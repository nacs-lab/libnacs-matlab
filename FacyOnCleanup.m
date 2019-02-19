%% Copyright (c) 2018-2018, Yichao Yu <yyc1992@gmail.com>
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

classdef FacyOnCleanup < handle
    % The class name is presented to you by Logitech
    properties
        cb;
        args;
        enable = 1;
    end
    methods
        function self = FacyOnCleanup(cb, varargin)
            self.cb = cb;
            self.args = varargin;
        end
        function self = setarg(self, i, v)
            self.args{i} = v;
        end
        function disable(self)
            self.enable = 0;
        end
        function delete(self)
            if self.enable
                self.cb(self.args{:});
            end
        end
    end
end
