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

classdef SubProps < handle
    % This is a delayed set/get operation on a parent class with a path prefix.
    properties(Hidden)
        parent;
        path;
    end
    methods
        function self = SubProps(parent, path)
            self.parent = parent;
            self.path = path;
        end
        function parent = get_parent(self)
            parent = self.parent;
        end
        function B = subsref(self, S)
            B = subsref(self.parent, [self.path, S]);
        end
        function A = subsasgn(self, S, B)
            A = self;
            subsasgn(self.parent, [self.path, S], B);
        end
        function res = fieldnames(self)
            res = subfieldnames(self.parent, self.path);
        end
        function disp(self)
            if ismethod(self.parent, 'subdisp')
                subdisp(self.parent, self.path);
                return;
            end
            builtin('disp', self);
        end
        function display(self, name)
            if ismethod(self.parent, 'subdisplay')
                subdisplay(self.parent, self.path, name);
                return;
            end
            fprintf('%s =\n\n', name);
            disp(self);
        end
    end
end
