%% Copyright (c) 2014-2021, Yichao Yu <yyc1992@gmail.com>
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

classdef ExpSeq < RootSeq
    %% `ExpSeq` is the object representing the entire experimental sequence (root node).
    % In additional to other properties and APIs provided for manipulating the
    % tree structure (timing APIs in `ExpSeqBase`), this contains global information
    % and API for the whole sequence including global sequence settings, e.g.
    % override, start and end callbacks, etc., and APIs related
    % to generating and running the sequence.
    properties
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
        % Locally disabled channels
        disabled_channels;
        % Map from original channel ID to channel ID with disabled channel taken into account.
        % Disabled channels have ID 0.
        cid_map;

        %% Output related:
        % Whether the default has been overwritten and the new default value.
        % Indexed by the channel ID.
        default_override = false(0);
        default_override_val = [];

        ttl_managers = struct('chn', {}, 'off_delay', {}, 'on_delay', {}, ...
                              'skip_time', {}, 'min_time', {}, 'off_val', {});

        seq_ctx;
        basic_seqs = {};
        time_scale = 1e12;
        globals = struct('id', {}, 'persist', {}, 'init_val', {});

        %% Whole sequence callbacks
        before_start_cbs = {};
        after_end_cbs = {};

        %% Runtime
        pyseq;
        ni_channels;
    end

    properties(Constant, Access=private)
        disabled = MutableRef(false);
    end

    methods
        function self = ExpSeq(C_ovr)
            % As top-level `ExpSeq`.
            self.config = SeqConfig.get(1);
            self.topLevel = self;
            self.root = self;
            C = struct();
            consts = self.config.consts;
            fields = fieldnames(consts);
            for i = 1:length(fields)
                fn = fields{i};
                C.(fn) = consts.(fn);
            end
            if exist('C_ovr', 'var')
                if ~isstruct(C_ovr)
                    error('Constant input must be a struct.');
                end
                % Allow parameters to overwrite consts in config
                fields = fieldnames(C_ovr);
                for i = 1:length(fields)
                    fn = fields{i};
                    C.(fn) = C_ovr.(fn);
                end
            end
            self.time_scale = SeqManager.tick_per_sec();
            self.C = DynProps(C);
            self.G = self.config.G;
            self.cid_cache = containers.Map('KeyType', 'char', 'ValueType', 'double');
            self.seq_ctx = SeqContext();
            self.disabled_channels = containers.Map('KeyType', 'char', ...
                                                    'ValueType', 'double');
            self.bseq_id = 1;
            self.zero_time = SeqTime.zero(self);
            self.curSeqTime = self.zero_time;
        end

        function bseq = newBasicSeq(self, cb, varargin)
            % can use a callback, cb, to populate the new BasicSeq
            bseq = BasicSeq(self);
            if exist('cb', 'var')
                cb(bseq, varargin{:});
            end
        end

        function addTTLMgr(self, chn, off_delay, on_delay, ...
                           skip_time, min_time, off_val)
            if ~exist('off_val', 'var')
                off_val = false;
            end
            % Only translate the name at this time since we don't want to assigned
            % a channel ID, (and therefore mark them used and initializing them)
            % just because we've specified the properties of these channels.
            chn = translateChannel(self.config, chn);
            self.ttl_managers(end + 1) = struct('chn', chn, 'off_delay', off_delay, ...
                                                'on_delay', on_delay, 'skip_time', skip_time, ...
                                                'min_time', min_time, 'off_val', off_val);
        end

        function cid = translateChannel(self, name)
            %% Convert a channel name to a channel ID.
            % A new ID is created if it does not exist yet.
            cid = getChannelId(self, name);
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

        function name = channelName(self, cid)
            name = self.channel_names{cid};
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
            if isempty(self.disabled_channels) && ~self.G.localDisableWarned(false)
                self.G.localDisableWarned = true;
                warning('Channel disabled locally.');
            end
            self.disabled_channels(name) = 0;
        end
        %% name is assumed to be translated. Returns false for untranslated name.
        function res = checkChannelDisabled(self, name)
            % See `SeqConfig::checkChannelDisabled`
            for key = keys(self.disabled_channels)
                key = key{:};
                if strcmp(name, key)
                    res = true;
                    return;
                elseif startsWith(name, [key, '/'])
                    res = true;
                    return;
                end
            end
            res = checkChannelDisabled(self.config, name);
        end

        function res = toString(self, indent)
            if ~exist('indent', 'var')
                indent = 0;
            end
            res = toString@RootSeq(self, indent);
            for i = 1:length(self.basic_seqs)
                res = [res char(10) char(10) toString(self.basic_seqs{i}, indent)];
            end
        end

        function res = serialize(self)
            % Format:
            %   [version <0>: 1B]
            %   [nnodes: 4B]
            %   [[[OpCode: 1B][[ArgType: 1B][NodeArg: 1-8B] x narg] /
            %     [OpCode <Interp>: 1B][[ArgType: 1B][NodeArg: 1-8B] x 3][data_id: 4B]] x nnodes]
            %   [nchns: 4B][[chnname: non-empty NUL-terminated string] x nchns]
            %   [ndefvals: 4B][[chnid: 4B][Type: 1B][value: 1-8B] x ndefvals]
            %   [nslots: 4B][[Type: 1B] x nslots]
            %   [nnoramp: 4B][[chnid: 4B] x nnoramp]
            %   [nbasicseqs: 4B][[Basic Sequence] x nbasicseqs]
            %   [ndatas: 4B][[ndouble: 4B][data: 8B x ndouble] x ndatas]
            %   [nbackenddatas: 4B][[device_name: NUL-terminated string]
            %                       [size: 4B][data: size B] x nbackenddatas]

            nchns = length(self.channel_names);
            % [nchns: 4B]
            chn_serialized = int8([]);
            cid_map = zeros(1, nchns, 'uint32');
            cid = 1;
            for i = 1:nchns
                % [chnname: non-empty NUL-terminated string]
                chnname = self.channel_names{i};
                if checkChannelDisabled(self, chnname)
                    continue;
                end
                cid_map(i) = cid;
                cid = cid + 1;
                assert(~isempty(chnname));
                chn_serialized = [chn_serialized int8(chnname) int8(0)];
            end
            chn_serialized = [typecast(uint32(cid - 1), 'int8'), chn_serialized];
            self.cid_map = cid_map;

            ndefvals = 0;
            defval_serialized = int8([]);
            for i = 1:nchns
                cid = cid_map(i);
                if cid == 0
                    continue;
                end
                % [chnid: 4B][Type: 1B][value: 1-8B]
                defval = getDefault(self, i);
                assert(islogical(defval) || isnumeric(defval));
                assert(isscalar(defval));
                if defval == 0
                    continue;
                end
                if islogical(defval)
                    assert(defval);
                    defval_serialized = [defval_serialized, ...
                                         typecast(cid, 'int8'), ...
                                         SeqVal.TypeBool, int8(1)];
                elseif isa(defval, 'int32')
                    defval_serialized = [defval_serialized, ...
                                         typecast(cid, 'int8'), ...
                                         SeqVal.TypeInt32, typecast(defval, 'int8')];
                else
                    defval = double(defval);
                    defval_serialized = [defval_serialized, ...
                                         typecast(cid, 'int8'), ...
                                         SeqVal.TypeFloat64, typecast(defval, 'int8')];
                end
                ndefvals = ndefvals + 1;
            end
            % [ndefvals: 4B]
            defval_serialized = [typecast(uint32(ndefvals), 'int8') defval_serialized];

            % [nbasicseqs: 4B][[Basic Sequence] x nbasicseqs]
            nbasicseqs = length(self.basic_seqs) + 1;
            bseqs = cell(1, nbasicseqs);
            bseqs{1} = serializeBSeq(self);
            for i = 2:nbasicseqs
                bseqs{i} = serializeBSeq(self.basic_seqs{i - 1});
            end
            bseqs_serialized = [typecast(uint32(nbasicseqs), 'int8') bseqs{:}];

            % [nbackenddatas: 4B][[device_name: NUL-terminated string]
            %                     [size: 4B][data: size B] x nbackenddatas]
            backenddata_serailized = serializeBackendData(self);

            seq_ctx = self.seq_ctx;
            % [version <0>: 1B]
            % [nnodes: 4B]
            % [[[OpCode: 1B][[ArgType: 1B][NodeArg: 1-8B] x narg] /
            %   [OpCode <Interp>: 1B][[ArgType: 1B][NodeArg: 1-8B] x 3][data_id: 4B]] x nnodes]
            % [nchns: 4B][[chnname: non-empty NUL-terminated string] x nchns]
            % [ndefvals: 4B][[chnid: 4B][Type: 1B][value: 1-8B] x ndefvals]
            % [nslots: 4B][[Type: 1B] x nslots]
            % [nnoramp: 4B][[chnid: 4B] x nnoramp]
            % [nbasicseqs: 4B][[Basic Sequence] x nbasicseqs]
            % [ndatas: 4B][[ndouble: 4B][data: 8B x ndouble] x ndatas]
            % [nbackenddatas: 4B][[device_name: NUL-terminated string]
            %                     [size: 4B][data: size B] x nbackenddatas]
            res = [int8(0), nodeSerialized(seq_ctx), chn_serialized, defval_serialized, ...
                   globalSerialized(seq_ctx), int8([0, 0, 0, 0]), bseqs_serialized, ...
                   dataSerialized(seq_ctx), backenddata_serailized];
        end

        function self = regBeforeStart(self, cb)
            %% Register a callback function that will be executed before
            % the sequence runs.
            % The callbacks will be called in the order they are registerred
            % with the sequence as the argument.
            self.before_start_cbs{end + 1} = cb;
        end

        function self = regAfterEnd(self, cb)
            %% Register a callback function that will be executed after
            % the sequence ends.
            % The callbacks will be called in the order they are registerred
            % with the sequence as the argument.
            self.after_end_cbs{end + 1} = cb;
        end

        function generate(self, preserve)
            %% Called after the sequence is fully constructed.
            if isempty(self.pyseq)
                if ~exist('preserve', 'var')
                    preserve = 0;
                end
                self.pyseq = SeqManager.create_sequence(serialize(self));
                ni_channel_info = get_nidaq_channel_info(self.pyseq, 'NiDAQ'); % Hardcode name
                self.ni_channels = cellfun(@(x) struct('chn', double(x{1}), ...
                                                       'dev', char(x{2})), ...
                                           cell(ni_channel_info));
                if ~preserve
                    releaseGeneration(self);
                end
                reset_globals(self, true);
            end
        end

        function val = get_global(self, g)
            if isempty(self.pyseq)
                error('Sequence must be generated before accessing globals.');
            end
            assert(isa(g, 'SeqVal') && g.head == SeqVal.HGlobal);
            val = get_global(self.pyseq, uint32(g.args{1}));
        end

        function set_global(self, g, val)
            if isempty(self.pyseq)
                error('Sequence must be generated before accessing globals.');
            end
            assert(isa(g, 'SeqVal') && g.head == SeqVal.HGlobal);
            set_global(self.pyseq, uint32(g.args{1}), double(val));
        end

        function [next_idx, bseq_len] = run_bseq(self, idx)
            if isempty(self.pyseq)
                error('Sequence must be generated before running.');
            end
