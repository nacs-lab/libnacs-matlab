%% wrapper for ExptServer.py

classdef ExptServer < handle
    properties
        server;
    end

    methods(Access = private)
        function self = ExptServer(url)
            [path, ~, ~] = fileparts(mfilename('fullpath'));
            pyglob = py.dict(pyargs('mat_srcpath', path, 'url', url));
            try
                py.exec('from ExptServer import ExptServer', pyglob);
            catch
                py.exec('import sys; sys.path.append(mat_srcpath)', pyglob);
                py.exec('from ExptServer import ExptServer', pyglob);
            end
            self.server = py.eval('ExptServer(url)', pyglob);
        end
    end

    methods
        function res = check_request(self)
            % 0 - NoRequest
            % 1 - Pause
            % 2 - Abort
            res = double(self.server.check_request());
        end
        function res = start_seq(self)
            res = int64(self.server.start_seq());
        end
        function store_imgs(self, imgs, scan_id, seq_id)
            shape = size(imgs);
            if length(shape) == 2
                to_send = [double(shape(1)) double(shape(2)) double(1) imgs(:)'];
            elseif length(shape) == 3
                to_send = [double(shape(1)) double(shape(2)) double(shape(3)) imgs(:)'];
            end
            res = self.server.store_imgs(to_send, scan_id, seq_id);
        end
        function seq_finish(self)
            self.server.seq_finish();
        end
        function set_config(self, dateStamp, timeStamp)
            self.server.set_config(dateStamp, timeStamp)
        end
        function reset(self)
            self.server.reset();
        end
        function recreate_sock(self)
            self.server.recreate_sock();
        end
        function cleanup = register_cleanup(self)
            cleanup = FacyOnCleanup(@recreate_sock, self);
        end
    end

    properties(Constant, Access=private)
        cache = containers.Map();
    end
    methods(Static)
        function dropAll()
            remove(ExptServer.cache, keys(ExptServer.cache));
        end
        function res = get(url)
            cache = ExptServer.cache;
            if isKey(cache, url)
                res = cache(url);
                if ~isempty(res) && isvalid(res)
                    return;
                end
            end
            res = ExptServer(url);
            cache(url) = res;
        end
    end
end