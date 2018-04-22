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

classdef (Sealed) TimeStep < TimeSeq
    % The 'pulses' property contains values for the channel and channel ids.
    % The 'pulses' property contains a TimeStep.pulses{cid} = pulse_list, which is
    % a cell-array of PulseBase ojbects, where cid is the channel id.
    % A TimeStep object is only created in the addTimeStep and addCustomStep
    % methods of the ExpSeqBase class.

    % All Methods:
    % self = TimeStep(varargin)
    % res = add(self, varargin)
    % ret = addPulse(self, name, pulse)

    properties
        pulses; % contains numbers or PulseBase objects, which are children of the PulseBase class.
        len;
    end

    methods
        %%
        function self = TimeStep(parent, start_time, len)
            % Made only in the ExpSeqBase::addTimeStep.

            self = self@TimeSeq(parent, start_time);
            self.len = len;
            self.pulses = {};
            parent.subSeqs{end + 1} = self;
        end

        function ret = add(self, name, pulse)
            ret = self;
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
                % Treat as function
                pulse = FuncPulse(pulse);
            end
            self.pulses{cid} = pulse;
        end

        function res = length(self)
            res = self.len;
        end
    end
end