%             if idx == 1
%                 tic;
%             end
            % Basic sequence 1 is the `ExpSeq`, the rest are in the `basic_seqs` array.
            if idx == 1
                bseq = self;
            else
                bseq = self.basic_seqs{idx - 1};
            end
            for cb = bseq.before_bseq_cbs
                cb{:}(self);
            end
%             before_seq_cb = toc
            pre_run(self.pyseq);
%             after_pre_run = toc
            if ~isempty(self.ni_channels)
                ni_nchns = length(self.ni_channels);
                ni_data_raw = get_nidaq_data(self.pyseq, 'NiDAQ');
%                 if ni_data_raw ~= py.NoneType
                    ni_data = double(ni_data_raw); % Hardcode name
                    ni_ndata = length(ni_data);
                    assert(mod(ni_ndata, ni_nchns) == 0);
                    NiDAQRunner.run(self.ni_channels, self.config.niClocks, self.config.niStart, ...
                                    reshape(ni_data, [ni_ndata / ni_nchns, ni_nchns]));
%                 end
            end
%             after_nidaq = toc
            start(self.pyseq);
%             after_start = toc
            while ~wait(self.pyseq, uint64(100))
            end
%             after_pyseq_wait = toc
            if ~isempty(self.ni_channels)
                NiDAQRunner.wait();
            end
