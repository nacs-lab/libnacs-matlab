%% Copyright (c) 2019-2019, Yichao Yu <yyc1992@gmail.com>
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

function str = num_to_str(num)
    if isinteger(num) || islogical(num)
        str = sprintf('%d', num);
        return;
    end
    if ~isfinite(num)
        if isnan(num)
            str = 'nan';
        elseif num > 0
            str = 'inf';
        else
            str = '-inf';
        end
        return;
    elseif num == 0
        % Ignore signed zero for now...
        str = '0';
        return;
    end
    assert(isnumeric(num));

    % This is very inefficient but I don't really care...
    % Don't really want to implement any fancy algorithms in matlab...
    function [ok, str] = try_format(fmt, ndig)
        str = sprintf(sprintf('%%.%d%s', ndig, fmt), num);
        ok = sscanf(str, '%f') == num;
    end
    anum = abs(num);
    if anum >= 1e6 || anum < 1e-4
        for i = 0:20
            [ok, str] = try_format('e', i);
            if ok
                break;
            end
        end
        % This is stupid but whatever........
        if anum > 1
            str = strrep(str, 'e+', 'e');
            str = strrep(str, 'e0', 'e');
        else
            str = strrep(str, 'e-0', 'e-');
        end
    else
        for i = 0:20
            [ok, str] = try_format('f', i);
            if ok
                break;
            end
        end
    end
end
