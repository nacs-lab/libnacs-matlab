%% Copyright (c) 2014-2017, Yichao Yu <yyc1992@gmail.com>
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
    % ExpSeq is an object representing the entire experimental sequence.
    % ExpSeq adds properties related to hardware, ie the drivers and channels.

    %Methods:  %self = ExpSeq(name)
    %cid = translateChannel(self, name)
    %cid = findChannelId(self, name)
    %driver = findDriver(self, driver_name)
    %generate(self)
    %run_async(self)
    %waitFinish(self)
    %run(self)
    %res = setDefault(self, name, val)
    %plot(self, varargin)
    %id = nextPulseId(self)
    %id = nextSeqId(self)
    %val = getDefault(self, cid)
    %[driver, driver_name] = initDeviceDriver(self, did)
    %logDefault(self)
    %plotReal(self, cids, names)
    properties
        drivers;            % map with key values 'FPGABackend' 'NiDACBackend'. This is updated when channel is used in a pulse, so it starts empty.
        driver_cids;        %
        generated = false;  %
        default_override = false(0);
        default_override_val = [];
        orig_channel_names = {};
        cid_cache;          %
        chn_manager;        %
        before_start_cbs = {};
        drivers_sorted;
        output_manager = {};
        pulses_overwrite = {};
        cached_length = -1;
    end

    methods
        function self = ExpSeq(varargin)
            % Contstructor. Uses ExpSeqBase contructor to initializes, then
            % populate new properties with empty cells and maps. After the
            % contrutor, only the chn_manager, config, and logger properties
            % are populated.
            if nargin > 1
                error('Too many arguments for ExpSeq.');
            elseif nargin == 1 && ~isstruct(varargin{1})
                error('Constant input must be a struct.');
            end
            self = self@ExpSeqBase(varargin{:});
            self.chn_manager = ChannelManager();
            self.drivers = containers.Map();
            self.driver_cids = containers.Map();
            self.cid_cache = containers.Map('KeyType', 'char', 'ValueType', 'double');
        end

        function res=length(self)
            % Note that this length does not account for the timing
            % difference caused by output managers.
            if self.cached_length > 0
                res = self.cached_length;
                return;
            end
            res = length@ExpSeqBase(self);
        end

        function mgr = addOutputMgr(self, chn, cls, varargin)
            chn = translateChannel(self, chn);
            mgr = cls(self, chn, varargin{:});
            self.output_manager{chn} = mgr;
        end

        function cid = translateChannel(self, name)
            [cid, name, inited] = getChannelId(self, name);
            if inited || checkChannelDisabled(self.config, name)
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

        function generate(self, preserve)
            if ~self.generated
                if ~exist('preserve', 'var')
                    preserve = 0;
                end
                self.cached_length = self.length();
                if self.config.maxLength > 0 && self.length() > self.config.maxLength
                    error('Sequence length %f exceeds max sequence length of maxLength=%f', ...
                          self.length(), self.config.maxLength);
                end
                fprintf('|');
                populateChnMask(self, length(self.chn_manager.channels));
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
                drivers = {};
                for driver = self.drivers.values()
                    drivers = [drivers; {driver{:}, -driver{:}.getPriority()}];
                end
                if ~isempty(drivers)
                    drivers = sortrows(drivers, [2]);
                end
                self.drivers_sorted = drivers(:, 1);
                self.generated = true;
                if ~preserve
                    self.default_override = false(0);
                    self.default_override_val = [];
                    self.orig_channel_names = [];
                    self.cid_cache = [];
                    self.chn_manager = [];
                    self.output_manager = [];
                    self.pulses_overwrite = [];
                    % NiDAC backend currently need config
                    self.subSeqs = [];
                end
            end
        end

        function run_async(self)
            % Do **NOT** put anything related to runSeq in this file!!!!!!!!!!
            % It messes up EVERYTHING!!!!!!!!!!!!!!!!!!!!!!
            global nacsExpSeqDisableRunHack;
            if ~isempty(nacsExpSeqDisableRunHack) && nacsExpSeqDisableRunHack
                return;
            end
            generate(self);
            run_real(self);
        end

        function run_real(self)
            drivers = self.drivers_sorted;
            if ~isempty(self.before_start_cbs)
                for cb = self.before_start_cbs
                    cb{:}();
                end
            end
            for i = 1:length(drivers)
                run(drivers{i});
            end
        end

        function res=regBeforeStart(self, cb)
            %% Register a callback function that will be executed before
            % the sequence run.
            % The callbacks will be called in the order they are registerred
            % without any arguments.
            self.before_start_cbs{end + 1} = cb;
            res = self;
        end

        function waitFinish(self)
            % Do **NOT** put anything related to runSeq in this file!!!!!!!!!!
            % It messes up EVERYTHING!!!!!!!!!!!!!!!!!!!!!!
            global nacsExpSeqDisableRunHack;
            if ~isempty(nacsExpSeqDisableRunHack) && nacsExpSeqDisableRunHack
                return;
            end
            drivers = self.drivers_sorted;
            for i = 1:length(drivers)
                wait(drivers{i, 1});
            end
        end

        function run(self)
            % run(self[ExpSeq])
            % Used to run the experimental sequence. Calls the methods
            % run_async() and waitFinish(), which are very similar codes.
            % run_async() calls the prepare and generate methods on the
            % drivers (using the generate() method),  and then applies the
            % run method on the driver objects.  waitFinish() just applies the
            % wait() method on the drivers.
            % Do **NOT** put anything related to runSeq in this file!!!!!!!!!!
            % It messes up EVERYTHING!!!!!!!!!!!!!!!!!!!!!!
            % Also, this function has to be only run_async() and then
            % waitFinish() do not put any more complex logic in.
            % DisableRunHack is fine since it doesn't mutate anything.
            global nacsExpSeqDisableRunHack;
            if ~isempty(nacsExpSeqDisableRunHack) && nacsExpSeqDisableRunHack
                return;
            end
            self.run_async();
            fprintf('Running @%s\n', datestr(now(), 'yyyy/mm/dd HH:MM:SS'));
            self.waitFinish();
        end

        function res = setDefault(self, name, val)
            res = self;
            if isnumeric(name)
                cid = name;
            else
                cid = translateChannel(self, name);
            end
            self.default_override(cid) = true;
            self.default_override_val(cid) = val;
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

                    for cid = 1:length(self.orig_channel_names)
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

                    for cid = 1:length(self.orig_channel_names)
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
            nstep = fld(total_t, dt) + 1;
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
                    next_vidx = cld(pulse{1}, dt);
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
                                if isnumeric(pulse_obj)
                                    cur_value = pulse_obj;
                                else
                                    cur_value = calcValue(pulse_obj, pulse{7}, ...
                                                          pulse{5}, cur_value);
                                end
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
                                if pidx > npulses
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
                                cur_value = calcValue(pulse_obj, pulse_end{1} - pulse{4}, ...
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
                    last_vidx = cld(pulse_end{1}, dt);
                    idxs = vidx:last_vidx;
                    pulse_obj = pulse{3};
                    vals(i, idxs) = calcValue(pulse_obj, (idxs - 1) * dt - pulse{4}, ...
                                              pulse{5}, cur_value) * scale;
                    cur_value = calcValue(pulse_obj, pulse_end{1} - pulse{4}, ...
                                          pulse{5}, cur_value);
                    pidx = pidx + 1;
                    vidx = last_vidx + 1;
                end
                vals(i, vidx:end) = cur_value * scale;
            end
        end

        function res = getPulseTimes(self, cid)
            res = {};
            pulses = self.getPulses(cid);
            for i = 1:size(pulses, 1)
                pulse = pulses(i, :);
                toffset = pulse{1};
                step_len = pulse{2};
                pulse_obj = pulse{3};
                if isnumeric(pulse_obj)
                    res(end + 1, 1:7) = {toffset, int32(TimeType.Dirty), pulse_obj, ...
                                         toffset, step_len, cid, 0};
                else
                    res(end + 1, 1:7) = {toffset, int32(TimeType.Start), pulse_obj, ...
                                         toffset, step_len, cid, 0};
                    res(end + 1, 1:7) = {toffset + step_len, int32(TimeType.End), pulse_obj, ...
                                         toffset, step_len, cid, step_len};
                end
            end
            if ~isempty(res)
                res = sortrows(res, [1, 2, 7]);
            end
        end

        function res = getPulses(self, cid)
            %% Return a array of tuples (toffset, length, pulse_obj)
            %  the pulse_obj should be a number or have a method calcValue that take 3 parameters:
            %      time_in_pulse, length, old_val_before_pulse
            %  and should return the new value @time_in_pulse after the step_start.
            %  The returned value should be sorted with toffset.
            %
            %  This must be run after `populateMask`
            if length(self.pulses_overwrite) >= cid && ~isempty(self.pulses_overwrite{cid})
                res = self.pulses_overwrite{cid};
                return;
            end
            res = appendPulses(self, cid, {}, 0);
            if ~isempty(res)
                res = sortrows(res', 1);
            end
            if length(self.output_manager) >= cid && ~isempty(self.output_manager{cid})
                res = processPulses(self.output_manager{cid}, res);
                self.pulses_overwrite{cid} = res;
            end
        end
        function val = getDefault(self, cid)
            if length(self.default_override) >= cid && self.default_override(cid)
                val = self.default_override_val(cid);
                return;
            end
            name = channelName(self, cid);
            if isKey(self.config.defaultVals, name)
                val = self.config.defaultVals(name);
            else
                val = 0;
            end
        end
        function disableChannel(self, name)
            % This check is in principle O(M * N) in total
            % where M is No of disabled channel and N is No of used channel.
            % However, in practice the disable channel should only be called
            % at the beginning of the sequence so this shouldn't be too bad.
            name = translateChannel(self.config, name);
            % `getChannelId` guarantees that all translated names used are in `cid_cache`
            for key = keys(self.cid_cache)
                % This should not have false positive disabled channels
                % for the same reason as `SeqConfig::checkChannelDisabled`.
                % name is always translated here.
                key = key{:};
                if strcmp(key, name) || startsWith(key, [name, '/'])
                    error('Cannot disable channel that is already initialized');
                end
            end
            disableChannel(self.config, name);
        end
    end

    methods(Access=protected)
        function t=globalPath(self)
            t = {};
        end
    end

    methods(Access=private)
        function [cid, name, inited] = getChannelId(self, name)
            inited = true;
            if isKey(self.cid_cache, name)
                cid = self.cid_cache(name);
                return;
            end
            orig_name = name;
            name = translateChannel(self.config, name);
            cid = getId(self.chn_manager, name);
            self.cid_cache(orig_name) = cid;
            if !strcmp(name, orig_name)
                % This makes sure that disableChannel
                % could iterate over all the translated names.
                self.cid_cache(name) = cid;
            end

            if (cid > length(self.orig_channel_names) || ...
                isempty(self.orig_channel_names{cid}))
                self.orig_channel_names{cid} = orig_name;
                inited = false;
            end
        end

        function [driver, driver_name] = initDeviceDriver(self, did)
            driver_name = self.config.pulseDrivers(did);
            driver = self.findDriver(driver_name);
            driver.initDev(did);
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
    methods(Static)
        function reset()
            global nacsExpSeqDisableRunHack;
            nacsExpSeqDisableRunHack = 0;
        end
    end
end
