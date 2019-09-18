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

% Acceptable id:
% Full path of the file.
% Path relative to $PathPrefix, optionally with ".mat" suffix removed.
% [date, time]: Both date and time can be string or number.
% "$(date)_$(time)": with optional "data_" prefix and ".mat" suffix.

function [fname, stamp] = FindDataFile(id)
    PathPrefix = Consts().PathPrefix;
    if ischar(id) || (isstring(id) && numel(id) == 1)
        id = char(id);
        if ~endsWith(id, '.mat')
            id = [id '.mat'];
        end
        [path, name, ext] = fileparts(id);
        if startsWith(name, 'data_')
            stamp = name(6:end);
        else
            stamp = name;
        end
        if exist(id, 'file')
            fname = id;
            return;
        end
        if isempty(name)
            error('Empty file name.');
        end
        if isempty(path)
            parts = split(stamp, '_');
            if length(parts) < 2
                error('Cannot parse file name: %s', name);
            end
            name = ['data_' stamp];
            path = fullfile(PathPrefix, 'Data', char(parts(1)));
        else
            path = fullfile(PathPrefix, path);
        end
        fname = fullfile(path, [name, ext]);
    else
        if id == 0
            try
                m = MemoryMap;
                id = [m.Data(1).DateStamp, m.Data(1).TimeStamp];
            catch
                fprintf('mem map not available!')
                return
            end
        elseif numel(id) ~= 2
            error('2-element array required');
        end
        date = to_char('%08d', id(1));
        time = to_char('%06d', id(2));
        stamp = [date, '_', time];
        fname = fullfile(PathPrefix, 'Data', date, ['data_', stamp, '.mat']);
    end
    if ~exist(fname, 'file')
        error('Cannot find file: %s', id);
    end
end

function s = to_char(fmt, i)
    if iscell(i)
        if numel(i) ~= 1
            error('Invalid input');
        end
        i = i{1};
    end
    if ischar(i)
        s = i;
    elseif isstring(i)
        s = char(i);
    else
        s = sprintf(fmt, i);
    end
end
