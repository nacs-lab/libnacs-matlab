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

classdef FuncPulse < PulseBase
    properties
        func;
        narg;
    end

    methods
        function self = FuncPulse(func)
            self.func = func;
            self.narg = nargin(func);
        end

        function val = calcValue(self, t, len, old_val)
            if self.narg == 1
                val = self.func(t);
            elseif self.narg == 2
                val = self.func(t, len);
            else
                val = self.func(t, len, old_val);
            end
        end
    end
end
