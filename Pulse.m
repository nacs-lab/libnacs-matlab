%% Copyright (c) 2021-2021, Yichao Yu <yyc1992@gmail.com>
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

classdef Pulse < handle
    properties
        id;
        val;
        cond;
    end
    methods
        function self = Pulse(id, val, cond)
            self.id = id;
            self.val = val;
            self.cond = cond;
        end

        function res = toString(self)
            if islogical(self.cond) && self.cond
                res = sprintf('Pulse(id=%d, val=%s)', self.id, SeqVal.toString(self.val));
            else
                res = sprintf('Pulse(id=%d, val=%s, cond=%s)', ...
                              self.id, SeqVal.toString(self.val), SeqVal.toString(self.cond));
            end
        end
    end
end
