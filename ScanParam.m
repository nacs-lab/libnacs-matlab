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
end
