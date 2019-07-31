%% Copyright (c) 2014-2018, Yichao Yu <yyc1992@gmail.com>
%
% This library is free software; you can redistribute it and/or
% modify it under the terms of the GNU Lesser General Public
% License as published by the Free Software Foundation; either
% version 3.0 of the License, or (at your option) any later version.
% This library is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
% Lesser General Public License for more details.
% You should have received a copy of the GNU Lesser General Public
% License along with this library.

classdef ExpSeq < ExpSeqBase
    %% `ExpSeq` is the object representing the entire experimental sequence (root node).
    % In additional to other properties and APIs provided for manipulating the
    % tree structure (timing APIs in `ExpSeqBase`), this contains global information
    % and API for the whole sequence including global sequence settings, e.g.
    % override, start and end callbacks, channel manager etc., and APIs related
    % to generating and running the sequence.
    properties
        %% Generation/driver related:
        % Map from driver name to driver instance
        drivers;
        % Map from driver name to the list of channel IDs managed by the driver
        driver_cids; % ::containers.Map
        % Drivers sorted in the order they should be run and waited.
        drivers_sorted;
        generated = false;
        % The total time of the sequence is cached before generation.
        cached_total_time = -1;

        %% Channel management:
        % The channel name used when the channel is first added, indexed by channel ID.
        % Only used for plotting.
        orig_channel_names = {};
        % The translated channel names.
        % (This is unique for each channel independent of what the user uses and
        % can be relied on by the backends. See `channelName`.)
        channel_names = {};
        % Map from channel name to channel ID.
        % Include both translated name and untranslated ones as keys.
        cid_cache;

        %% Output related:
        % Whether the default has been overwritten and the new default value.
        % Indexed by the channel ID.
        default_override = false(0);
        default_override_val = [];
        % Output managers indexed by channel ID.
        % These are classes that can process the output (time and value)
        % of a channel after the whole sequence is constructed using the global
        % information of the sequence that's only available at this time.
        % See `TTLMgr` for an example.
        output_manager = {};
        % Cache of the output manager output.
        pulses_overwrite = {};

        %% Running related:
        % Callback to be called (without argument) before the sequence start
        before_start_cbs = {};
        % Callback to be called (without argument) after the sequence finishes
        after_end_cbs = {};

        %% IR stuff
        % For dealing with code generation within the sequence.
        ir_ctx;
    end

    methods
        function self = ExpSeq(varargin)
            if nargin > 1
                error('Too many arguments for ExpSeq.');
            elseif nargin == 1 && ~isstruct(varargin{1})
                error('Constant input must be a struct.');
            end
            self = self@ExpSeqBase(varargin{:});
            self.drivers = containers.Map();
            self.driver_cids = containers.Map();
            self.cid_cache = containers.Map('KeyType', 'char', 'ValueType', 'double');
            self.ir_ctx = IRContext();
        end

        function res = totalTime(self)
            % Note that this total time does not account for the timing
            % difference caused by output managers.
            if self.cached_total_time > 0
                res = self.cached_total_time;
                return;
            end
            res = totalTime@ExpSeqBase(self);
        end

        function mgr = addOutputMgr(self, chn, cls, varargin)
            %% Add an output manager for the channel
            % See `output_manager` above.
            chn = translateChannel(self, chn);
            mgr = cls(self, chn, varargin{:});
            self.output_manager{chn} = mgr;
        end

        function cid = translateChannel(self, name)
            %% Convert a channel name to a channel ID.
            % A new ID is created if it does not exist yet.
            [cid, name, inited] = getChannelId(self, name);
            if inited || checkChannelDisabled(self.config, name)
                return;
            end
            cpath = strsplit(name, '/');
            did = cpath{1};
            [driver, driver_name] = initDeviceDriver(self, did);

            driver.initChannel(cid);
            cur_cids = self.driver_cids(driver_name);
            self.driver_cids(driver_name) = unique([cur_cids, cid]);
        end

        function driver = findDriver(self, driver_name)
            %% Lazily create driver of the given name.
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
            %% Called after the sequence is fully constructed.
            % Collect global information (e.g. totla time, channel mask)
            % before letting drivers generating their output (cached in driver if needed).
            if ~self.generated
                if ~exist('preserve', 'var')
                    preserve = 0;
                end
                self.cached_total_time = totalTime(self);
                if self.config.maxLength > 0 && totalTime(self) > self.config.maxLength
                    error('Sequence length %f exceeds max sequence length of maxLength=%f', ...
                          totalTime(self), self.config.maxLength);
                end
                fprintf('|');
                populateChnMask(self, length(self.channel_names));
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
                    self.drivers_sorted = drivers(:, 1);
                end
                self.generated = true;
                if ~preserve
                    self.default_override = false(0);
                    self.default_override_val = [];
                    self.orig_channel_names = [];
                    self.channel_names = [];
                    self.cid_cache = [];
                    self.output_manager = [];
                    self.pulses_overwrite = [];
                    % NiDAC backend currently need config
                    self.subSeqs = [];
                end
            end
        end

        function run_async(self)
            %% Start the run and return.
            % Generate the sequence first if it is not done yet.
            %
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
            %% Similar to `run_async` but more lower level.
            % Assume the generation is already done and does not check the
            % disable run flag.
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

        function self = regBeforeStart(self, cb)
            %% Register a callback function that will be executed before
            % the sequence run.
            % The callbacks will be called in the order they are registerred
            % without any arguments.
            self.before_start_cbs{end + 1} = cb;
        end

        function self = regAfterEnd(self, cb)
            %% Register a callback function that will be executed after
            % the sequence ends.
            % The callbacks will be called in the order they are registerred
            % without any arguments.
            self.after_end_cbs{end + 1} = cb;
        end

        function waitFinish(self)
            %% Wait for the sequences to finish.
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
            if ~isempty(self.after_end_cbs)
                for cb = self.after_end_cbs
                    cb{:}();
                end
            end
        end

        function run(self)
            %% Run the sequence (after generating) and wait for it to finish.
            % Do **NOT** put anything related to runSeq in this file!!!!!!!!!!
            % It messes up EVERYTHING!!!!!!!!!!!!!!!!!!!!!!
            % Also, this function has to be only run_async() and then
            % waitFinish() do not put any more complex logic in.
            % DisableRunHack is fine since it doesn't mutate anything.
            global nacsExpSeqDisableRunHack;
            if ~isempty(nacsExpSeqDisableRunHack) && nacsExpSeqDisableRunHack
                return;
            end
            run_async(self);
            fprintf('Running @%s\n', datestr(now(), 'yyyy/mm/dd HH:MM:SS'));
            waitFinish(self);
        end

        function self = setDefault(self, name, val)
            %% Override default value in the `expConfig`.
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
            populateChnMask(self, length(self.channel_names));

            cids = [];
            names = {};
            for i = 1:(nargin - 1)
                arg = varargin{i};
                if ~ischar(arg)
                    error('Channel name has to be a string');
                end
                if arg(end) == '/'
                    matches = regexp(arg, '^(.*[^/])/*$', 'tokens');
                    prefix = translateChannel(self.config, matches{1}{1});
                    prefix_len = size(prefix, 2);

                    for cid = 1:length(self.orig_channel_names)
                        orig_name = self.orig_channel_names{cid};
                        if isempty(orig_name)
                            continue;
                        end
                        name = translateChannel(self.config, orig_name);
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
                        name = translateChannel(self.config, orig_name);
                        if ~isempty(regexp(name, arg))
                            cids(end + 1) = cid;
                            names{end + 1} = orig_name;
                        end
                    end
                else
                    name = translateChannel(self.config, arg);
                    if isKey(self.cid_cache, name)
                        % Look up the name without creating an ID
                        cid = self.cid_cache(name);
                    else
                        error('Channel %s does not exist.', arg);
                    end
                    cids(end + 1) = cid;
                    names{end + 1} = arg;
                end
            end

            if size(cids, 2) == 0
                error('No channel to plot.');
            end

            plotReal(self, cids, names);
        end

        function name = channelName(self, cid)
            name = self.channel_names{cid};
        end

        function vals = getValues(self, dt, varargin)
            total_t = totalTime(self);
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
                pulses = getPulseTimes(self, chn);

                pidx = 1;
                vidx = 1;
                npulses = size(pulses, 1);

                cur_value = getDefault(self, chn);

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
            pulses = getPulses(self, cid);
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
            %% Return 3-row cell array with each column being `toffset, length, pulse_obj`.
            % The `pulse_obj` should be a number or a `PulseBase` (see `PulseBase::calcValue`).
            % See `ExpSeqBase::appendPulses`.
            % The returned value should be sorted with toffset.
            %
            % This must be run after `populateMask`
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
            %% Disable channels with the prefix `name` (so `$name/...` or `name` itself)
            % Disabled channels are still added to the sequence but are hidden from the backend.
            name = translateChannel(self.config, name);
            % This check is in principle O(M * N) in total
            % where M is No of disabled channel and N is No of used channel.
            % However, in practice the disable channel should only be called
            % at the beginning of the sequence so this shouldn't be too bad.
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
        function t = globalPath(self)
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
            cid = length(self.channel_names) + 1;
            self.channel_names{cid} = name;
            % This makes sure that disableChannel
            % could iterate over all the translated names.
            self.cid_cache(name) = cid;
            if ~strcmp(name, orig_name)
                self.cid_cache(orig_name) = cid;
            end

            if (cid > length(self.orig_channel_names) || ...
                isempty(self.orig_channel_names{cid}))
                self.orig_channel_names{cid} = orig_name;
                inited = false;
            end
        end

        function [driver, driver_name] = initDeviceDriver(self, did)
            driver_name = self.config.pulseDrivers(did);
            driver = findDriver(self, driver_name);
            initDev(driver, did);
        end

        function plotReal(self, cids, names)
            cids = num2cell(cids);
            len = totalTime(self);
            dt = len / 1e6;
            data = getValues(self, dt, cids{:})';
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
