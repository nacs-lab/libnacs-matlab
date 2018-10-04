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

classdef(Abstract) PulseBackend < handle
    %% Base class of all backends that translate the high level sequence
    % to the low level format necessary for execution.
    % Pulse backend should **not** be singleton objects.
    % Instead, each sequence will create their own instance of the pulse
    % backend for each backends that they use.
    % The backend object should hold sequence specific information that's
    % needed for the target of the backend. (e.g. channels, generated data etc).

    properties(Access=protected)
        seq;
    end

    methods(Abstract=true)
        initDev(self, did); % Check and add device
        initChannel(self, cid); % Check and add channel
        generate(self, cids); % Generate sequence.
        run(self); % Start sequence.
    end

    methods
        function self = PulseBackend(seq)
            self.seq = seq;
        end

        function val = getPriority(self)
            %% Return the priority which is used to sort the drivers.
            % See `ExpSeq::generate`.
            % There's probably a better way to let the backend specify the necessary
            % dependencies for running each functions. A simple priority is good
            % enough for now.
            val = 0;
        end

        function prepare(self, cids)
            %% For preparation that needs to be done before the generation.
            % (e.g. doing inter-backend calls to prepare related other backends).
        end

        function wait(self)
            % Wait for the sequence to finish.
        end
    end
end
