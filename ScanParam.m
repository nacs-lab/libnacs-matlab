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

%% This represent a N-dimensional scan. See `ScanGroup`
% API:
% * (nested) field access (i.e. `param.a.b.c.d`):
%     If the result is a fixed parameter, the value of it will be returned.
%     When using this syntax, the full parameter (with base applied) will be used
%     and the scan has to be valid.
%     Otherwise, a lazy lookup object will be returned and operation on that object
%     will be equivalent to operating on this object with a field access prefix.
% * (nested) field assignment (i.e. `param.a.b.c.d = x`):
%     This always represent a single parameter. Never a scan.
%     Throws an error if the field is already set as a scan.
% * (nested) field scan (i.e. `param.a.b.c.d.scan([nd, ]array)` or
%                        `param.a.b.c.d.scan(nd) = array`):
%     `nd` is the dimension of the scan. Default to 1.
%     If `array` is a scalar or single element cell array,
%     this is equivalent to `param.a.b.c.d = x` (or `param.a.b.c.d = x{1}` for cell array).
%     Otherwise, the `array` represent the list of parameters to scan.
%     Throws an error if the field is already assigned as a parameter.
%     Also throw an error if the field is already set as scan on another dimension.
%
%     `array` of `char` is treated specially.
%     It is not treated as array if the non-1 dimension is the second one (horizontal)
%     meaning a string literal will be treated as scalar. To scan over characters/strings,
%     use use vertical array of string (e.g. `('123')'` or `['1'; '2'; '3']`) or cell array
%     instead.
% * toscan(param)
%     Convert the `ScanParam` to a scan.

classdef ScanParam < handle
    properties(Access=private)
        group;
        idx;
    end
    methods(Access=?ScanGroup)
        function self = ScanParam(group, idx)
            self.group = group;
            self.idx = idx;
        end
        function group = getgroup(self)
            group = self.group;
        end
        function idx = getidx(self)
            idx = self.idx;
        end
    end
    methods
        function sz = size(self, dim)
            sz = param_size(self.group, self.idx, self, dim);
        end
        function varargout = subsref(self, S)
            [varargout{1:nargout}] = param_subsref(self.group, self.idx, self, S);
        end
        function self = subsasgn(self, S, B)
            param_subsasgn(self.group, self.idx, self, S, B);
        end
        function res = horzcat(varargin)
            res = ScanGroup.cat_scans(varargin{:});
        end
        function res = toscan(self)
            res = ScanGroup.cat_scans(self);
        end
        function disp(self)
            param_disp(self.group, self.idx, self);
        end
        function display(self, name)
            fprintf('%s = ', name);
            disp(self);
        end
        function subdisp(self, S)
            param_subdisp(self.group, self.idx, self, S);
        end
        function subdisplay(self, S, name)
            fprintf('%s = ', name);
            subdisp(self, S);
        end
    end
end
