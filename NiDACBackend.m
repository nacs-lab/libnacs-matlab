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

classdef NiDACBackend < PulseBackend
    %NiDACBackend, along with FPGABackend, is a subclass of PulseBackend (which only has the property seq).
    %NiDACBackend has all code relateverythin grelated to the NiDAC

    %Methods
        % self = NiDACBackend(seq)
        % val = getPriority(self)
        % initDev(self, did)
        % initChannel(self, cid)
        % connectClock(self, did)
        % generate(self, cids)
        % run(self)
        % wait(self)

  properties(Hidden)
    session;
    cid_map;
    cids;           % list of channel ids, ie [5,6,7,8]
    data;           % matrix of values to be queued to board. Generated by TimeSeq's getValues method.
    all_pulses;
    active_times;

    clk_period;     % defined in contructor.
    clk_period_ns;
    clk_rate; % Constant
  end

  properties(Constant, Hidden, Access=private)
    EXTERNAL_CLOCK = true;
    CLOCK_DIVIDER = 100;
  end

  methods
      %%
    function self = NiDACBackend(seq)
      self = self@PulseBackend(seq);
      self.cid_map = {};
      self.cids = [];

      self.clk_period_ns = 10 * self.CLOCK_DIVIDER * 2;
      self.clk_period = self.clk_period_ns * 1e-9;
      self.clk_rate = 1 / self.clk_period;
    end

    %%
    function val = getPriority(self)
      val = 2;
    end

    %%
    function initDev(self, did)
    end

    %%
    function initChannel(self, cid)
        %
      if size(self.cid_map, 2) >= cid && ~isempty(self.cid_map{cid})
        return;
      end
      name = channelName(self.seq, cid);
      cpath = strsplit(name, '/');
      if size(cpath, 2) ~= 2
        error('Invalid NI channel "%s".', name);
      end
      dev_name = cpath{1};
      matches = regexp(cpath{2}, '^([1-9]\d*|0)$', 'tokens');
      if isempty(matches)
        error('No NI channel number');
      end
      output_id = str2double(matches{1}{1});

      self.cid_map{cid} = {dev_name, output_id};
      self.cids(end + 1) = cid;
    end

    function connectClock(self, session, did)
      %% It seems that the trigger connection has to be added before clock.
      [~] = addTriggerConnection(session, 'External', ...
                                 [did, '/', self.seq.config.niStart(did)], ...
                                 'StartTrigger');
      if ~self.EXTERNAL_CLOCK
        return;
      end
      [~] = addClockConnection(session, 'External', ...
                               [did, '/', self.seq.config.niClocks(did)], ...
                               'ScanClock');
    end

    function prepare(self, cids0)
      if ~all(sort(cids0) == sort(self.cids))
        error('Channel mismatch.');
      end
      clk_period = self.clk_period;
      seq = self.seq;

      all_pulses = {};
      times = [];
      for cid = self.cids
        pulses = getPulses(seq, cid);
        for i = 1:size(pulses, 1)
          pulse = pulses(i, :);
          pulse_obj = pulse{3};
          toffset = pulse{1};
          step_len = pulse{2};
          toffset_idx = cld(toffset, clk_period);
          if isa(pulse_obj, 'jumpTo')
            times(1:2, end + 1) = [toffset_idx, toffset_idx + 1];
          else
            tend = toffset + step_len;
            tend_idx = cld(tend, clk_period);
            times(1:2, end + 1) = [toffset_idx, tend_idx + 1];
          end
        end
        all_pulses{cid} = pulses;
      end
      self.all_pulses = all_pulses;
      times = sortrows(times', [1, 2]);

      % `start_tidx; end_tidx; tidx_offset; end_pulseidx`
      % `end_tidx` and `start_tidx` are zero-based and the difference
      % between the two is the number of points we need to generate.
      % Valid tidx (0-based) are `start_tidx:(end_tidx - 1)`
      % The corresponding indices in the data array is
      % `(start_tidx - tidx_offset):(end_tidx - tidx_offset - 1)`
      tidx_sum = 1000;
      active_times = [0; tidx_sum; -1];
      for i = 1:size(times, 1)
        idx_start = times(i, 1);
        idx_end = times(i, 2);
        active_end = active_times(2, end);
        if idx_start <= active_times(2, end)
          %% merge
          if idx_end > active_end
            active_times(2, end) = idx_end;
          end
        else
          active_times(1:3, end + 1) = [idx_start, idx_end, ...
                                        active_times(3, end) + idx_start - active_end];
        end
      end
      self.active_times = active_times;
      fpgadriver = seq.findDriver('FPGABackend');
      fpgadriver.enableClockOut(self.CLOCK_DIVIDER, active_times(1:2, :));
    end

    function generate(self, cids0)
      cids = self.cids;
      if ~all(sort(cids0) == sort(cids))
        error('Channel mismatch.');
      end
      active_times = self.active_times;
      all_pulses = self.all_pulses;
      seq = self.seq;
      clk_period = self.clk_period;

      nstep = sum(active_times(2, :) - active_times(1, :));
      data = zeros(nstep, length(cids));

      for i = 1:length(cids)
        chn = cids(i);
        vidx = 1;
        active_idx = 1;
        cur_value = seq.getDefault(chn);
        pulses = all_pulses{chn};
        npulses = size(pulses, 1);
        for pidx = 1:npulses
          % At the beginning of each loop:
          %   `pidx` points to the pulse to be processed
          %   `vidx` points to the slot in `data` to be filled
          %   `cur_value` is the value of the channel right before `vidx`
          %   `active_idx` points to the `active_times` being processed.
          toffset = pulses{pidx, 1};

          %% Find corresponding active_times
          toffset_idx = cld(toffset, clk_period);
          while toffset_idx > active_times(2, active_idx)
            active_idx = active_idx + 1;
          end
          fill_vidx = toffset_idx - active_times(3, active_idx);

          %% First fill the values before the next pulse starts
          %% Index before next time
          if fill_vidx > vidx
            data(vidx:(fill_vidx - 1), i) = cur_value;
          end
          next_time = toffset_idx * clk_period;
          vidx = fill_vidx;

          %% Now find the last pulse that starts no later than the next point.
          has_pulse_running = 0;
          while true
            if pidx > npulses
              pidx = 0;
              break;
            end
            pulse = pulses(pidx, :);
            pulse_t = pulse{1};
            if pulse_t > next_time
              break;
            end
            pulse_obj = pulse{3};
            if isa(pulse_obj, 'jumpTo')
              cur_value = pulse_obj.val;
              pidx = pidx + 1;
              continue;
            end
            pulse_len = pulse{2};
            if pulse_t + pulse_len > next_time
              has_pulse_running = 1;
              break;
            end
            %% Forward to the end of the pulse since it is shorter than
            %% our time interval.
            cur_value = calcValue(pulse_obj, pulse_len,  pulse_len, cur_value);
            pidx = pidx + 1;
          end
          % There are three possibilities when we exit the loop
          % 1. we are at the end of the pulses:
          %     Just fill the rest of the sequence with the current value
          %     and done for the channel. The last processed pulse must be
          %     an End or Dirty.
          if pidx == 0
            break;
          end
          % 2. all the processed pulses finishes before the next time point
          %     Finish the current process and run the next loop.
          %     We'll fill the next element when we find the next pulse to
          %     to process.
          if ~has_pulse_running
            continue;
          end
          % 3. we've started a pulse and it continues pass the next time point
          %     Calculate values for this pulse and run the next loop.
          idx_offset = active_times(3, active_idx);
          last_vidx = cld(pulse_t + pulse_len, clk_period) - idx_offset;
          idxs = vidx:last_vidx;
          ts = (idxs + idx_offset) * clk_period - pulse_t;
          data(idxs, i) = calcValue(pulse_obj, ts, pulse_len, cur_value);
          cur_value = calcValue(pulse_obj, pulse_len, pulse_len, cur_value);
          pidx = pidx + 1;
          vidx = last_vidx + 1;
        end
        data(vidx:end, i) = cur_value;
      end
      self.data = data;
    end

    function session = createNewSession(self)
      session = daq.createSession('ni');
      % Setting to a high clock rate makes the NI card to wait for more
      % clock cycles after the sequence finished. However, setting to
      % a rate lower than the real one cause the card to not update
      % at the end of the sequence.
      session.Rate = self.clk_rate;
      inited_devs = containers.Map();

      %
      for i = 1:size(self.cids, 2)
        cid = self.cids(i);
        dev_name = self.cid_map{cid}{1};
        output_id = self.cid_map{cid}{2};
        [~] = addAnalogOutputChannel(session, dev_name, output_id, ...
                                     'Voltage');
        if ~isKey(inited_devs, dev_name)
          connectClock(self, session, dev_name);
          inited_devs(dev_name) = true;
        end
      end
    end

    function res = checkSession(self, session)
      % This can be further improved by storing an age of the session and
      % skip the check if the age didn't change. The current implementation
      % seems to be fast enough though ;-)
      Channels = session.Channels;
      nchns = size(self.cids, 2);
      if length(Channels) ~= nchns
          res = 0;
          return;
      end
      for i = 1:nchns
        cid = self.cids(i);
        dev_name = self.cid_map{cid}{1};
        output_id = sprintf('ao%d', self.cid_map{cid}{2});
        if ~strcmp(dev_name, Channels(i).Device.ID) || ...
                ~strcmp(output_id, Channels(i).ID)
            res = 0;
            return;
        end
      end
      res = 1;
      return;
    end

    function ensureSession(self)
        % Use a global variable to cache the session since
        % adding channels is really slow.... (50ms per channel)
        global nacsNiDACBackendSession
        global nacsNiDACBackendSessionUsing
        % Check if the session is in use first since
        % operations on the invalid session may error.
        if (~isempty(nacsNiDACBackendSessionUsing) && ...
                nacsNiDACBackendSessionUsing == 1) || ...
                isempty(nacsNiDACBackendSession) || ...
                ~self.checkSession(nacsNiDACBackendSession)
            delete(nacsNiDACBackendSession);
            nacsNiDACBackendSession = self.createNewSession();
        end
        nacsNiDACBackendSessionUsing = 1;
        self.session = nacsNiDACBackendSession;
    end

    function run(self)
      ensureSession(self);
      session = self.session;
      queueOutputData(session, self.data);
      startBackground(session);
    end

    function wait(self)
      global nacsNiDACBackendSessionUsing
      % This turns the pause(0.1) in the NI driver into a busy wait loop
      % and reduce ~50ms of wait time per run on average.
      old_state = pause('off');
      % The cleanup object tracks the lifetime of the current scope.
      cleanup = FacyOnCleanup(@(old_state) pause(old_state), old_state);
      wait(self.session);
      nacsNiDACBackendSessionUsing = 0;
    end
  end
end
