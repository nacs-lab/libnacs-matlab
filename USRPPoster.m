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

classdef USRPPoster < handle
    properties
        poster;
    end

    methods(Access = private)
        function self = USRPPoster(url)
            [path, ~, ~] = fileparts(mfilename('fullpath'));
            pyglob = py.dict(pyargs('mat_srcpath', path, 'usrp_url', url));
            try
                py.exec('from USRPPoster import USRPPoster', pyglob);
            catch
                py.exec('import sys; sys.path.append(mat_srcpath)', pyglob);
                py.exec('from USRPPoster import USRPPoster', pyglob);
            end
            self.poster = py.eval('USRPPoster(usrp_url)', pyglob);
        end
    end

    methods
        function res = post(self, data)
            cleanup = register_cleanup(self);
            self.poster.post(data);
            while 1
                res = self.poster.post_reply();
                if res ~= 0
                    cleanup.disable();
                    return
                end
            end
        end

        function wait(self, id)
            cleanup = register_cleanup(self);
            self.poster.wait_send(id);
            while ~self.poster.wait_reply()
            end
            cleanup.disable();
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
            global nacsUSRPPosterCache
            nacsUSRPPosterCache = [];
        end
        function res = get(url)
            global nacsUSRPPosterCache
            if isempty(nacsUSRPPosterCache)
                nacsUSRPPosterCache = containers.Map();
            end
            cache = nacsUSRPPosterCache;
            if isKey(cache, url)
                res = cache(url);
                return;
            end
            res = USRPPoster(url);
            cache(url) = res;
        end
    end
end
