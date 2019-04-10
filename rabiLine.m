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

function res = rabiLine(det, t, Omega)
    % det in angular freq units
    % t is 1/freq units
    % omega is angular freq units
    Omega2 = Omega.^2;
    OmegaG2 = det.^2 + Omega2;
    res = Omega2 ./ OmegaG2 .* sin(sqrt(OmegaG2) .* t ./ 2).^2;
end
