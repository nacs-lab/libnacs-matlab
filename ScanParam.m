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
%                        `param.a.b.c.d.scan([nd]) = array`):
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

classdef ScanParam < handle
    properties(Access=?ScanGroup)
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
        function varargout = subsref(self, S)
            nS = length(S);
            for i = 1:nS
                typ = S(i).type;
                if strcmp(typ, '.')
                    continue;
                end
                if i > 1 && strcmp(S(i).type, '()') && isempty(S(i).subs)
                    if i < nS
                        error('Invalid parameter access syntax.');
                    end
                    nargoutchk(0, 2);
                    [val, dim] = try_getfield(self.group, self.idx, S(1:i - 1), 1);
                    if dim < 0
                        error('Parameter does not exist yet.');
                    end
                    varargout{1} = val;
                    varargout{2} = dim;
                    return;
                end
                if i > 1 && strcmp(S(i - 1).subs, 'scan') && strcmp(S(i).type, '()')
                    if i == 2
                        error('Must specify parameter to scan.');
                    elseif i < nS
                        error('Invalid scan() syntax after scan.');
                    end
                    nargoutchk(0, 0);
                    subs = S(i).subs;
                    switch length(subs)
                        case 0
                            error('Too few arguments for scan()');
                        case 1
                            addscan(self.group, self.idx, S(1:i - 2), 1, subs{1});
                        case 2
                            addscan(self.group, self.idx, S(1:i - 2), subs{1}, subs{2});
                        otherwise
                            error('Too many arguments for scan()');
                    end
                    return;
                end
                error('Invalid parameter access syntax.');
            end
            nargoutchk(0, 1);
            varargout{1} = SubProps(self, S);
        end
        function self = subsasgn(self, S, B)
            nS = length(S);
            for i = 1:nS
                typ = S(i).type;
                if strcmp(typ, '.')
                    continue;
                end
                if (strcmp(typ, '()') && i > 1 && strcmp(S(i - 1).subs, 'scan'))
                    if i == 2
                        error('Must specify parameter to scan.');
                    elseif i ~= nS
                        error('Invalid scan() syntax after scan.');
                    end
                    subs = S(i).subs;
                    switch length(subs)
                        case 0
                            addscan(self.group, self.idx, S(1:i - 2), 1, B);
                        case 1
                            addscan(self.group, self.idx, S(1:i - 2), subs{1}, B);
                        otherwise
                            error('Too many arguments for scan()');
                    end
                    return;
                end
                error('Invalid parameter access syntax.');
            end
            addparam(self.group, self.idx, S, B);
        end
    end
end
