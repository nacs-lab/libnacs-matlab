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

function F = GetFrame(n)
    if ~exist('n', 'var')
        n = 2;
    elseif n < 1
        error('Invalid frame index');
    else
        n = n + 1;
    end
    SI = dbstack();
    if n > length(SI)
        F = struct('file', '', 'name', '', 'line', 0);
    else
        F = SI(n);
    end
end
