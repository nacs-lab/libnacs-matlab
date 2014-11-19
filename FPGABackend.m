%% Copyright (c) 2014-2014, Yichao Yu <yyc1992@gmail.com>
%%
%% This library is free software; you can redistribute it and/or
%% modify it under the terms of the GNU Lesser General Public
%% License as published by the Free Software Foundation; either
%% version 3.0 of the License, or (at your option) any later version.
%% This library is distributed in the hope that it will be useful,
%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
%% Lesser General Public License for more details.
%% You should have received a copy of the GNU Lesser General Public
%% License along with this library.

classdef FPGABackend < PulseBackend
  properties(Hidden, Access=private)
    url = '';
    clock_div = 0;
    config;
    poster = [];
    type_cache = [];
    num_cache = [];
    cmd_str = '';
    MIN_DELAY = 1e-6;
  end

  properties(Constant, Hidden, Access=private)
    INIT_DELAY = 100e-6;
    CLOCK_DELAY = 2e-6;
    START_DELAY = 0.1e-6;
    FIN_CLOCK_DELAY = 30e-3;
    MIN_DELAY_REAL = 1e-6;

    TTL_CHN = 1;
    DDS_FREQ = 2;
    DDS_AMP = 3;
    DDS_PHASE = 4;

    START_TRIGGER_TTL = 9;
  end

  methods
    function self = FPGABackend(seq)
      self = self@PulseBackend(seq);
      self.config = loadConfig();
      self.url = self.config.fpgaUrls('FPGA1');
    end

    function setTimeResolution(self, dt)
      self.MIN_DELAY = max(self.MIN_DELAY_REAL, dt);
    end

    function initDev(self, did)
      if ~strcmp('FPGA1', did)
        error('Unknown FPGA device "%s".', did);
      end
    end

    function initChannel(self, cid)
      if size(self.type_cache, 2) >= cid && self.type_cache(cid) > 0
        return;
      end
      name = self.seq.channelName(cid);
      if ~strncmp('FPGA1/', name, 5)
        error('Unknown channel name "%s"', name);
      end
      name = name(7:end);
      [chn_type, chn_num] = self.parseCId(name);
      self.type_cache(cid) = chn_type;
      self.num_cache(cid) = chn_num;
    end

    function enableClockOut(self, div)
      if div < 0 || div > 254
        error('Clock divider out of range.');
      end
      self.clock_div = div;
    end

    function generate(self, cids)
      %% Load member constants/caches into local variable since matlab is super
      %% slow at loading members.
      TTL_CHN = self.TTL_CHN;
      DDS_FREQ = self.DDS_FREQ;
      DDS_AMP = self.DDS_AMP;
      DDS_PHASE = self.DDS_PHASE;
      MIN_DELAY = self.MIN_DELAY;

      MIN_DELAY_US = MIN_DELAY * 1e6;

      type_cache = self.type_cache;
      num_cache = self.num_cache;

      max_pulse_id = self.seq.curPulseId();
      pulse_cache_range = zeros(max_pulse_id, 2);
      pulse_cache = cell(1, max_pulse_id);

      start_us = self.INIT_DELAY * 1e6;
      self.cmd_str = '';
      commands = {};
      cmd_len = 0;

      nchn = size(cids, 2);
      total_t = self.seq.length();
      nstep = floor(total_t / MIN_DELAY);

      ttl_values = self.getTTLDefault();
      %% Pre allocating memory
      commands{cmd_len + min(nstep, 100000)} = [];
      cmd_len = cmd_len + 1;
      commands{cmd_len} = sprintf('t=%.2f,TTL(all)=%x\n', ...
                                  start_us, ttl_values);

      pulse_mask = false(1, nchn);
      cur_pulses = cell(1, nchn);

      pidxs = ones(1, nchn);
      %% The first command can only be run one time period after the clock_out
      %% command.
      glob_tidx = 1;
      all_pulses = cell(1, nchn);
      npulses = zeros(1, nchn);
      orig_values = zeros(1, nchn);
      cur_values = zeros(1, nchn);
      %% Matlab seems to have special optimization for "for x = 1:y"
      %% anything that is not exactly this form is much slower.
      for i = 1:nchn
        cid = cids(i);
        all_pulses{i} = self.seq.getPulseTimes(cid);
        npulses(i) = size(all_pulses{i}, 1);
        orig_values(i) = self.seq.getDefaults(cid);
        cur_values(i) = orig_values(i);

        %% TTL defaults are already set.
        if type_cache(cid) ~= TTL_CHN
          start_us = start_us + MIN_DELAY_US * 10;
          chn_num = num_cache(cid);
          chn_type = type_cache(cid);
          if chn_type == DDS_FREQ
            cmd_len = cmd_len + 1;
            commands{cmd_len} = sprintf('t=%.2f,freq(%d)=%f\n', ...
                                        start_us, chn_num, cur_values(i));
          elseif chn_type == DDS_AMP
            cmd_len = cmd_len + 1;
            commands{cmd_len} = sprintf('t=%.2f,amp(%d)=%f\n', ...
                                        start_us, chn_num, cur_values(i));
          end
        end

        if npulses(i) == 0
          pidxs(i) = 0;
        end
      end

      if self.clock_div > 0
        if self.START_TRIGGER_TTL >= 0
          %% The NI Card (with the driver/interface comes with MATLAB 2014b)
          %% seems to want a start trigger before the clock starts and
          %% it will start running when it gets a clock.
          start_us = start_us + MIN_DELAY_US * 100;
          cmd_len = cmd_len + 1;
          commands{cmd_len} = sprintf('t=%.2f,TTL(%d)=1\n', ...
                                      start_us, self.START_TRIGGER_TTL);
          start_us = start_us + MIN_DELAY_US * 2;
          cmd_len = cmd_len + 1;
          commands{cmd_len} = sprintf('t=%.2f,TTL(%d)=0\n', ...
                                      start_us, self.START_TRIGGER_TTL);
        end
        start_us = start_us + self.CLOCK_DELAY * 1e6;
        cmd_len = cmd_len + 1;
        commands{cmd_len} = sprintf('t=%.2f,CLOCK_OUT(%d)\n', ...
                                    start_us, self.clock_div);
        %% Delay everything by half a clock out cycle so that everything
        %% updates at the same time.
        start_us = start_us + self.clock_div * 10e-3;
      else
        start_us = start_us + self.START_DELAY * 1e6; % global time offset
      end

      %% We run the loop as long as there's any pulses left.
      while any(pidxs ~= 0)
        %% At the beginning of each loop:
        %% @glob_tidx the time index to be filled. The corresponding sequence
        %% time is glob_tidx * MIN_DELAY and the corresponding FPGA
        %% time in us is glob_tidx * MIN_DELAY_US + start_us
        %%
        %% @pidxs points to the pulse for each channel to be processed
        %% in @all_pulses (0 if there's not more pulses for the channel).
        %% It might point to non-existing pulse when the last pulse is being
        %% processed. @pidxs should never points to a end pulse.
        %%
        %% @pulse_mask and @cur_pulses determines if there's a pulse running
        %% during the last time point (which might finish before the next
        %% time point). The pulse stored in @cur_pulses should be the end
        %% pulse.
        %%
        %% @orig_values is the start value to calculate the value for the
        %% current pulse. If there is no current pulse, this is the value at
        %% the beginning of the next pulse.
        %%
        %% @cur_values is the value at the last time step this can be used
        %% to only update the channel when the value has changed by more than
        %% the resolution.
        %%
        %% @ttl_values is the value of all the TTL channels in the previous
        %% time point.

        %% For DDS frequency, resolution is 0.4Hz (1.75GHz / 2**32)
        %% For DDS amplitude, resolution is 0.0002 (1 / 2**12)
        %% For TTL, resolution is, ... well, .... 0 or 1...
        %% No DDS phase for now.

        %% In each loop, we propagate each active channel (determined by
        %% @pulse_mask) by one time period. For each DDS channels, we
        %% append a command and increment the time if the value changes.
        %% For each TTL channels, we update the TTL values and add a command
        %% at the end of the loop to update all TTL values.
        new_ttl = ttl_values;
        next_tidx = nstep;

        for i = 1:nchn
          cid = cids(i);
          if pulse_mask(i)
            %% Check pulse_mask first since it is the most likely case.
            pulse = cur_pulses{i};
            pid = pulse{7};
            if pulse_cache_range(pid, 2) >= glob_tidx;
              %% If the current pulse continues to the next time point,
              %% calculate the new value, add command, update necessary state
              %% variables, and proceed to the next channel.
              val = pulse_cache{pid}(glob_tidx - pulse_cache_range(pid, 1));
              next_tidx = glob_tidx + 1;
              chn_type = type_cache(cid);
              chn_num = num_cache(cid);
              if chn_type == DDS_FREQ
                if abs(cur_values(i) - val) >= 0.4
                  tus = glob_tidx * MIN_DELAY_US + start_us;
                  glob_tidx = glob_tidx + 1;
                  cmd_len = cmd_len + 1;
                  commands{cmd_len} = sprintf('t=%.2f,freq(%d)=%.1f\n', ...
                                              tus, chn_num, val);
                  cur_values(i) = val;
                end
              elseif chn_type == DDS_AMP
                %% Maximum amplitude is 1.
                val = min(1, val);
                if abs(cur_values(i) - val) >= 0.0002
                  tus = glob_tidx * MIN_DELAY_US + start_us;
                  glob_tidx = glob_tidx + 1;
                  cmd_len = cmd_len + 1;
                  commands{cmd_len} = sprintf('t=%.2f,amp(%d)=%.4f\n', ...
                                              tus, chn_num, val);
                  cur_values(i) = val;
                end
              elseif chn_type == TTL_CHN
                val = logical(val);
                cur_values(i) = val;
                new_ttl = bitset(new_ttl, chn_num + 1, val);
              end
              continue;
            end
            %% Otherwise, finish up the pulse and proceed to check for
            %% new pulses.
            pulse_mask(i) = false;
            %% pulse{1} is the end of the pulse.
            orig_values(i) = pulse{3}.calcValue(pulse{1} - pulse{4}, ...
                                                pulse{5}, orig_values(i));
          end
          if pidxs(i) == 0
            %% pulse index is only 0 when all the pulses are done.
            continue;
          end
          %% Find and process pulses that starts no later than the next time
          %% point. If no new pulses are found we still need to check if a new
          %% value is necessary since we might need to finish up a previous
          %% pulse.
          %% Also needs to update next_tidx according to the next time pulse.

          while true
            pidx = pidxs(i);
            if pidx > npulses(i)
              pidxs(i) = 0;
              break;
            end

            %% So the next pulse is good, let's process it.
            pulses = all_pulses{i};
            %% Well, not quite yet, we need to make sure it is no later than
            %% the next time point.
            step_tidx = ceil(pulses{pidx, 1} / MIN_DELAY);
            if step_tidx > glob_tidx
              %% if it is too late just update next_tidx to make sure we
              %% catch it next time and exit.
              next_tidx = min(next_tidx, step_tidx);
              break;
            end
            pulse = pulses(pidx, :);

            %% So we have no excuse to not process this pulse this time.
            %% Let's do it...
            switch pulse{2}
              case TimeType.Dirty
                pidxs(i) = pidx + 1;
                pulse_obj = pulse{3};
                orig_values(i) = pulse_obj.calcValue(pulse{8}, ...
                                                     pulse{5}, orig_values(i));
                continue;
              case TimeType.Start
                pidx = pidx + 1;
                %% Debug only
                if pidx > npulses(i) || pulse{7} ~= all_pulses{i}{pidx, 7}
                  error('Unmatch pulse start and end.');
                end
                pulse_end = all_pulses{i}(pidx, :);
                end_tidx = pulse_end{1} / MIN_DELAY;
                pidxs(i) = pidx + 1;
                pobj = pulse{3};
                if ceil(end_tidx) > glob_tidx
                  %% If the pulse persists, record it and quit the loop.
                  pulse_mask(i) = true;
                  cur_pulses{i} = pulse_end;
                  %% Cache values so that we can use later.
                  pid = pulse{7};
                  end_tidx = floor(end_tidx);
                  ts = (glob_tidx:end_tidx) * MIN_DELAY - pulse{4};
                  pulse_cache_range(pid, 1) = glob_tidx - 1;
                  pulse_cache_range(pid, 2) = end_tidx;
                  pulse_cache{pid} = pobj.calcValue(ts, pulse{5}, ...
                                                    orig_values(i));
                  commands{cmd_len + end_tidx - glob_tidx + 1000} = [];
                  break;
                end
                %% Forward to the end of the pulse since it is shorter than
                %% our time interval.
                ptime = pulse_end{1} - pulse{4};
                orig_values(i) = pobj.calcValue(ptime, pulse{5}, ...
                                                orig_values(i));
              otherwise
                %% Debug only
                error('Invalid pulse type.');
            end
          end
          %% There are two possibilities when we exit the loop
          %% 1. Next pulse too late or not exist
          %%     No pulse is currently running, but we do need to check
          %%     if we need to update the device using orig_values(i)
          if ~pulse_mask(i)
            val = orig_values(i);
            chn_type = type_cache(cid);
            chn_num = num_cache(cid);
            if chn_type == TTL_CHN
              val = logical(val);
              new_ttl = bitset(new_ttl, chn_num + 1, val);
              cur_values(i) = val;
            elseif chn_type == DDS_FREQ
              if abs(cur_values(i) - val) >= 0.4
                tus = glob_tidx * MIN_DELAY_US + start_us;
                glob_tidx = glob_tidx + 1;
                cmd_len = cmd_len + 1;
                commands{cmd_len} = sprintf('t=%.2f,freq(%d)=%.1f\n', ...
                                            tus, chn_num, val);
                cur_values(i) = val;
              end
            elseif chn_type == DDS_AMP
              %% Maximum amplitude is 1.
              val = min(1, val);
              if abs(cur_values(i) - val) >= 0.0002
                tus = glob_tidx * MIN_DELAY_US + start_us;
                glob_tidx = glob_tidx + 1;
                cmd_len = cmd_len + 1;
                commands{cmd_len} = sprintf('t=%.2f,amp(%d)=%.4f\n', ...
                                            tus, chn_num, val);
                cur_values(i) = val;
              end
            end
            continue;
          end

          %% 2. Found a pulse that persists
          %%     Calculate values for this pulse and run the next loop.
          pulse = pulse_end;
          pid = pulse{7};
          val = pulse_cache{pid}(glob_tidx - pulse_cache_range(pid, 1));
          next_tidx = glob_tidx + 1;
          chn_type = type_cache(cid);
          chn_num = num_cache(cid);
          if chn_type == TTL_CHN
            val = logical(val);
            cur_values(i) = val;
            new_ttl = bitset(new_ttl, chn_num + 1, val);
          elseif chn_type == DDS_FREQ
            if abs(cur_values(i) - val) >= 0.4
              tus = glob_tidx * MIN_DELAY_US + start_us;
              glob_tidx = glob_tidx + 1;
              cmd_len = cmd_len + 1;
              commands{cmd_len} = sprintf('t=%.2f,freq(%d)=%.1f\n', ...
                                          tus, chn_num, val);
              cur_values(i) = val;
            end
          elseif chn_type == DDS_AMP
            %% Maximum amplitude is 1.
            val = min(1, val);
            if abs(cur_values(i) - val) >= 0.0002
              tus = glob_tidx * MIN_DELAY_US + start_us;
              glob_tidx = glob_tidx + 1;
              cmd_len = cmd_len + 1;
              commands{cmd_len} = sprintf('t=%.2f,amp(%d)=%.4f\n', ...
                                          tus, chn_num, val);
              cur_values(i) = val;
            end
          end
        end

        %% Now we need to update ttl values
        if new_ttl ~= ttl_values
          ttl_values = new_ttl;
          tus = glob_tidx * MIN_DELAY_US + start_us;
          glob_tidx = glob_tidx + 1;
          cmd_len = cmd_len + 1;
          commands{cmd_len} = sprintf('t=%.2f,TTL(all)=%x\n', ...
                                      tus, ttl_values);
        end

        %% And check if we can skip some time points.
        glob_tidx = max(glob_tidx, next_tidx);
      end

      %% Now we wait till the end of the sequence.
      glob_tidx = max(nstep, glob_tidx + 1);
      if self.clock_div > 0
        %% This is a hack that is believed to make the NI card happy.
        tus = glob_tidx * MIN_DELAY_US + start_us;
        glob_tidx = glob_tidx + floor(self.FIN_CLOCK_DELAY / MIN_DELAY);
        cmd_len = cmd_len + 1;
        commands{cmd_len} = sprintf('t=%.2f,CLOCK_OUT(60)\n', tus);
      end
      %% We turn off the clock even when it is not used just as a place holder.
      %% for the end of the sequence.
      tus = glob_tidx * MIN_DELAY_US + start_us;
      glob_tidx = glob_tidx + 1;
      cmd_len = cmd_len + 1;
      commands{cmd_len} = sprintf('t=%.2f,CLOCK_OUT(off)\n', tus);

      %% Finally we construct and log the sequence.
      self.cmd_str = [commands{:}];

      self.seq.log('#### Start Generated Sequence File ####');
      self.seq.log(self.cmd_str);
      self.seq.log('#### End Sequence File ####');
    end

    function res = getCmd(self)
      res = self.cmd_str;
    end

    function run(self)
      self.poster = URLPoster(self.url);
      self.poster.post({'command', 'runseq', 'debugPulses', 'off', ...
                        'reps', '1'}, {'seqtext', self.cmd_str});
    end

    function wait(self)
      output = self.poster.reply();
      disp(output);
    end
  end

  methods(Access=private)
    function [chn_type, chn_num] = parseCId(self, cid)
      cpath = strsplit(cid, '/');
      if strncmp(cpath{1}, 'TTL', 3)
        chn_type = self.TTL_CHN;
        if size(cpath, 2) ~= 1
          error('Invalid TTL channel id "%s".', cid);
        end
        matches = regexp(cpath{1}, '^TTL([1-9]\d*|0)$', 'tokens');
        if isempty(matches)
          error('No TTL channel number');
        end
        chn_num = str2double(matches{1}{1});
        if ~isfinite(chn_num) || chn_num < 0 || chn_num > 28 || ...
           mod(chn_num, 4) == 0
          error('Unconnected TTL channel %d.', chn_num);
        elseif chn_num == self.START_TRIGGER_TTL
          error('Channel conflict with start trigger');
        end
      elseif strncmp(cpath{1}, 'DDS', 3)
        if size(cpath, 2) ~= 2
          error('Invalid DDS channel id "%s".', cid);
        end
        matches = regexp(cpath{1}, '^DDS([1-9]\d*|0)$', 'tokens');
        if isempty(matches)
          error('No DDS channel number');
        end
        chn_num = str2double(matches{1}{1});
        if ~isfinite(chn_num) || chn_num < 0 || chn_num > 22
          error('DDS channel number %d out of range.', chn_num);
        end
        if strcmp(cpath{2}, 'FREQ')
          chn_type = self.DDS_FREQ;
        elseif strcmp(cpath{2}, 'AMP')
          chn_type = self.DDS_AMP;
        else
          error('Invalid DDS parameter name "%s".', cpath{2});
        end
      else
        error('Unknown channel type "%s"', cpath{1});
      end
    end

    function val = singleTTLDefault(self, chn)
      val = false;
      try
        cid = self.seq.findChannelId(sprintf('FPGA1/TTL%d', chn));
        if cid > 0 && self.seq.getDefaults(cid)
          val = true;
        end
      catch
      end
    end

    function val = getTTLDefault(self)
      val = uint64(0);
      for i = 0:31
        val = bitset(val, i + 1, self.singleTTLDefault(i));
      end
    end
  end
end
