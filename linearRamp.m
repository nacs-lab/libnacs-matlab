%% Copyright (c) 2014-2021, Yichao Yu <yyc1992@gmail.com>
%%
%% This library is free software; you can redistribute it and/or
%% modify it under the terms of the GNU Lesser General Public
%% License as published by the Free Software Foundation; either
%% version 3.0 of the License, or (at your option) any later version.
%% This library is distributed in the hope that it will be useful,
%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
%% Lesser General Public License for more details.
%% You should have received a copy of the GNU Lesser General Public
%% License along with this library.

function func = linearRamp(vstart, vend)
    if isnumeric(vstart) && isnumeric(vend) && vstart == vend
        func = vstart;
    else
        func = @(t, len, old_val) (vstart .* (len - t) + vend .* t) ./ len;
    end
end
