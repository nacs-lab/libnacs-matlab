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

classdef ExpSeq < ExpSeqBase
  properties(Access=private)
    drivers;
    driver_cids;
    generated = false;
    default_override;
    orig_channel_names;
    cid_cache;
    pulse_id_counter = 0;
    seq_id_counter = 0;
    chn_manager;
  end

  methods
    function self = ExpSeq(name)
      if nargin < 1
        name = 'seq';
      elseif ~ischar(name)
        error('Sequence name must be a string.');
      end
      global nacsTimeSeqNameSuffixHack;
      name = [name, nacsTimeSeqNameSuffixHack];
      self = self@ExpSeqBase(name);
      self.chn_manager = ChannelManager();
      self.drivers = containers.Map();
      self.driver_cids = containers.Map();
      self.default_override = {};
      self.orig_channel_names = {};
      self.cid_cache = containers.Map('KeyType', 'char', 'ValueType', 'double');

      self.logDefault();
    end

    function cid = translateChannel(self, name)
      if self.cid_cache.isKey(name)
        cid = self.cid_cache(name);
        return;
      end
      orig_name = name;
      name = self.config.translateChannel(name);
      cid = self.chn_manager.getId(name);
      self.cid_cache(orig_name) = cid;

      if (cid > size(self.orig_channel_names, 2) || ...
          isempty(self.orig_channel_names{cid}))
        self.orig_channel_names{cid} = orig_name;
      else
        return;
      end
      cpath = strsplit(name, '/');
      did = cpath{1};
      [driver, driver_name] = self.initDeviceDriver(did);

      driver.initChannel(cid);
      cur_cids = self.driver_cids(driver_name);
      self.driver_cids(driver_name) = unique([cur_cids, cid]);
    end

    function cid = findChannelId(self, name)
      name = self.config.translateChannel(name);
      cid = self.chn_manager.findId(name);
    end

    function driver = findDriver(self, driver_name)
      try
        driver = self.drivers(driver_name);
      catch
        driver_func = str2func(driver_name);
        driver = driver_func(self);
        self.drivers(driver_name) = driver;
        self.driver_cids(driver_name) = [];
      end
    end

    function generate(self)
      if ~self.generated
        disp('Generating ...');
        self.log(['# Generating @ ', datestr(now, 'yyyy-mm-dd_HH-MM-SS')]);
        for key = self.drivers.keys()
          driver_name = key{:};
          driver = self.drivers(driver_name);
          cids = self.driver_cids(driver_name);
          driver.prepare(cids);
        end
        for key = self.drivers.keys()
          driver_name = key{:};
          driver = self.drivers(driver_name);
          cids = self.driver_cids(driver_name);
          driver.generate(cids);
        end
        self.generated = true;
      end
    end

    function run_async(self)
      self.generate();
      global nacsTimeSeqDisableRunHack;
      if ~isempty(nacsTimeSeqDisableRunHack) && nacsTimeSeqDisableRunHack
        return;
      end
      drivers = {};
      for driver = self.drivers.values()
        drivers = [drivers; {driver{:}, -driver{:}.getPriority()}];
      end
      if ~isempty(drivers)
        drivers = sortrows(drivers, [2]);
      end
      disp(['Running at ' datestr(now, 'HH:MM:SS, yyyy/mm/dd') ' ...']);
      self.log(['# Start running @ ', datestr(now, 'yyyy-mm-dd_HH-MM-SS')]);
      for i = 1:size(drivers, 1)
        drivers{i, 1}.run();
      end

      self.log(['# Started @ ', datestr(now, 'yyyy-mm-dd_HH-MM-SS')]);
    end

    function waitFinish(self)
      global nacsTimeSeqDisableRunHack;
      if ~isempty(nacsTimeSeqDisableRunHack) && nacsTimeSeqDisableRunHack
        return;
      end
      drivers = {};
      for driver = self.drivers.values()
        drivers = [drivers; {driver{:}, -driver{:}.getPriority()}];
      end
      if ~isempty(drivers)
        drivers = sortrows(drivers, [2]);
      end
      self.log(['# Start waiting @ ', datestr(now, 'yyyy-mm-dd_HH-MM-SS')]);
      for i = 1:size(drivers, 1)
        drivers{i, 1}.wait();
      end
      self.log(['# Done @ ', datestr(now, 'yyyy-mm-dd_HH-MM-SS')]);
    end

    function run(self)
       %Set up memory map to share variables between MATLAB instances.
      m = MemoryMap;

       % See if another MATLAB instance has asked runSeq to pause.  If
       % we are aborting, don't bother pausing.
      if (m.Data(1).PauseRunSeq == 1) && (m.Data(1).AbortRunSeq == 0)
        m.Data(1).IsPausedRunSeq = 1;
        disp('PauseRunSeq set to 1. Run ContinueRunSeq to continue, AbortRunSeq to abort. Hit ctrl+c and run ResetMemoryMap if all else fails.')
        while m.Data(1).PauseRunSeq
          pause(1)
          if m.Data(1).AbortRunSeq
            break
          end
        end
      end
      m.Data(1).IsPausedRunSeq = 0;

      self.run_async();
      self.waitFinish();
				%Increment current sequence number
      m.Data(1).CurrentSeqNum = m.Data(1).CurrentSeqNum + 1;
     %If we are using NumGroup to run sequences in groups, pause every
     %NumGroup sequences.
      if ~mod(m.Data(1).CurrentSeqNum, m.Data(1).NumPerGroup) &&  (m.Data(1).NumPerGroup>0)
        m.Data(1).PauseRunSeq = 1;
      end

      global nacsTimeSeqDisableRunHack;
      if ~isempty(nacsTimeSeqDisableRunHack) && nacsTimeSeqDisableRunHack
        return;
      end
    end

    function res = setDefault(self, name, val)
      res = self;
      cid = self.translateChannel(name);
      self.default_override{cid} = val;
    end

    function plot(self, varargin)
      if nargin <= 1
        error('Please specify at least one channel to plot.');
      end

      cids = [];
      names = {};
      for i = 1:(nargin - 1)
        arg = varargin{i};
        if ~ischar(arg)
          error('Channel name has to be a string');
        end
        if arg(end) == '/'
          matches = regexp(arg, '^(.*[^/])/*$', 'tokens');
          prefix = self.config.translateChannel(matches{1}{1});
          prefix_len = size(prefix, 2);

          for cid = 1:size(self.orig_channel_names, 2)
            orig_name = self.orig_channel_names{cid};
            if isempty(orig_name)
              continue;
            end
            name = self.config.translateChannel(orig_name);
            if strncmp(prefix, name, prefix_len)
              cids(end + 1) = cid;
              names{end + 1} = orig_name;
            end
          end
        elseif arg(1) == '~'
          arg = arg(2:end);

          for cid = 1:size(self.orig_channel_names, 2)
            orig_name = self.orig_channel_names{cid};
            if isempty(orig_name)
              continue;
            end
            name = self.config.translateChannel(orig_name);
            if ~isempty(regexp(name, arg))
              cids(end + 1) = cid;
              names{end + 1} = orig_name;
            end
          end
        else
          try
            cid = self.findChannelId(arg);
          catch
            error('Channel does not exist.');
          end
          cids(end + 1) = cid;
          names{end + 1} = arg;
        end
      end

      if size(cids, 2) == 0
        error('No channel to plot.');
      end

      self.plotReal(cids, names);
    end
    function name = channelName(self, cid)
      name = self.chn_manager.channels{cid};
    end

    function vals = getValues(self, dt, varargin)
      total_t = self.length();
      nstep = floor(total_t / dt) + 1;
      nchn = nargin - 2;

      vals = zeros(nchn, nstep);
      for i = 1:nchn
        chn = varargin{i};
        if isnumeric(chn)
          scale = 1;
        else
          scale = chn{2};
          chn = chn{1};
        end
        pulses = self.getPulseTimes(chn);

        pidx = 1;
        vidx = 1;
        npulses = size(pulses, 1);

        cur_value = self.getDefault(chn);

        while pidx <= npulses
          %% At the beginning of each loop, pidx points to the pulse to be
          %% processed, vidx points to the value to be filled, cur_value is the
          %% value of the channel right before vidx

          %% First fill the values before the next pulse starts
          pulse = pulses(pidx, :);
          %% Index before next time
          next_vidx = ceil(pulse{1} / dt);
          if next_vidx >= vidx
            vals(i, vidx:next_vidx) = cur_value * scale;
          end
          next_time = next_vidx * dt;
          vidx = next_vidx + 1;

          %% Now find the last pulse that starts no later than the next point.
          cur_pulse = {};
          while true
            %% At the beginning of each loop, pidx and pulse points to the
            %% pulse to be processed, vidx should never change and should
            %% points to value to be filled, cur_value is value at the end of
            %% the last pulse
            switch pulse{2}
              case TimeType.Dirty
                pulse_obj = pulse{3};
                cur_value = pulse_obj.calcValue(pulse{8}, pulse{5}, cur_value);
                pidx = pidx + 1;
                if pidx > npulses
                  %% End of pulses
                  pidx = 0;
                  break;
                end
                pulse = pulses(pidx, :);
                if pulse{1} > next_time
                  break;
                end
              case TimeType.Start
                pidx = pidx + 1;
                if pidx > npulses || pulse{7} ~= pulses{pidx, 7}
                  error('Unmatch pulse start and end.');
                end
                pulse_end = pulses(pidx, :);
                if pulse_end{1} > next_time
                  cur_pulse = pulse;
                  break;
                end
                pulse_obj = pulse{3};
                %% Forward to the end of the pulse since it is shorter than
                %% our time interval.
                cur_value = pulse_obj.calcValue(pulse_end{1} - pulse{4}, ...
                                                pulse{5}, cur_value);
                pidx = pidx + 1;
                if pidx > npulses
                  %% End of pulses
                  pidx = 0;
                  break;
                end
                pulse = pulses(pidx, :);
                if pulse{1} > next_time
                  break;
                end
              otherwise
                error('Invalid pulse type.');
            end
          end

          %% There are three possibilities when we exit the loop
          %% 1. we are at the end of the pulses:
          %%     Just fill the rest of the sequence with the current value
          %%     and done for the channel.
          if ~pidx
            break;
          end
          %% 2. all the processed pulses finishes before the next time point
          %%     Finish the current process and run the next loop.
          if isempty(cur_pulse)
            continue;
          end
          %% 3. we've started a pulse and it continues pass the next time point
          %%     Calculate values for this pulse and run the next loop.
          last_vidx = ceil(pulse_end{1} / dt);
          idxs = vidx:last_vidx;
          pulse_obj = pulse{3};
          vals(i, idxs) = pulse_obj.calcValue((idxs - 1) * dt - pulse{4}, ...
                                              pulse{5}, cur_value) * scale;
          cur_value = pulse_obj.calcValue(pulse_end{1} - pulse{4}, ...
                                          pulse{5}, cur_value);
          pidx = pidx + 1;
          vidx = last_vidx + 1;
        end
        vals(i, vidx:end) = cur_value * scale;
      end
    end

    function vals = getDefaults(self, cids)
      %% @cid: a column array of channel id numbers
      if isnumeric(cids)
        vals = self.getDefault(cids);
      else
        nchn = size(cids, 1);
        vals = zeros(nchn, 1);
        for i = 1:nchn
          vals(i) = self.getDefault(cids(i));
        end
      end
    end
  end

  methods(Access=protected)
    function id = nextPulseId(self)
      self.pulse_id_counter = self.pulse_id_counter + 1;
      id = self.pulse_id_counter;
    end
    function id = nextSeqId(self)
      self.seq_id_counter = self.seq_id_counter + 1;
      id = self.seq_id_counter;
    end
    function val = getDefault(self, cid)
      try
        val = self.default_override{cid};
        if ~isempty(val)
          return;
        end
      catch
      end
      name = self.channelName(cid);
      try
        val = self.config.defaultVals(name);
      catch
        val = 0;
      end
    end
  end

  methods(Access=private)
    function [driver, driver_name] = initDeviceDriver(self, did)
      driver_name = self.config.pulseDrivers(did);
      driver = self.findDriver(driver_name);
      driver.initDev(did);
    end

    function logDefault(self)
      for key = self.config.defaultVals.keys
        self.logf('# Default value %s = %f', ...
                  key{:}, self.config.defaultVals(key{:}));
      end
    end

    function plotReal(self, cids, names)
      cids = num2cell(cids);
      len = self.length();
      dt = len / 1e4;
      data = self.getValues(dt, cids{:})';
      ts = (1:size(data, 1)) * dt;
      plot(ts, data);
      xlabel('t / s');
      legend(names{:});
    end
  end
end