%             after_nidaq_wait = toc
            for cb = bseq.after_bseq_cbs
                cb{:}(self);
            end
%             after_after_seq_cb = toc
            bseq_len = cur_bseq_length(self.pyseq);
            next_idx = double(post_run(self.pyseq));
%             after_post_run = toc
            for cb = bseq.after_branch_cbs
                cb{:}(self);
            end
%             after_after_branch = toc
        end

        function run_real(self)
            bseq_len = 0;
            try
                for cb = self.before_start_cbs
                    cb{:}(self);
                end
                init_run(self.pyseq);
                idx = 1;
                while idx ~= 0
                    start_t = now() * 86400;
                    [idx, bseq_len] = run_bseq(self, idx);
                end
                for cb = self.after_end_cbs
                    cb{:}(self);
                end
            catch E
                reset_globals(self, false);
                rethrow(E);
            end
            % Reset the globals
            % Do this after the sequence finishes instead of before start
            % so that we could observe values set before running the sequence.
            reset_globals(self, false);
            % We'll wait until this time before returning to the caller
            end_after = start_t + bseq_len / self.time_scale - 50e-3;
            end_t = now() * 86400;
            if end_t < end_after
                pause(end_after - end_t);
            end
        end

        function run(self)
            if ExpSeq.disabled.get()
                return;
            end
            if isempty(self.pyseq)
                fprintf('Generating...\n');
                generate(self);
            end
            fprintf('Running @%s\n', datestr(now(), 'yyyy/mm/dd HH:MM:SS'));
            SeqManager.new_run();
            run_real(self);
        end

        % For debug use only
        function res = get_builder_dump(self)
            res = char(get_builder_dump(self.pyseq));
        end
        function res = get_seq_dump(self)
            res = char(get_seq_dump(self.pyseq));
        end
        function res = get_seq_opt_dump(self)
            res = char(get_seq_opt_dump(self.pyseq));
        end

        function res = get_nidaq_channel_info(self, name)
            if ~exist('name', 'var')
                name = 'NiDAQ'; % Hardcode name
            end
            ni_channel_info = get_nidaq_channel_info(self.pyseq, name);
            res = cellfun(@(x) struct('chn', double(x{1}), 'dev', char(x{2})), ...
                          cell(ni_channel_info));
        end
        function res = get_nidaq_data(self, name)
            if ~exist('name', 'var')
                name = 'NiDAQ'; % Hardcode name
            end
            ni_nchns = length(self.ni_channels);
            ni_data = double(get_nidaq_data(self.pyseq, name));
            ni_ndata = length(ni_data);
            assert(mod(ni_ndata, ni_nchns) == 0);
            res = reshape(ni_data, [ni_ndata / ni_nchns, ni_nchns]);
        end
        function res = get_zynq_clock(self, name)
            clock = get_zynq_clock(self.pyseq, name);
            res = cellfun(@(x) struct('time', int64(x{1}), 'period', int64(x{2})), cell(clock));
        end
        function res = get_zynq_bytecode(self, name)
            res = uint8(get_zynq_bytecode(self.pyseq, name));
        end
    end

    methods(Access=?TimeSeq)
        function g = newGlobalReal(self, persist, type, init_val)
            if ~exist('init_val', 'var')
                init_val = 0;
            end
            if ~exist('type', 'var')
                type = SeqVal.TypeFloat64;
            end
            [g, id] = newGlobal(self.seq_ctx, type);
            self.globals(end + 1) = struct('id', id, 'persist', persist, ...
                                           'init_val', double(init_val));
        end
    end

    methods(Access=protected)
        function releaseGeneration(self)
            releaseGeneration@RootSeq(self);
            self.orig_channel_names = [];
            self.channel_names = [];
            self.cid_cache = [];
            self.disabled_channels = [];
            self.cid_map = [];

            self.default_override = false(0);
            self.default_override_val = [];

            self.ttl_managers = [];
            for i = 1:length(self.basic_seqs)
                releaseGeneration(self.basic_seqs{i});
            end
        end
    end

    methods(Access=private)
        function res = serializeBackendData(self)
            % [nbackenddatas: 4B][[device_name: NUL-terminated string]
            %                     [size: 4B][data: size B] x nbackenddatas]
            if isempty(self.ttl_managers)
                res = int8([0, 0, 0, 0]);
                return;
            end
            device_ttl_managers = containers.Map();
            cid_map = self.cid_map;
            for i = 1:length(self.ttl_managers)
                ttl_manager = self.ttl_managers(i);
                chnname = ttl_manager.chn;
                [devname, subname] = strtok(chnname, '/');
                if isempty(devname) || isempty(subname)
                    error('Invalid channel name "%s"', chnname);
                end
                if ~isKey(self.cid_cache, chnname)
                    continue;
                end
                cid = cid_map(self.cid_cache(chnname));
                off_delay = int32(ttl_manager.off_delay * self.time_scale);
                on_delay = int32(ttl_manager.on_delay * self.time_scale);
                skip_time = int32(ttl_manager.skip_time * self.time_scale);
                min_time = int32(ttl_manager.min_time * self.time_scale);
                off_val = ttl_manager.off_val ~= 0;
                ttl_mgr_serialized = [typecast(cid, 'int8'), ... % [chn_id: 4B]
                                      typecast(off_delay, 'int8'), ... % [off_delay: 4B]
                                      typecast(on_delay, 'int8'), ... % [on_delay: 4B]
                                      typecast(skip_time, 'int8'), ... % [skip_time: 4B]
                                      typecast(min_time, 'int8'), ... % [min_time: 4B]
                                      int8(off_val), ... % [off_val: 1B]
                                     ];
                if isKey(device_ttl_managers, devname)
                    tmp = device_ttl_managers(devname);
                    tmp{end + 1} = ttl_mgr_serialized;
                    device_ttl_managers(devname) = tmp;
                else
                    device_ttl_managers(devname) = {ttl_mgr_serialized};
                end
            end
            % [nbackenddatas: 4B]
            res = typecast(int32(length(device_ttl_managers)), 'int8');
            devs = keys(device_ttl_managers);
            for i = 1:length(devs)
                devname = devs{i};
                ttl_mgr = device_ttl_managers(devname);
                % [magic <"ZYNQZYNQ">: 8B]
                % [version <0>: 1B]
                % [nttl_mgrs: 1B][[chn_id: 4B][off_delay: 4B][on_delay: 4B]
                %                 [skip_time: 4B][min_time: 4B][off_val: 1B] x nttl_mgrs]
                dev_serialized = [int8('ZYNQZYNQ'), int8(0), ...
                                  int8(length(ttl_mgr)), ttl_mgr{:}];
                % [device_name: NUL-terminated string][size: 4B][data: size B]
                res = [res, int8(devname), int8(0), ...
                       typecast(int32(length(dev_serialized)), 'int8'), dev_serialized];
            end
        end
        function cid = getChannelId(self, name)
            if isKey(self.cid_cache, name)
                cid = self.cid_cache(name);
                return;
            end
            orig_name = name;
            name = translateChannel(self.config, name);
            if isKey(self.cid_cache, name)
                cid = self.cid_cache(name);
                return;
            end
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
            end
        end

        function reset_globals(self, first)
            for i = 1:length(self.globals)
                g = self.globals(i);
                if g.persist && ~first
                    continue;
                end
                set_global(self.pyseq, uint32(g.id), double(g.init_val));
            end
        end
    end
    methods(Static)
        function disabler = disable(val)
            ExpSeq.disabled.set(val);
            % Using an anonymous function here upsets MATLAB's parser...
            function cb()
                ExpSeq.disabled.set(false);
            end
            disabler = FacyOnCleanup(@cb);
        end
    end
end
