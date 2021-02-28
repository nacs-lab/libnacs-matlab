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

classdef FPGAPoster2 < handle
    properties
        poster;
    end

    methods(Access = private)
        function self = FPGAPoster2(url)
            [path, ~, ~] = fileparts(mfilename('fullpath'));
            pyglob = py.dict(pyargs('mat_srcpath', path, 'url', url));
            try
                py.exec('from FPGAPoster2 import FPGAPoster2', pyglob);
            catch
                py.exec('import sys; sys.path.append(mat_srcpath)', pyglob);
                py.exec('from FPGAPoster2 import FPGAPoster2', pyglob);
            end
            self.poster = py.eval('FPGAPoster2(url)', pyglob);
        end
    end

    methods
        function [id, ttl_ovr, dds_ovr] = post(self, data)
            cleanup = register_cleanup(self);
            self.poster.post(data);
            while 1
                r = self.poster.post_reply();
                if r ~= py.None
                    cleanup.disable();
                    id = r{1};
                    ttl_ovr = r{2};
                    dds_ovr = uint8(r{3});
                    dds_ovr = dds_ovr(1:5:end);
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

    properties(Constant, Access=private)
        cache = containers.Map();
    end
    methods(Static)
        function dropAll()
            remove(FPGAPoster2.cache, keys(FPGAPoster2.cache));
        end
        function res = get(url)
            cache = FPGAPoster2.cache;
            if isKey(cache, url)
                res = cache(url);
                if ~isempty(res) && isvalid(res)
                    return;
                end
            end
            res = FPGAPoster2(url);
            cache(url) = res;
        end
    end
end
