%% wrapper for AnalysisUser.py

classdef AnalysisUser < handle
    properties
        AU;
    end

    methods(Access = private)
        function self = AnalysisUser(url)
            [path, ~, ~] = fileparts(mfilename('fullpath'));
            pyglob = py.dict(pyargs('mat_srcpath', path, 'url', url));
            try
                py.exec('from AnalysisUser import AnalysisUser', pyglob);
            catch
                py.exec('import sys; sys.path.append(mat_srcpath)', pyglob);
                py.exec('from AnalysisUser import AnalysisUser', pyglob);
            end
            self.AU = py.eval('AnalysisUser(url)', pyglob);
        end
    end

    methods
        function res = check_msg(self)
            res = self.AU.check_msg();
            if res ~= py.None
                res = char(res{1});
            else
                res = '';
            end
        end
        function pause_seq(self)
            self.AU.pause_seq();
        end
        function abort_seq(self)
            self.AU.abort_seq();
        end
        function start_seq(self)
            self.AU.start_seq();
        end
        function set_refresh_rate(self, val)
            self.AU.set_refresh_rate(val);
        end
        function info = grab_imgs(self)
            res = cell(self.AU.grab_imgs());
            info.imgs = {};
            info.scan_ids = [];
            info.seq_ids = [];
            for i = 1:length(res)
                this_info = AnalysisClient.process_imgs(double(res{i}));
                if isempty(this_info.imgs)
                    continue;
                end
                info.imgs = horzcat(info.imgs, this_info.imgs);
                info.scan_ids = horzcat(info.scan_ids, this_info.scan_ids);
                info.seq_ids = horzcat(info.seq_ids, this_info.seq_ids);
            end
        end
        function res = get_seq_num(self)
        end
        function res = get_config(self)
        end
        function res = get_status(self)
            res = double(self.AU.get_status());
        end
        function reset_client(self)
            self.AU.reset_client();
        end
        function cleanup = register_cleanup(self)
            cleanup = FacyOnCleanup(@reset_client, self);
        end
    end

    properties(Constant, Access=private)
        cache = containers.Map();
    end
    methods(Static)
        function dropAll()
            remove(AnalysisUser.cache, keys(AnalysisUser.cache));
        end
        function res = get(url)
            cache = AnalysisUser.cache;
            if isKey(cache, url)
                res = cache(url);
                if ~isempty(res) && isvalid(res)
                    return;
                end
            end
            res = AnalysisUser(url);
            cache(url) = res;
        end
    end
end