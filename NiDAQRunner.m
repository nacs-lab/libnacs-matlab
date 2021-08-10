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

classdef NiDAQRunner < handle
    properties(Constant, Access=private)
        % Use cache for the session since adding channels is really slow....
        % (50ms per channel)
        session = MutableRef();
        % Flag to see if the cache is being used
        % (i.e. it is in a state we cannot use to start a new run)
        cache_in_use = MutableRef(false);
        channels = MutableRef();
        clocks = containers.Map();
        triggers = containers.Map();
    end

    methods(Static, Access=private)
        function res = map_equal(a, b)
            res = isequaln(keys(a), keys(b)) && isequaln(values(a), values(b));
        end

        function cache_map(dest, src)
            remove(dest, keys(dest));
            ks = keys(src);
            vs = values(src);
            for i = 1:length(ks)
                dest(ks{i}) = vs{i};
            end
        end

        function session = get_session(channels, clocks, triggers)
            session_cache = NiDAQRunner.session;
            channels_cache = NiDAQRunner.channels;
            clocks_cache = NiDAQRunner.clocks;
            triggers_cache = NiDAQRunner.triggers;
            cache_in_use = NiDAQRunner.cache_in_use;
            session = session_cache.get();
            if cache_in_use.get() || isempty(session) || ~isvalid(session) || ...
               ~isequaln(channels, channels_cache.get()) || ...
               ~NiDAQRunner.map_equal(clocks_cache, clocks) || ...
               ~NiDAQRunner.map_equal(triggers_cache, triggers)
                % Need to (re)create session.
                delete(session);
                session = NiDAQRunner.create_session(channels, clocks, triggers);
                channels_cache.set(channels);
                session_cache.set(session);
                NiDAQRunner.cache_map(clocks_cache, clocks);
                NiDAQRunner.cache_map(triggers_cache, triggers);
            end
            cache_in_use.set(true);
        end

        function session = create_session(channels, clocks, triggers)
            session = daq.createSession('ni');
            % Setting to a high clock rate makes the NI card to wait for more
            % clock cycles after the sequence finished. However, setting to
            % a rate lower than the real one cause the card to not update
            % at the end of the sequence.
            session.Rate = 500e3; % XXX: Hard code

            inited_devs = containers.Map();

            for i = 1:length(channels)
                dev_name = channels(i).dev;
                output_id = channels(i).chn;
                [~] = addAnalogOutputChannel(session, dev_name, output_id, 'Voltage');
                if ~isKey(inited_devs, dev_name)
                    [~] = addTriggerConnection(session, 'External', ...
                                               [dev_name, '/', triggers(dev_name)], ...
                                               'StartTrigger');
                    [~] = addClockConnection(session, 'External', ...
                                             [dev_name, '/', clocks(dev_name)], ...
                                             'ScanClock');
                    inited_devs(dev_name) = true;
                end
            end
        end
    end

    methods(Static)
        function clear_session()
            session_cache = NiDAQRunner.session;
            session = session_cache.get();
            if ~isempty(session)
                delete(session);
                session_cache.set([]);
            end
        end

        function run(channels, clocks, triggers, data)
            session = NiDAQRunner.get_session(channels, clocks, triggers);
            queueOutputData(session, data);
            startBackground(session);
        end

        function wait()
            % This turns the pause(0.1) in the NI driver into a busy wait loop
            % and reduce ~50ms of wait time per run on average.
            old_state = pause('off');
            % The cleanup object tracks the lifetime of the current scope.
            cleanup = FacyOnCleanup(@(old_state) pause(old_state), old_state);
            wait(NiDAQRunner.session.get());
            NiDAQRunner.cache_in_use.set(false);
            delete(cleanup);
            % 1.5 has some strange issue (no output from time to time) that
            % seems to go away with any amount of pause time after the
            % sequence finishes. It could be related to us disabling the
            % pause above. In any case, 1ms of wait time here is a pretty
            % cheap way to workaround it.
            pause(1e-3);
        end
    end
end
