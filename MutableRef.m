%% Copyright (c) 2019-2019, Yichao Yu <yyc1992@gmail.com>
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

%% Matlab only supports constant static variables for classes
% This is a mutable container that can be used as a constant member
% to work around this limitation

classdef MutableRef < handle
    properties
        x;
    end
    methods
        function self = MutableRef(x)
            if exist('x', 'var')
                self.x = x;
            end
        end
        function self = set(self, x)
            self.x = x;
        end
        function x = get(self)
            x = self.x;
        end
    end
end
