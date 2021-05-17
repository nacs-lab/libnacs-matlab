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

        %% Output related:
        % Whether the default has been overwritten and the new default value.
        % Indexed by the channel ID.
        default_override = false(0);
        default_override_val = [];

        ttl_managers = struct('chn', {}, 'off_delay', {}, 'on_delay', {}, ...
                              'skip_time', {}, 'min_time', {}, 'off_val', {});

        seq_ctx;
        basic_seqs = {};
        time_scale = 1e12; % TODO load from config
        globals = struct('id', {}, 'persist', {}, 'init_val', {});
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

        function bseq = newBasicSeq(self)
            bseq = BasicSeq(self);
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

    methods(Access=private)
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
