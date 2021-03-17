%% wrapper for ExptClient.py

classdef ExptClient < handle
    properties
        client;
    end

    methods(Access = private)
        function self = ExptClient(url)
            [path, ~, ~] = fileparts(mfilename('fullpath'));
            pyglob = py.dict(pyargs('mat_srcpath', path, 'url', url));
            try
                py.exec('from ExptClient import ExptClient', pyglob);
            catch
                py.exec('import sys; sys.path.append(mat_srcpath)', pyglob);
                py.exec('from ExptClient import ExptClient', pyglob);
            end
            self.client = py.eval('ExptClient(url)', pyglob);
        end
    end

    methods
        function res = send_imgs(self, img)
            shape = size(img);
            res = self.client.send_imgs(img(:)', shape);
        end
        function res = send_config(self, n_per_group, n_images_per_seq)
            res = self.client.send_config(int64(n_per_group), int64(n_images_per_seq));
        end
        function res = send_end_seq(self, data)
            res = self.client.send_end_seq(int64(data));
        end
        function result = recv_reply(self)
            cleanup = register_cleanup(self);
            while 1
                res = self.client.recv_reply();
                if res ~= py.None
                    cleanup.disable()
                    result = int64(res);
                    return
                end
            end
        end
        function wait_reply(self)
            cleanup = register_cleanup(self);
            while ~self.client.wait_reply()
            end
            cleanup.disable();
        end

%         function wait(self, id)
%             cleanup = register_cleanup(self);
%             self.poster.wait_send(id);
%             while ~self.poster.wait_reply()
%             end
%             cleanup.disable();
%         end
        function recreate_sock(self)
            self.client.recreate_sock();
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
            remove(ExptClient.cache, keys(ExptClient.cache));
        end
        function res = get(url)
            cache = ExptClient.cache;
            if isKey(cache, url)
                res = cache(url);
                if ~isempty(res) && isvalid(res)
                    return;
                end
            end
            res = ExptClient(url);
            cache(url) = res;
        end
    end
end
