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
    commands;
    cmd_str = '';
  end

  properties(Constant, Hidden, Access=private)
    INIT_DELAY = 100e-6;
    CLOCK_DELAY = 100e-6;
    START_DELAY = 0.5e-6;
    FIN_CLOCK_DELAY = 100e-6;
    MIN_DELAY = 1e-6;

    TTL_CHN = 1;
    DDS_FREQ = 2;
    DDS_AMP = 3;
    DDS_PHASE = 4;
  end

  methods
    function self = FPGABackend(varargin)
      self = self@PulseBackend(varargin{:});
      self.config = loadConfig();
      self.url = self.config.fpgaUrls('FPGA1');
      self.commands = {};
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
      [chn_type, chn_num] = self.parseCIdReal(name);
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
      t = self.INIT_DELAY;
      self.cmd_str = '';
      self.commands = {};

      ttl_values = self.getTTLDefault();
      self.commands{end + 1} = sprintf('t=%.2f,TTL(all)=%x\n', ...
                                       t * 1e6, ttl_values);

      nchn = size(cids, 2);
      total_t = self.seq.length();
      nstep = floor(total_t / dt) + 1;

      pulse_mask = false(1, nchn);
      cur_pulses = cell(1, nchn);

      pidxs = ones(1, nchn);
      %% The first command can only be run one time period after the clock_out
      %% command.
      glob_itdx = 1;
      tidxs = zeros(1, nchn);
      all_pulses = cell(1, nchn);
      npulses = zeros(1, nchn);
      orig_values = zeros(1, nchn);
      cur_values = zeros(1, nchn);
      for i = 1:nchn
        cid = cids(i);
        all_pulses{i} = self.seq.getPulseTimes(cid);
        npulses(i) = size(all_pulses{i}, 1);
        orig_values(i) = self.seq.getDefaults(cid);
        cur_values(i) = orig_values(i);

        %% TTL defaults are already set.
        if self.type_cache(cid) ~= self.TTL_CHN
          t = t + self.MIN_DELAY * 10;
          chn_num = self.num_cache(cid);
          if chn_type == self.DDS_FREQ
            self.commands{end + 1} = sprintf('t=%.2f,freq(%d) = %f\n', ...
                                             t * 1e6, chn_num, cur_values(i));
          elseif chn_type == self.DDS_AMP
            self.commands{end + 1} = sprintf('t=%.2f,amp(%d) = %f\n', ...
                                             t * 1e6, chn_num, cur_values(i));
          end
        end

        if npulses(i) == 0
          pidxs(i) = 0;
        end
      end

      if self.clock_div > 0
        t = t + self.CLOCK_DELAY;
        self.commands{end + 1} = sprintf('t=%.2f,CLOCK_OUT(%d)\n', ...
                                         t * 1e6, self.clock_div);
      end
      start_t = t + self.START_DELAY; % global time offset

      while true
        %% At the beginning of each loop:
        %% @glob_tidx the time index to be filled. The corresponding sequence
        %% time is glob_tidx * self.MIN_DELAY and the corresponding FPGA
        %% time is glob_tidx * self.MIN_DELAY + start_t
        %%
        %% @tidxs the time index processed for this channel last time. For each
        %% channel, each loop needs to propagate the channel from tidxs(i)
        %% to right before glob_tidx + 1.
        %%
        %% @pidxs points to the pulse for each channel to be processed
        %% in @all_pulses (0 if there's not more pulses for the channel).
        %% It might point to non-existing pulse when the last pulse is being
        %% processed.
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
        %% the resolution. This might not be the same with the value at
        %% tidxs(i) when the update last time is too small and it was uncessary
        %% to generate a new command.
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

        for i = 1:nchn
          cid = cids(i);
          if pulse_mask(i)
            pulse = cur_pulses{i};
            t_seq = glob_tidx * self.MIN_DELAY;
            if pulse{1} > t_seq
              %% If the current pulse continues to the next time point,
              %% calculate the new value, add command, update necessary state
              %% variables, and proceed to the next channel.
              val = pulse{3}.calcValue(t_seq - pulse{4}, pulse{5}, ...
                                       orig_values(i));
              tidxs(i) = glob_tidx;
              chn_type = self.type_cache(i);
              chn_num = self.num_cache(i);
              if chn_type == self.TTL_CHN
                %% TODO update cur_values, ttl_values
              elseif chn_type == self.DDS_FREQ
                %% TODO update cur_values
              elseif chn_type == self.DDS_AMP
                %% TODO update cur_values
              else
                error('Invalid channel type.');
              end
              continue;
            end
            %% Otherwise, finish up the pulse and proceed to check for
            %% new pulses.
            %% TODO
          end
          %% Find and process pulses that starts no later than the next time
          %% point. If no new pulses are found we still need to check if a new
          %% value is necessary since we might need to finish up a previous
          %% pulse.
          %% TODO
        end

        %% Now we need to update ttl values
        if new_ttl ~= ttl_values
          ttl_values = new_ttl;
          t = glob_tidx * self.MIN_DELAY + start_t;
          glob_tidx = glob_tidx + 1;
          self.commands{end + 1} = sprintf('t=%.2f,TTL(all)=%x\n', ...
                                           t * 1e6, ttl_values);
        end

        %% At the end of the loop, we check if all channels have processed
        %% all the pulses, if so, we should break the loop and finish up.
        if all(pidxs == 0)
          break;
        end
      end

      %% Now we wait till the end of the sequence.
      glob_tidx = max(nstep, glob_tidx + 1);
      if self.clock_div > 0
        %% This is a hack that is believed to make the NI card happy.
        t = glob_tidx * self.MIN_DELAY + start_t;
        glob_tidx = glob_tidx + floor(self.FIN_CLOCK_DELAY / self.MIN_DELAY);
        self.commands{end + 1} = sprintf('t=%.2f,CLOCK_OUT(100)\n', t * 1e6);
      end
      %% We turn off the clock even when it is not used just as a place holder.
      %% for the end of the sequence.
      t = glob_tidx * self.MIN_DELAY + start_t;
      glob_tidx = glob_tidx + 1;
      self.commands{end + 1} = sprintf('t=%.2f,CLOCK_OUT(off)\n', t * 1e6);
    end

    function generate_old(self, cids)
      %% t = self.INIT_DELAY;
      %% self.cmd_str = '';
      %% self.commands = {};
      %% self.commands{end + 1} = sprintf('t=%.2f,TTL(all)=%x\n', ...
      %%                                  t * 1e6, self.getTTLDefault());
      %% if self.clock_div > 0
      %%   t = t + self.CLOCK_DELAY;
      %%   self.commands{end + 1} = sprintf('t=%.2f,CLOCK_OUT(%d)\n', ...
      %%                                    t * 1e6, self.clock_div);
      %% end
      %% start_t = t + self.START_DELAY;
      tracker = PulseTimeTracker(self.seq, cids);

      while true
        min_delay = self.MIN_DELAY + t - (tracker.curTime + start_t);
        [new_t, new_pulses] = tracker.nextEvent(min_delay, TrackMode.NoEarlier);
        if new_t < 0
          break;
        end
        t = new_t + start_t;

        updated_chn = containers.Map();
        for i = 1:size(new_pulses, 1)
          pulse = new_pulses(i, :);
          cid = pulse{6};
          if pulse{2} == TimeType.Dirty
            %% TODO? merge TTL update, use more precise values
            %% TODO? update finished pulse
            self.appendPulse(cid, t, tracker.curValues(cid));
            t = t + self.MIN_DELAY;
            updated_chn(cid) = 1;
          end
        end

        %% Update channels that are currently active.
        cur_pulses = tracker.curPulses;
        for key = 1:tracker.nchn
          if updated_chn.isKey(key)
            continue
          end
          self.appendPulse(key, t, tracker.curValues(key));
          t = t + self.MIN_DELAY;
        end
      end

      if self.clock_div > 0
        t = t + self.MIN_DELAY;
        self.commands{end + 1} = sprintf('t=%.2f,CLOCK_OUT(100)\n', t * 1e6);
        t = t + self.FIN_CLOCK_DELAY;
        self.commands{end + 1} = sprintf('t=%.2f,CLOCK_OUT(off)\n', t * 1e6);
      end

      self.cmd_str = [self.commands{:}];

      self.seq.log('#### Start Generated Sequence File ####');
      self.seq.log(self.cmd_str);
      self.seq.log('#### End Sequence File ####');
    end

    function res = getCmd(self)
      res = self.cmd_str;
    end

    function run(self, rep)
      self.poster = URLPoster(self.url);
      self.poster.post({'command', 'runseq', ...
                        'debugPulses', 'off',
                        'reps', '1',
                        'seqtext', self.cmd_str});
    end

    function wait(self, rep)
      output = self.poster.reply();
      disp(output);
    end
  end

  methods(Access=private)
    function [chn_type, chn_num] = parseCIdReal(self, cid)
      cpath = strsplit(cid, '/');
      if strncmp(cpath{1}, 'TTL', 3)
        chn_type = self.TTL_CHN;
        if size(cpath, 2) ~= 1
          error('Invalid TTL channel id "%s".', cid);
        end
        matches = regexp(cpath{1}, '^TTL([1-9]\d*)$', 'tokens');
        if isempty(matches)
          error('No TTL channel number');
        end
        chn_num = str2double(matches{1}{1});
        if ~isfinite(chn_num) || chn_num < 0 || chn_num > 24 || ...
           mod(chn_num, 4) == 0
          error('Unconnected TTL channel %d.', chn_num);
        end
      elseif strncmp(cpath{1}, 'DDS', 3)
        if size(cpath, 2) ~= 2
          error('Invalid DDS channel id "%s".', cid);
        end
        matches = regexp(cpath{1}, '^DDS([1-9]\d*)$', 'tokens');
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
      val = uint64(0);
      try
        cid = self.seq.findChannelId(sprintf('FPGA1/TTL%d', chn));
        if cid > 0 && self.seq.getDefaults(cid)
          val = uint64(1);
        end
      catch
      end
    end

    function val = getTTLDefault(self)
      val = 0;
      for i = 0:31
        val = val | bitshift(self.singleTTLDefault(i), i);
      end
    end

    function appendPulse(self, cid, t, val)
      chn_type = self.type_cache(cid);
      chn_num = self.num_cache(cid);
      if chn_type == self.TTL_CHN
        if val
          self.commands{end + 1} = sprintf('t=%.2f,TTL(%d) = 1\n', ...
                                           t * 1e6, chn_num);
        else
          self.commands{end + 1} = sprintf('t=%.2f,TTL(%d) = 0\n', ...
                                           t * 1e6, chn_num);
        end
      elseif chn_type == self.DDS_FREQ
        self.commands{end + 1} = sprintf('t=%.2f,freq(%d) = %f\n', ...
                                         t * 1e6, chn_num, val);
      elseif chn_type == self.DDS_AMP
        self.commands{end + 1} = sprintf('t=%.2f,amp(%d) = %f\n', ...
                                         t * 1e6, chn_num, val);
      else
        error('Unknown channel type.');
      end
    end
  end
end
