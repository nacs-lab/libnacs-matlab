%% wrapper for AnalysisServer.py

classdef AnalysisServer < handle
    properties
        server;
    end

    methods(Access = private)
        function self = AnalysisServer(url)
            [path, ~, ~] = fileparts(mfilename('fullpath'));
            pyglob = py.dict(pyargs('mat_srcpath', path, 'url', url));
            try
                py.exec('from AnalysisServer import AnalysisServer', pyglob);
            catch
                py.exec('import sys; sys.path.append(mat_srcpath)', pyglob);
                py.exec('from AnalysisServer import AnalysisServer', pyglob);
            end
            self.server = py.eval('AnalysisServer(url)', pyglob);
        end
    end

    methods
        function result = recv_info(self)
            cleanup = register_cleanup(self);
            while 1
                res = self.server.recv_info();
                if res ~= py.None
                    cleanup.disable();
                    result = char(res);
                    return
                end
            end
        end

%         function wait(self, id)
%             cleanup = register_cleanup(self);
%             self.poster.wait_send(id);
%             while ~self.poster.wait_reply()
%             end
%             cleanup.disable();
%         end

        function imgs = recv_imgs(self)
            cleanup = register_cleanup(self);
            while 1
                data = self.server.recv_imgs();
                if data ~= py.None
                    cleanup.disable();
                    shape = double(data{1});
                    img1D = double(data{2});
                    imgs = reshape(img1D, shape(1), shape(2), shape(3));
                    return
                end
            end
        end
        function [n_per_group, n_images_per_seq] = recv_config(self)
            cleanup = register_cleanup(self);
            while 1
                data = self.server.recv_config(); % python list becomes cell array
                if data ~= py.None
                    cleanup.disable();
                    n_per_group = int64(data{1});
                    n_images_per_seq = int64(data{2});
                    return
                end
            end
        end
        function res = recv_end_seq(self)
            cleanup = register_cleanup(self);
            while 1
                data = self.server.recv_end_seq(); % python list becomes cell array
                if data ~= py.None
                    cleanup.disable();
                    res = int64(data);
                    return
                end
            end
        end
        function res = send_go(self)
            res = self.server.send_go();
        end
        function res = send_stop(self)
            res = self.server.send_stop();
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
            remove(AnalysisServer.cache, keys(AnalysisServer.cache));
        end
        function res = get(url)
            cache = AnalysisServer.cache;
            if isKey(cache, url)
                res = cache(url);
                if ~isempty(res) && isvalid(res)
                    return;
                end
            end
            res = AnalysisServer(url);
            cache(url) = res;
        end
    end
end
