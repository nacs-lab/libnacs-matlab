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

classdef (Sealed) TimeStep < TimeSeq
    %% `TimeStep`s are leaf nodes in the experiment sequence (tree/DAG).
    % Since this cannot contain any subsequences or child steps, the only
    % time step specific API provided is adding output to the step.
    % See `TimeSeq` for the general structure of the sequence.

    properties
        % Pulses indexed by the channel ID.
        % Each pulse span the whole time of the time step.
        % Pre-allocated to minimize resizing.
        pulses = {[], [], [], [], [], [], [], []};
        % The length of the step
        len;
    end

    methods
        function self = TimeStep(parent, start_time, len)
            % These fields are in `TimeSeq`.
            % However, they are not initialized in `TimeSeq` constructor
            % to isolate the handling of `ExpSeq` to `ExpSeqBase`
            % and to reduce function call overhead...
            self.parent = parent;
            self.tOffset = start_time;
            self.config = parent.config;
            self.topLevel = parent.topLevel;
            self.len = len;
            ns = parent.nSubSeqs + 1;
            parent.nSubSeqs = ns;
            if ns > length(parent.subSeqs)
                parent.subSeqs{round(ns * 1.3) + 8} = [];
            end
            parent.subSeqs{ns} = self;
        end

        function self = add(self, name, pulse)
            %% Add a pulse on a channel to the step.
            % The channel name can be provided as a string, which will be
            % translated and converted to the channel ID, or it can be
            % given as the channel ID (number) directly. (See `TimeSeq::translateChannel`)
            % The pulse can be
            %
            % * A number
            %
            %     Output the value at the beginning of the step.
            %
            % * A subclass of `PulseBase`
            %
            %     The `calcValue` method will be used to compute the output value.
            %
            % * Or an arbitrary callable object/function handle.
            %
            %     Equivalent as a `FuncPulse`. The object will be called to
            %     compute the output value.
            if isnumeric(name)
                cid = name;
            else
                cid = translateChannel(self.topLevel, name);
            end
            if isnumeric(pulse) || islogical(pulse)
                if ~isscalar(pulse)
                    error('Pulse cannot be a non-scalar value.');
                end
                pulse = double(pulse);
            elseif ~isa(pulse, 'PulseBase')
                % Treat as function/callable
                pulse = FuncPulse(pulse);
            end
            if cid > length(self.pulses)
                % Minimize resizing
                self.pulses{cid + 5} = [];
            end
            self.pulses{cid} = pulse;
        end

        function res = totalTime(self)
            res = self.len;
        end
    end
end
