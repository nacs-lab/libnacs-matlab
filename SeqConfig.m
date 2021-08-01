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

classdef SeqConfig < handle
    % The SeqConfig object contains hardware info, channel names.

    % All Methods
    % self = SeqConfig()
    % res = translateChannel(self, name)

    properties(Access=private)
        name_map;
    end
    properties
        channelAlias;
        defaultVals;
        consts;
        disabledChannels;

        niClocks;
        niStart;
        warnUnusedScan;

        % Global context. See `ExpSeqBase::G`.
        % Put it in the config in order to (ab)use the runSeq caching logic to share this
        % between all the sequences.
        G;
    end

    methods
        %%
        function self = SeqConfig(is_seq)
            if ~exist('is_seq', 'var')
                is_seq = 0;
            end
            self.name_map = containers.Map();
            % Create empty maps
            channelAlias = containers.Map();
            defaultVals = containers.Map();
            % Channel prefix to be disabled
            m_disabledChannels = containers.Map('KeyType', 'char', ...
                                                'ValueType', 'double');
            niClocks = containers.Map();
            niStart = containers.Map();
            consts = struct();
            warnUnusedScan = true;
            disableChannel = SeqConfig.getDisableChannelSetter(m_disabledChannels);
            configFile = [];

            % Run script which loads the empty maps.
            expConfig();

            if ~isempty(configFile)
                configFile = fullfile(fileparts(which('expConfig')), configFile);
                SeqManager.load_config_file(configFile);
            end
            self.niClocks = niClocks;
            self.niStart = niStart;
            self.consts = consts;
            self.warnUnusedScan = warnUnusedScan;

            for key = keys(channelAlias)
                key = key{:};

                if ~isempty(strfind(key, '/'))
                    error('Channel name should not have "/"');
                end

                matches = regexp(channelAlias(key), '^(.*[^/])/*$', 'tokens');
                if ~isempty(matches)
                    channelAlias(key) = matches{1}{1};
                end
            end
            self.channelAlias = channelAlias;

            self.defaultVals = containers.Map();
            for key = keys(defaultVals)
                key = key{:};
                name = translateChannel(self, key);
                if isKey(self.defaultVals, name)
                    error('Conflict default values for channel "%s" (%s).', key, name);
                end
                self.defaultVals(name) = defaultVals(key);
            end

            self.disabledChannels = containers.Map('KeyType', 'char', ...
                                                   'ValueType', 'double');
            for key = keys(m_disabledChannels)
                key = key{:};
                name = translateChannel(self, key);
                self.disabledChannels(name) = 0;
            end
            if is_seq && ~isempty(self.disabledChannels)
                warning('%d channel disabled globally.', ...
                        length(self.disabledChannels));
            end

            self.G = DynProps();
        end

        %% name is assumed to be translated. Returns false for untranslated name.
        function res = checkChannelDisabled(self, name)
            % This is `O(N)` in channel numbers. `O(log(N))` should be possible with a
            % sorted data structure but I'm not sure how that could be done in matlab.
            % We hopefully don't have enough channels for this to be an issue.....
            for key = keys(self.disabledChannels)
                % The map only contains translated name which are not translatable anymore,
                % i.e. calling translateChannel on them will return the input value.
                % Therefore, any untranslated names (i.e. names where translateChannel
                % is not a no-op) will not match any prefix and
                % the return value is guaranteed to be false.
                key = key{:};
                if strcmp(name, key)
                    res = true;
                    return;
                elseif startsWith(name, [key, '/'])
                    res = true;
                    return;
                end
            end
            res = false;
        end

        %%
        function res = translateChannel(self, name)
            if isKey(self.name_map, name)
                res = self.name_map(name);
                if isempty(res)
                    error('Alias loop detected: %s.', name);
                end
            else
                cpath = strsplit(name, '/');
                self.name_map(name) = [];
                if isKey(self.channelAlias, cpath{1})
                    cpath{1} = self.channelAlias(cpath{1});
                    res = translateChannel(self, strjoin(cpath, '/'));
                else
                    res = name;
                end
                self.name_map(name) = res;
            end
        end
    end
    methods(Static, Access=private)
        function func = getDisableChannelSetter(m_disabledChannels)
            function disableChannel(chn)
                m_disabledChannels(chn) = 0;
            end
            func = @disableChannel;
        end
    end

    properties(Constant, Access=private)
        cached_config = MutableRef();
    end
    methods(Static)
        function config = get(is_seq)
            if ~exist('is_seq', 'var')
                is_seq = 0;
            end
            config = SeqConfig.cached_config.get();
            if isempty(config)
                config = SeqConfig(is_seq);
            end
        end
        function reset()
            SeqConfig.cached_config.set([]);
        end
        function cache(is_seq)
            if ~exist('is_seq', 'var')
                is_seq = 0;
            end
            SeqConfig.cached_config.set(SeqConfig(is_seq));
        end
    end
end
