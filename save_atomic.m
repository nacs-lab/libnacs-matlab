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

% Save a MAT file atomically
% Print a warning instead of aborting if the saving failed.
function save_atomic(filename, s)
    if ~endsWith(filename, '.mat')
        filename = [filename, '.mat'];
    end
    tmpf = [tempname(), '.mat'];
    save(tmpf, '-struct', 's', '-v7.3');
    for i = 1:3
        try
            movefile(tmpf, filename);
            return;
        catch
            warning('Save %s failed.', filename);
            pause(0.4);
        end
    end
    % If the saving failed, try saving a backup in case it's caused by the file being used.
    filename = [filename, '.bak'];
    for i = 1:3
        try
            movefile(tmpf, filename);
            return;
        catch
            warning('Save %s failed.', filename);
            pause(0.1);
        end
    end
    delete(tmpf);
end
