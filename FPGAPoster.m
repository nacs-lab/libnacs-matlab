%% Copyright (c) 2017-2017, Yichao Yu <yyc1992@gmail.com>
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

classdef FPGAPoster < handle
    properties
        poster;
    end

    methods(Access = private)
        function self = FPGAPoster(url)
            [path, ~, ~] = fileparts(mfilename('fullpath'));
            pyglob = py.dict(pyargs('mat_srcpath', path, 'url', url));
            try
                py.exec('from FPGAPoster import FPGAPoster', pyglob);
            catch
                py.exec('import sys; sys.path.append(mat_srcpath)', pyglob);
                py.exec('from FPGAPoster import FPGAPoster', pyglob);
            end
            self.poster = py.eval('FPGAPoster(url)', pyglob);
        end
    end

    methods
        function post(self, data)
            cleanup = register_cleanup(self);
            self.poster.post(data);
            cleanup.disable();
        end

        function wait(self)
            cleanup = register_cleanup(self);
            while ~self.poster.post_reply()
            end
            cleanup.disable();
        end

        function msg = prepare_msg(self, tlen, code)
            msg = self.poster.prepare_msg(tlen, code);
        end
        function recreate_socket(self)
            self.poster.recreate_sock();
        end
        function cleanup = register_cleanup(self)
            cleanup = FacyOnCleanup(@recreate_socket, self);
        end
    end

    methods(Static)
        function dropAll()
            global nacsFPGAPosterCache
            nacsFPGAPosterCache = [];
        end
        function res = get(url)
            global nacsFPGAPosterCache
            if isempty(nacsFPGAPosterCache)
                nacsFPGAPosterCache = containers.Map();
            end
            cache = nacsFPGAPosterCache;
            if isKey(cache, url)
                res = cache(url);
                return;
            end
            res = FPGAPoster(url);
            cache(url) = res;
        end
    end
end
