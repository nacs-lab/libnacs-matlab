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
% * (nested) field assignment (i.e. `group.a.b.c.d = x`):
%     This always represent a single parameter. Never a scan.
%     Throws an error if the field is already set as a scan.
% * (nested) field scan (i.e. `group.a.b.c.d.scan([nd, ]array)`):
%     `nd` is the dimension of the scan. Default to 1.
%     If `array` is a scalar or single element cell array,
%     this is equivalent to `group.a.b.c.d = x` (or `group.a.b.c.d = x{1}` for cell array).
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
        function self=ScanParam(group, idx)
            self.group = group;
            self.idx = idx;
        end
        function check_noconflict(self, S, dim)
            grp = self.group;
            if self.idx == 0
                scan = grp.base;
            elseif length(grp.scans) < self.idx
                % Initialize the scans, no need to check for conflict yet since it's empty.
                grp.scans(length(grp.scans) + 1:self.idx) = grp.DEF_SCAN;
                return;
            else
                scan = grp.scans(self.idx);
            end
            if dim ~= 0
                if ScanGroup.check_field(scan.params, S)
                    error('Cannot scan a fixed parameter.');
                end
            end
            for i = 1:length(scan.vars)
                if dim == i
                    continue;
                end
                if ScanGroup.check_field(scan.vars(i).params, S)
                    if dim == 0
                        error('Cannot fix a scanned parameter.');
                    else
                        error('Cannot scan a parameter in multiple dimensions.');
                    end
                end
            end
        end
        function scan(self, S, dim, vals)
            if ~ScanGroup.isarray(vals)
                setparam(self, S, vals);
                return;
            end
            if ~(dim > 0 && isscalar(dim) && isinteger(dim))
                error('Scan dimension must be positive integer.');
            end
            check_noconflict(self, S, dim);
            grp = self.group;
            idx = self.idx;
            nvals = numel(vals);
            if idx == 0
                sz = grp.base.vars(dim).size;
                if sz == 0
                    grp.base.vars(dim).size = nvals;
                elseif sz ~= nvals
                    error('Scan parameter size does not match');
                end
                grp.base.vars(dim).params = subsasgn(grp.base.vars(dim).params, S, vals);
            else
                sz = grp.scans(idx).vars(dim).size;
                if sz == 0
                    grp.scans(idx).vars(dim).size = nvals;
                elseif sz ~= nvals
                    error('Scan parameter size does not match');
                end
                grp.scans(idx).vars(dim).params = subsasgn(grp.scans(idx).vars(dim).params, ...
                                                           S, vals);
            end
        end
        function setparam(self, S, val)
            check_noconflict(self, S, 0);
            grp = self.group;
            idx = self.idx;
            if idx == 0
                grp.base.params = subsasgn(grp.base.params, S, val);
            else
                grp.scans(idx).params = subsasgn(grp.scans(idx).params, S, val);
            end
        end
    end
    methods
        function varargout = subsref(self, S)
            nS = length(S);
            for i = 1:nS
                typ = S(i).type;
                if ~strcmp(typ, '.')
                    error('Invalid parameter access syntax.');
                end
                if strcmp(name, 'scan') && i < nS && strcmp(S(i + 1).type, '()')
                    if i == 1
                        error('Must specify parameter to scan.');
                    elseif i + 1 < nS
                        error('Invalid scan() syntax after scan.');
                    end
                    nargoutchk(0, 0);
                    subs = S(i + 1).subs;
                    switch length(subs)
                        case 0
                            error('Too few arguments for scan()');
                        case 1
                            scan(self, S(1:i - 1), 1, subs{1});
                        case 2
                            scan(self, S(1:i - 1), subs{1}, subs{2});
                        otherwise
                            error('Too many arguments for scan()');
                    end
                    return;
                end
            end
            nargoutchk(0, 1);
            varargout{1} = SubProps(self, S);
        end
        function self = subsasgn(self, S, B)
            nS = length(S);
            for i = 1:nS
                typ = S(i).type;
                if ~strcmp(typ, '.')
                    error('Invalid parameter access syntax.');
                end
            end
            setparam(self, S, B);
        end
    end
end
