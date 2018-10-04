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
    %% This is the base class for pulses. The main purpose of this is to distinguish
    % between pulse classes that has important fields (e.g. `IRPulse`) or methods
    % and arbitrary callbacks.
    % The only API required by pulses is `calcValue` which returns the value
    % of the pulse at a given time within the step (`TimeStep`).

    methods(Abstract=true)
        % Old value is the value of the channel at tstart returned by timeSpan.
        val = calcValue(self, t, len, old_val);
    end
end
