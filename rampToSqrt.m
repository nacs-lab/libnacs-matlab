%% Copyright (c) 2025, Sam & Youngshin
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

function func = rampToSqrt(v1)
    % Sqrt ramp from old value to final value vend
    func = @(t, len, v0) sqrt((v1^2 - v0^2) / len .* t + v0^2);
end
