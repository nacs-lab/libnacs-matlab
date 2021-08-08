%% Copyright (c) 2021-2021, Yichao Yu <yyc1992@gmail.com>
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

function dump_to_file(fname, array)
    f = fopen(fname, 'w');
    % typecast and fwrite want vector as input.
    array = reshape(array, [1, numel(array)]);
    % Note that matlab's `fwrite` will convert the array to `uint8` in a lossy way
    % before writing. That's why we have to do the conversion ourselve.
    if ischar(array)
        array = uint8(array);
    else
        array = typecast(array, 'uint8');
    end
    fwrite(f, array);
    fclose(f);
end
