%% wrapper for AnalysisClient.py

classdef AnalysisClient < handle
    properties
        client;
    end

    methods(Access = private)
        function self = AnalysisClient(url)
            [path, ~, ~] = fileparts(mfilename('fullpath'));
            pyglob = py.dict(pyargs('mat_srcpath', path, 'url', url));
            try
                py.exec('from AnalysisClient import AnalysisClient', pyglob);
            catch
                py.exec('import sys; sys.path.append(mat_srcpath)', pyglob);
                py.exec('from AnalysisClient import AnalysisClient', pyglob);
            end
            self.client = py.eval('AnalysisClient(url)', pyglob);
        end
    end
    methods(Static)
        function info = process_imgs(double_arr)
            % we traverse through the double array and separate out the
            % imgs per sequence and return a cell array, where each entry
            % is a different sequence. 
            res = double_arr;
            seq_idx = 1; % idx in imgs
            num_seqs = res(1);
            imgs = cell(1, num_seqs);
            scan_ids = zeros(1, num_seqs);
            seq_ids = zeros(1, num_seqs);
            if num_seqs == 0
                info.imgs = imgs;
                info.scan_ids = scan_ids;
                info.seq_ids = seq_ids;
                return
            end
            idx = 2; % idx in res
            first_img = true;
            stop = false;
            while ~stop
                if idx > length(res)
                    stop = true;
                    break;
                end 
                while res(idx) == 0
                    % end of sequence
                    if idx == length(res)
                        %reached end
                        stop = true;
                        break;
                    end
                    seq_idx = seq_idx + 1;
                    idx = idx + 1;
                    first_img = true;
                end
                if stop
                    break;
                end
                % get scan_id and seq_id
                if first_img
                    scan_id = res(idx);
                    idx = idx + 1;
                    scan_ids(seq_idx) = scan_id;
                    seq_id = res(idx);
                    idx = idx + 1;
                    seq_ids(seq_idx) = seq_id;
                    first_img = false;
                end
                % get_size
                s1 = res(idx);
                s2 = res(idx + 1);
                s3 = res(idx + 2);
                idx = idx + 3;
                % POSSIBLE TODO: preallocate
                if isempty(imgs{seq_idx})
                    imgs{seq_idx} = reshape(res(idx:(idx + s1 * s2 * s3 - 1)), [s1, s2, s3]);
                else
                    % assumes all images in one sequence are same size for
                    % now...
                    this_img_array = imgs{seq_idx};
                    this_img_array(:,:,(end + 1):(end + s3)) = reshape(res(idx:(idx + s1 * s2 * s3 - 1)), [s1, s2, s3]);
                    imgs{seq_idx} = this_img_array;
                end
                idx = idx + s1 * s2 * s3; 
            end
            info.imgs = imgs;
            info.scan_ids = scan_ids;
            info.seq_ids = seq_ids;
        end
    end
    methods
        function res = pause_seq(self)
            res = cell(self.client.pause_seq());
            res = char(res{1});
        end
        function res = abort_seq(self)
            res = cell(self.client.abort_seq());
            res = char(res{1});
        end
        function res = start_seq(self)
            res = cell(self.client.start_seq());
            res = char(res{1});
        end
        function res = get_status(self)
            res = cell(self.client.get_status());
            res = char(res{1});
        end
        function [info] = get_imgs(self)
            res = double(self.client.get_imgs(10000)); % timeout of 10 s
            info = AnalysisClient.process_imgs(res);
        end
        function res = get_seq_num(self)
            res = double(self.client.get_seq_num());
        end
        function res = get_num_imgs(self)
            res = double(self.client.get_num_imgs());
        end
        function res = get_config(self)
            res = cell(self.client.get_config());
            res = cellfun(@char, res, 'UniformOutput', false);
        end
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
            remove(AnalysisClient.cache, keys(AnalysisClient.cache));
        end
        function res = get(url)
            cache = AnalysisClient.cache;
            if isKey(cache, url)
                res = cache(url);
                if ~isempty(res) && isvalid(res)
                    return;
                end
            end
            res = AnalysisClient(url);
            cache(url) = res;
        end
    end
end