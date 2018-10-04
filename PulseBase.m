%% Copyright (c) 2014-2018, Yichao Yu <yyc1992@gmail.com>
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

classdef(Abstract) PulseBase < handle
    % PulseBase is the parent class of FuncPulse etc.
    % PulseBase does not have any used properties.  The PulseBase objects
    % are store in the TimeStep.pulses{cid}, where cid is the channel id for
    % the pulse.

    methods(Abstract=true)
        % Old value is the value of the channel at tstart returned by timeSpan.
        val = calcValue(self, t, len, old_val);
    end
end
