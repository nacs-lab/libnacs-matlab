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

classdef IRContext < handle
    %% This is a simple class to give each IRNode an ID.
    % I cannot find a way to build a object ID dict in matlab so the ID
    % is used to identify nodes.
    properties(Access=private)
        counter = int64(0);
    end
    methods
        function res = next_id(self)
            res = self.counter;
            self.counter = res + 1;
        end
    end
end
