%% SingleShotDataMgr
% Manager for single shots of data. Memory conscious, so after getting one
% batch, immediately disposes for another batch. 
classdef SingleShotDataMgr < handle
    properties
        id;
        info = struct();
        imgs = zeros(0,0,0);
        num_imgs_per_seq = [];
        fname;
        date;
        time;
    end
    
    methods(Access = private)
        function self = SingleShotDataMgr(scan_id)
            self.id = scan_id;
            if self.id < 0
                scan_id_str = num2str(scan_id);
                if length(scan_id_str) == 15
                    % normal format
                    dateStamp = scan_id_str(2:9);
                    timeStamp = scan_id_str(10:15);
                    [fname, date, time] = DateTimeStampFilename(dateStamp, timeStamp);
                else
                    % use current time
                    [fname, date, time] = DateTimeStampFilename();
                end
            else
                error('%s, scan_id for single shot data must be negative!', scan_id);
            end
            self.fname = fname;
            self.date = date;
            self.time = time;
        end
    end
    
    methods
        function self = store_new_data(self, info)
            self.info = info; 
        end
        
        function self = process_data(self, bProcess)
            % always processes unless explicitly told not to
            if ~exist('bProcess', 'var')
                bProcess = 1;
            end
            if bProcess && ~isempty(fieldnames(self.info))
                % naive preallocation
                img_idx = 1;
                new_imgs = zeros(size(self.info.imgs{1}, 1), size(self.info.imgs{1}, 2), size(self.info.imgs{1}, 3) * length(self.info.seq_ids));
                for i = 1:length(self.info.seq_ids)
                    these_imgs = self.info.imgs{i};
                    self.num_imgs_per_seq(i) = size(these_imgs, 3);
                    new_imgs(:,:,img_idx:(img_idx + size(these_imgs,3) -1)) = these_imgs;
                    img_idx = img_idx + size(these_imgs,3);
                end
                if size(new_imgs, 3) > sum(self.num_imgs_per_seq)
                    new_imgs(:,:, (sum(self.num_imgs_per_seq) + 1):end) = [];
                end
                self.imgs = new_imgs;
                self.info = struct();
            end
        end
        
        function res = save_data(self, bSave)
            if ~exist('bSave', 'var')
                bSave = 1;
            end
            if bSave && ~isempty(self.num_imgs_per_seq)
                if isfile(self.fname)
                    mf = matfile(self.fname, 'Writable', true);
                    new_imgs_size = size(self.imgs, 3);
                    mf.imgs(:,:,(end + 1):(end + new_imgs_size)) = self.imgs;
                    mf.num_imgs_per_seq(1,(end + 1):(end + length(self.num_imgs_per_seq))) = self.num_imgs_per_seq;
                else
                    imgs = self.imgs;
                    num_imgs_per_seq = self.num_imgs_per_seq;
                    save(self.fname, 'imgs', 'num_imgs_per_seq', '-v7.3');
                end
                self.imgs = zeros(0,0,0);
                self.num_imgs_per_seq = [];
                res = self.fname;
            else
                res = '';
            end
        end
        
        function self = plot_data(self, bPlot)
            if ~exist('bPlot', 'var')
                bPlot = 1;
            end
            if bPlot && ~isempty(self.num_imgs_per_seq)
                fig1 = figure(1); clf(fig1);
                nrows = length(self.num_imgs_per_seq);
                ncols = max(self.num_imgs_per_seq);
                img_idx = 1;
                frame_size = size(self.imgs);
                for i = 1:nrows
                    for j = 1:self.num_imgs_per_seq(i)
                        subplot(nrows, ncols, nrows * (i - 1) + j);
                        imagesc(-ceil(frame_size(2)/2) + 1, -floor(frame_size(1)/2), self.imgs(:,:,img_idx));
                        colormap gray; shading flat; pbaspect([1,1,1]);   %axis equal;
                        img_idx = img_idx + 1;
                    end
                end
            end
        end
    end
    
    properties(Constant, Access=private)
        cache = containers.Map('KeyType', 'int64', 'ValueType', 'any');
    end
    methods(Static)
        function dropAll()
            remove(SingleShotDataMgr.cache, keys(SingleShotDataMgr.cache));
        end
        function res = get(scan_id)
            if ~exist('scan_id', 'var')
                scan_id = -1;
            end
            cache = SingleShotDataMgr.cache;
            if isKey(cache, scan_id)
                res = cache(scan_id);
                if ~isempty(res) && isvalid(res)
                    return;
                end
            end
            res = SingleShotDataMgr(scan_id);
            cache(scan_id) = res;
        end
    end
end