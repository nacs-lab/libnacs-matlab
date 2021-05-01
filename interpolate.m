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

function y = interpolate(x, x0, x1, vals)
    dx = x1 - x0;
    x = x - x0;
    y = zeros(size(x));
    nv = length(vals);
    xscaled = x * (nv - 1) / dx;
    for i = 1:length(x)
        xe = xscaled(i);
        if xe <= 0
            y(i) = vals(1);
        elseif xe >= (nv - 1)
            y(i) = vals(end);
        else
            lo = floor(xe);
            xrem = xe - lo;
            vlo = vals(lo + 1);
            if xrem == 0
                y(i) = vlo;
            else
                y(i) = vlo * (1 - xrem) + vals(lo + 2) * xrem;
            end
        end
    end
end
