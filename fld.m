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

function r = fld(x, y)
    %% This is the best way I can find to do this.
    % The first line is the julia implementation but it doesn't seem to
    % work....
    % Test case:
    %   x = -0.097076000000000023
    %   y = 0.0000020000000000000003
    % Expected answer:
    %   -48539
    r0 = round((x - rem(x, y)) / y);
    for r1 = (r0 - 1):(r0 + 1)
        if r1 * y > x
            r = r1 - 1;
            return;
        end
    end
    r = r0 + 1;
end
