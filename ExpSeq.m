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
            cid = findChannelId@ExpSeqBase(self, name);
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
            %       beep;
        end
        
        function res = setDefault(self, name, val)
            res = self;
            cid = self.translateChannel(name);
            self.default_override{cid} = val;
            
            % self.logf('# Override default value %s(%s) = %f', ...
            %     name, self.channelName(cid), val);
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