%% ScanDataMgr is a manager that handles a single dataset. It processes it together, saves it. Usually interacts with a NaCsDataLive who populates it.
% Initial use case: live plotting or runtime plotting so the manager is
% quite memory conscious. Used for data from a scan only.
% Goal: Separate the tasks inside plot_data/plot_data_partial
% Saved data is consistent with the format required for NaCsData for
% further analysis.

classdef ScanDataMgr < handle
    properties
        scan_id; % id that identifies this DataMgr. Should be scan_id.
        
        imgs; % imgs to save. Cleared when images are saved
        new_imgs = []; % a new set of images that needs to be processed for summary_data
        seq_ids; % seq_ids to save. Cleared when saved
        new_seq_ids; % new_seq_ids 
        startidx = 1; % for imgs in the full scan for saving
        endidx = 0; % for imgs in the full scan for saving
        plot_counter = 0;
        
        config; 
        summary_data;
        
        hist_idx = 0;
        
        analysis; % the plot_data_partial output
        ParamList;
        n_loads; % figure out new home for this later...
        Alg;
        scgrp;
        
        % logicals
%         single_atom_logical; % in analysis
        loading_logical;
        survival_loading_logical;
        survival_logical;
        rearr_loading_logical;
        param_loads_rearr;
        
        %timing parameters
        ProcessInterval = 100; % number of imgs to process at a time
        PlotInterval = 100; % number of imgs to plot at a time 
        SaveInterval = 100; % number of imgs to save at a time
        NewImgFileInterval = 1000; % number of imgs for a new file
        NewSummaryFileInterval = 100; % number of sets of img files before starting a new "summary" file
        
        % files
        scan_fname;
        dname;
        dates = {};
        times = {};
        summary_fnames = {};
        img_fnames = {};
        names_fname;
        summary_fnames_to_save = {};
        img_fnames_to_save = {};
        summary_counter = 1;
        
        imgs_saved = 0;
    end

    methods(Access = private)
        function self = ScanDataMgr(scan_id)
            self.scan_id = scan_id;
            %Directory where data will be saved.  This is run in StartScan() to create file fname, which this code then reads
            if scan_id > 0
                scan_id_str = num2str(scan_id);
                dateStamp = scan_id_str(1:8);
                timeStamp = scan_id_str(9:14);
            else
                error('scan_id for scan data must be positive!');
            end
            dname = DateTimeStampDirectory(dateStamp, timeStamp);
            [scan_fname, date, time] = DateTimeStampFilename(dateStamp, timeStamp, dname);
            ScanIn = load(scan_fname);
            self.config = ScanIn.Scan;
            self.config.version = 3; % really version 3... will change this
            self.imgs = [];
            self.seq_ids = [];
            self.summary_data = struct();
            self.summary_data.n_seq = 0;
            self.summary_data.single_atom_signal = [];
            self.summary_data.av_images = zeros(self.config.FrameSize(1), self.config.FrameSize(2), self.config.NumImages);
            if isfield(self.config, 'Rearrangement')
                if self.config.Rearrangement
                    params = self.config.Params;
                    unique_params = unique(params);
                    num_params = length(unique_params);
                    self.summary_data.rearr_success = zeros(1, num_params);
                    self.summary_data.rearr_n = zeros(1, num_params);
                    Alg_cb = str2func(self.config.Rearr.Algo);
                    cb_args = self.config.Rearr.AlgoCbArgs;
                    self.Alg = Alg_cb(cb_args{:});
%                     Alg_cb = RearrConsts.Algo;
%                     cb_args = RearrConsts.AlgoCbArgs;
%                     self.Alg = Alg_cb(cb_args{:});
                end
            end
            if isfield(self.config, 'ScanGroup')
                scangroup = ScanGroup.load(self.config.ScanGroup);
            elseif isfield(self.config, 'ScanSeq')
                scangroup = ScanGroup.load(self.config.ScanSeq.dump());
            end
            
            self.scgrp = scangroup;

            self.ParamList = [];
            self.analysis = struct();

            % for saving, first file is known.
            self.dname = dname;
            self.scan_fname = scan_fname;
            self.dates{end + 1} = date;
            self.times{end + 1} = time;
            self.names_fname = [scan_fname(1:end-4) '_names.mat'];
            summary_fname = [scan_fname(1:end-4), '_logicals.mat'];
            img_fname = [scan_fname(1:end-4) '_imgs.mat'];
            self.summary_fnames{end + 1} = summary_fname;
            self.summary_fnames_to_save{end + 1} = ['.' summary_fname(length(dname):end)];
            self.img_fnames{end + 1} = img_fname;
            self.img_fnames_to_save{end + 1} = ['.' img_fname(length(dname):end)];
            names = struct();
            names.summary_fnames = self.summary_fnames_to_save;
            names.img_fnames = self.img_fnames_to_save;
            names.dates = self.dates;
            names.times = self.times;
            save_atomic(self.names_fname, struct('names', names));

            self.ProcessInterval = self.config.NumPerGroup;
            self.PlotInterval = self.config.NumPerGroup;
            self.SaveInterval = self.config.NumPerGroup;
            self.NewImgFileInterval = self.config.NumPerGroup * ceil(1000 / self.config.NumPerGroup);
        end
    end

    methods
        function self = store_new_data(self, info)
            % info is an "info" cell array as created from
            % AnalysisClient.grab_imgs() excluding the 'scan_ids' field
            this_nseq = length(info.seq_ids);
            this_dim1 = self.config.FrameSize(1);
            this_dim2 = self.config.FrameSize(2);
            n_images_per_seq = self.config.NumImages;
            if isempty(self.new_imgs)
                nimgs = 0;
            else
                dims = size(self.new_imgs);
                nimgs = dims(3);
            end
            % We preallocate first
            self.new_imgs(this_dim1, this_dim2, nimgs + this_nseq * n_images_per_seq) = 0;
            for i = 1:this_nseq
                self.new_imgs(:,:,(nimgs + (i - 1) * n_images_per_seq + 1):(nimgs + i * n_images_per_seq)) = info.imgs{i};
            end
            self.new_seq_ids = [self.new_seq_ids, info.seq_ids];
        end
        
        function self = process_data(self, bProcess)
            % this function calculates summary_data from the new_imgs and
            % also transfers any new_imgs and new_seq_ids
            if ~exist('bProcess', 'var')
                bProcess = 0;
            end
            if length(self.new_seq_ids) < self.ProcessInterval && ~bProcess
                return
            end
            if isempty(self.new_imgs)
                return
            end
            single_atom_sites = self.config.SingleAtomSites;
            cutoffs = self.config.Cutoffs;
            num_images_per_seq = self.config.NumImages;
            num_sites = self.config.NumSites;
            box_size = self.config.BoxSize;
            frame_size = self.config.FrameSize;
            %% determine if we have atoms
            disp(size(self.new_imgs, 3));
            [single_atom_logical, single_atom_signal, single_atom_cutoffs, av_images] ...
                = find_single_atoms_sites_partial...
                    (self.new_imgs, single_atom_sites, cutoffs, num_images_per_seq, num_sites, box_size, frame_size, self.summary_data);

            self.analysis.Cutoffs = single_atom_cutoffs;
            %% determine logicals
            % Create loading and survival logicals
            % These are of dimensions (Number survival plots, number sites, number of
            % sequences).
            
%             loading_logical_cond = self.config.LoadingLogicals;
            survival_loading_logical_cond = self.config.SurvivalLoadingLogicals;
%             survival_logical_cond = self.config.SurvivalLogicals;
            if ~isfield(self.config, 'Rearrangement')
                is_rearrangement = 0;
            else
                is_rearrangement = self.config.Rearrangement;
            end
            if is_rearrangement
                logstruct = DataProcessTools.getCondLogicals(self.config, single_atom_logical, 1, self.Alg);
            else
                logstruct = DataProcessTools.getCondLogicals(self.config, single_atom_logical, 0);
%                 rearr_surv_logical_cond = self.config.RearrSurvLoadingLogicals;
            end
            
            num_images_total = size(self.new_imgs,3) + self.summary_data.n_seq * num_images_per_seq;
            num_seq = num_images_total / num_images_per_seq;
            loading_logical = logstruct.loading_logical;
            survival_loading_logical = logstruct.survival_loading_logical;
            survival_logical = logstruct.survival_logical;
            if is_rearrangement
                rearr_loading_logical = logstruct.rearr_loading_logical;
                self.n_loads = logstruct.n_loads;
            end
% 
%             loading_logical = find_logical(loading_logical_cond, single_atom_logical, num_sites, num_seq);
%             if is_rearrangement
%                 [rearr_loading_logical, n_loads] = self.Alg.getRearrangedLogicals(loading_logical);
%                 survival_loading_logical = find_logical(rearr_surv_logical_cond, rearr_loading_logical, num_sites, num_seq);
%                 self.n_loads = n_loads;
%             else
%                 survival_loading_logical = find_logical(survival_loading_logical_cond, single_atom_logical, num_sites, num_seq);
%             end
%             survival_logical = find_logical(survival_logical_cond, single_atom_logical, num_sites, num_seq);
            %% loading probabilities
            params = self.config.Params;
            param_list_orig = repmat(params, 1, ceil(num_images_total / (num_images_per_seq * length(params))));
            param_list_orig = param_list_orig(1:num_seq);
            param_struct = DataProcessTools.getLoadsByParam(params, loading_logical);
            param_loads = param_struct.param_loads;
            param_loads_err = param_struct.param_loads_err;
            param_loads_all = param_struct.param_loads_all;
            param_loads_err_all = param_struct.param_loads_err_all;
            param_loads_prob = param_struct.param_loads_prob;
            param_loads_err_prob = param_struct.param_loads_err_prob;
            param_loads_all_prob = param_struct.param_loads_all_prob;
            param_loads_err_all_prob = param_struct.param_loads_err_all_prob;
            num_attempts_by_param = param_struct.num_attempts_by_param;
            unique_params = unique(params);
            if is_rearrangement
                param_struct_rearr = DataProcessTools.getLoadsByParam(params, survival_loading_logical);
                self.param_loads_rearr = param_struct_rearr.param_loads;
            end
%             num_params = length(unique_params);
%             param_list = repmat(params, 1, ceil(num_images_total / (num_images_per_seq * length(params))));
%             param_list_all = param_list;
%             param_list = param_list(1:num_seq);
%             num_loading = length(loading_logical_cond);
%             
%             param_loads(num_loading, num_sites, num_params) = 0;
%             param_loads_err(num_loading, num_sites, num_params) = 0;
%             param_loads_all(num_loading, num_params) = 0;
%             param_loads_err_all(num_loading, num_params) = 0;
%             param_loads_prob(num_loading, num_sites, num_params) = 0;
%             param_loads_err_prob(num_loading, num_sites, num_params) = 0;
%             param_loads_all_prob(num_loading, num_params) = 0;
%             param_loads_err_all_prob(num_loading, num_params) = 0;
%             
%             for i = 1:num_loading
%                 for j = 1:num_sites
%                     [param_loads(i,j,:), param_loads_err(i,j,:), param_loads_prob(i,j,:), param_loads_err_prob(i,j,:)] = find_param_loads(loading_logical(i, j, :), param_list_all);
%                 end
%                 [param_loads_all(i,:), param_loads_err_all(i,:), param_loads_all_prob(i,:), param_loads_err_all_prob(i,:)] = ...
%                     find_param_loads(reshape(permute(loading_logical(i,:,:), [1,3,2]), 1, numel(loading_logical(i,:,:))), repmat(param_list_all, [1, num_sites]));
%             end
            %% get survivals
            num_survival = length(survival_loading_logical_cond);
            surv_struct = DataProcessTools.getSurvivalByParam(param_list_orig, survival_loading_logical, survival_logical);
            p_survival_all = surv_struct.p_survival_all;
            p_survival_err_all = surv_struct.p_survival_err_all;
            p_survival = surv_struct.p_survival;
            p_survival_err = surv_struct.p_survival_err;
%             p_survival_all(num_survival, num_params) = 0;
%             p_survival_err_all(num_survival, num_params) = 0;
%             p_survival{num_sites} = [];
%             p_survival_err{num_sites} = [];
%             
%             for n = 1:num_survival
%             % combine different sites
%                 [p_survival_all(n,:), p_survival_err_all(n,:)] = ...
%                     find_survival(reshape(permute(survival_logical(n,:,:), [1,3,2]), 1, numel(survival_logical(n,:,:))),...
%                         reshape(permute(survival_loading_logical(n,:,:), [1,3,2]), 1, numel(survival_loading_logical(n,:,:))),...
%                         repmat(param_list, 1, num_sites), unique_params, num_params);
% 
%                 if num_sites > 0
%                     for i = 1:num_sites
%                         this_p_surv = p_survival{i};
%                         this_p_surv_err = p_survival_err{i};
%                         [this_surv, this_surv_err] = find_survival(survival_logical(n,i,:), ...
%                             survival_loading_logical(n,i,:), param_list, unique_params, num_params);
%                         this_p_surv(end + 1, :) = this_surv;
%                         this_p_surv_err(end + 1, :) = this_surv_err;
%                         p_survival{i} = this_p_surv;
%                         p_survival_err{i} = this_p_surv_err;
%                     end
%                 end
%             end
            
            %% rearrangement specific
            if is_rearrangement
                this_n = size(self.new_imgs, 3) / num_images_per_seq;
                newest_first_idx = num_seq - this_n + 1;
                this_surv_loading_logical = survival_loading_logical(:,:, newest_first_idx:num_seq);
                this_surv_logical = survival_logical(:,:, newest_first_idx:num_seq);
                Algo = self.Alg;
                self.summary_data = getRearrangementSuccessByParam(this_surv_loading_logical, this_surv_logical, param_list_orig(newest_first_idx:num_seq), self.summary_data, @Algo.compareLogicals, length(unique(params)));
            end
            
            %% populate appropriate places
            self.analysis.LoadSite = param_loads;
            self.analysis.LoadSiteErr = param_loads_err;
            self.analysis.LoadAll = param_loads_all;
            self.analysis.LoadAllErr = param_loads_err_all;
            self.analysis.LoadSiteProbability = param_loads_prob;
            self.analysis.LoadSiteProbabilityErr = param_loads_err_prob;
            self.analysis.LoadProbability = param_loads_all_prob;
            self.analysis.LoadProbabilityErr = param_loads_err_all_prob;
            self.analysis.NumAttemptsByParam = num_attempts_by_param;
            if num_survival>0
               self.analysis.SurvivalProbability = p_survival_all;
               self.analysis.SurvivalProbabilityErr = p_survival_err_all;
               self.analysis.SurvivalSiteProbability = p_survival;
               self.analysis.SurvivalSiteProbabilityErr = p_survival_err;
            else
                self.analysis.SurvivalProbability = [];
                self.analysis.SurvivalProbabilityErr = [];
            end
            self.analysis.SingleAtomLogical = single_atom_logical;
            self.analysis.UniqueParameters = unique_params;

            % update summary_data
            self.summary_data.n_seq = num_seq;
            self.summary_data.single_atom_signal = single_atom_signal;
            self.summary_data.av_images = av_images;
            self.analysis.SummaryData = self.summary_data;
            
            % logicals
            self.loading_logical = loading_logical;
            self.survival_loading_logical = survival_loading_logical;
            self.survival_logical = survival_logical;
            if is_rearrangement
                self.rearr_loading_logical = rearr_loading_logical;
            end
            
            self.ParamList = param_list_orig;
            
            %% transfer new_imgs to imgs and clear new_imgs
            self.endidx = self.endidx + size(self.new_imgs, 3) / num_images_per_seq;
            self.plot_counter = self.plot_counter + size(self.new_imgs, 3) / num_images_per_seq;
            
            self.imgs = cat(3, self.imgs, self.new_imgs);
            self.seq_ids = [self.seq_ids, self.new_seq_ids];
            self.new_imgs = [];
            self.new_seq_ids = [];
        end
        
        function res = save_data(self, bSave)
            if ~exist('bSave', 'var')
                bSave = 0;
            end
            if length(self.seq_ids) < self.SaveInterval && ~bSave
                res = '';
                return
            end
            if self.imgs_saved == size(self.imgs, 3)
                % no new images
                res = '';
                return;
            end
            n_images_per_seq = self.config.NumImages;
            [~, ParamListToSave, AnalysisToSave] = make_partial_data([], self.ParamList, self.analysis, self.startidx:self.endidx);
            LogicalAnalysis = struct('SingleAtomLogical', AnalysisToSave.SingleAtomLogical, 'SummaryData', AnalysisToSave.SummaryData);
            save_atomic(self.summary_fnames{end}, struct('Scan', self.config, 'ParamList', ParamListToSave, ...
                                  'Analysis', LogicalAnalysis));
            AnalysisToSave = rmfield(AnalysisToSave, 'SingleAtomLogical');
            AnalysisToSave.SummaryData = rmfield(AnalysisToSave.SummaryData, 'single_atom_signal');
            save_atomic(self.scan_fname, struct('Scan', self.config, 'Analysis', AnalysisToSave));

            % save images
            save_atomic(self.img_fnames{end}, struct('Images', self.imgs));
            self.imgs_saved = size(self.imgs, 3);
            names_update = false;
            if size(self.imgs, 3) >= self.NewImgFileInterval * n_images_per_seq
                % start a new file and clear imgs
                [img_fname, date, time] = DateTimeStampFilename([], [], self.dname);
                img_fname = [img_fname(1:end-4) '_imgs.mat'];
                self.img_fnames{end + 1} = img_fname;
                self.img_fnames_to_save{end + 1} =  ['.' img_fname(length(self.dname):end)];
                self.dates{end + 1} = date;
                self.times{end + 1} = time;
                self.imgs = [];
                self.seq_ids = [];
                self.summary_counter = self.summary_counter + 1;
                names_update = true;
            end
            if self.summary_counter > self.NewSummaryFileInterval
                [summary_fname, ~, ~] = DateTimeStampFilename([], [], self.dname);
                summary_fname = [summary_fname(1:end-4), '_logicals.mat'];
                self.summary_fnames{end + 1} = summary_fname;
                self.summary_fnames_to_save{end + 1} = ['.' summary_fname(length(self.dname):end)];
                self.startidx = self.endidx + 1;
                self.summary_counter = 0;
            end
            if names_update % image counter reached
                names = struct();
                names.summary_fnames = self.summary_fnames_to_save;
                names.img_fnames = self.img_fnames_to_save;
                names.dates = self.dates;
                names.times = self.times;
                save_atomic(self.names_fname, struct('names', names));
            end
            res = self.img_fnames{end};
        end
        
        function self = plot_data(self, bPlot)
            if ~exist('bPlot', 'var')
                bPlot = 0;
            end
            if self.plot_counter < self.PlotInterval && ~bPlot
                return
            end
            %% load preliminaries
            frame_size = self.config.FrameSize;
            box_size = self.config.BoxSize;
            av_images = self.summary_data.av_images;
            single_atom_species = self.config.SingleAtomSpecies;
            single_atom_cutoffs = self.analysis.Cutoffs;
            num_sites = self.config.NumSites;
            ColorSet = nacstools.display.varycolorrainbow(num_sites);
            num_images_per_seq = self.config.NumImages;
            loading_logical_cond = self.config.LoadingLogicals;
            num_loading = length(loading_logical_cond);
            params = self.config.Params;
            plot_scale = self.config.PlotScale;
            param_units = self.config.ParamUnits;
            param_name = self.config.ParamName;
            if isempty(param_units) || (isstring(param_units) && param_units == "")
                % Do not show square bracket if the unit is empty.
                param_name_unit = param_name;
            else
                if isstring(param_name) && isstring(param_units)
                    param_name_unit = param_name + " [" + param_units + "]";
                else
                    param_name_unit = [param_name, ' [', param_units, ']'];
                end
            end
            num_seq_per_grp = length(params);
            num_images_total = self.summary_data.n_seq * num_images_per_seq;
            num_seq = num_images_total / num_images_per_seq;
            if ~isempty(self.scgrp)
                if self.scgrp.groupsize() == 1 && self.scgrp.scandim(1) == 1 % only for single 1-d scans
                    % if multiple variables scanned, use first scanned variablefor axes.
                    scannedparams = self.scgrp.get_scanaxis(1, 1);
                    params = scannedparams(params);
                else
                    plot_scale = 1;
                    param_name_unit = 'Index';
                end
            end
            unique_params = unique(params);
            num_params = length(unique_params);
            param_list = repmat(params, 1, ceil(num_images_total / (num_images_per_seq * length(params))));
            param_list = param_list(1:num_seq);
            survival_loading_logical_cond = self.config.SurvivalLoadingLogicals;
            num_survival = length(survival_loading_logical_cond);
            survival_logical_cond = self.config.SurvivalLogicals;
            fname = self.scan_fname;

            fit_type = self.config.FitType;
            if ~isfield(self.config, 'Rearrangement')
                is_rearrangement = 0;
                rearr_cutoffs = [];
                img_for_rearr_cutoff = 0;
            else
                is_rearrangement = self.config.Rearrangement;
                if is_rearrangement
                    rearr_cutoffs = self.config.Rearr.cutoffs;
                    img_for_rearr_cutoff = self.config.Rearr.imgForCutoff;
                else
                    rearr_cutoffs = [];
                    img_for_rearr_cutoff = 0;
                end
            end
            
            single_atom_sites = self.config.SingleAtomSites;
            %% plot images
            figInfo = DynProps();
            figInfo.fignum = 1;
            figInfo.bClear = 1;
            figInfo.fname = fname;
            PlotProcessTools.plotAvgImg(figInfo, av_images, single_atom_sites, frame_size, box_size, single_atom_species);
%             fig1 = figure(1); clf(fig1);
%             num_col = num_images_per_seq;
%             single_atom_sites = self.config.SingleAtomSites;
%             num_images_per_seq = self.config.NumImages;
%             for n = 1:num_images_per_seq
%                 subplot(1, num_col, n);
%                 imagesc(-ceil(frame_size(2)/2) + 1, -floor(frame_size(1)/2), av_images(:,:,n));
%                 colormap gray; shading flat; pbaspect([1,1,1]);   %axis equal;
% 
%                 title(['Image #',num2str(n),' ',single_atom_species{n}])
% 
%                 sites = single_atom_sites{n};
%                 if ~isempty(sites)
%                     for i = 1:num_sites
%                         % plot ROI for atom detection
%                         site = sites(i,:);
%                         rad = ceil((box_size-1)/2);
%                         x = site(1) - 0.5 - rad;%site(1)+round(frame_size/2)-0.5-rad;
%                         y = site(2) - 0.5 - rad;%site(2)+round(frame_size/2)-0.5-rad;
% 
%                         subplot(1, num_col, n); %(n-1)*num_col+1);
%                         hold on;
%                         rectangle('Position',[x, y, 2*rad+1, 2*rad+1],'EdgeColor','r');
%                         t = text(x-1, y-1, num2str(i));
%                         t.Color = 'red';
%                         hold off;
%                         axis equal
%                         axis tight
%                     end 
%                 end
%             end
            %% plot histograms
%             fig2 = figure(2); clf(fig2);
            if num_sites > 10
                site_idxs = mod(self.hist_idx:(self.hist_idx + 9), num_sites) + 1;
                self.hist_idx = mod(self.hist_idx + 10, num_sites);
            else
                site_idxs = 1:num_sites;
            end
            figInfo = DynProps();
            figInfo.fignum = 2;
            figInfo.bClear = 1;
            figInfo.fname = fname;
            PlotProcessTools.plotHistograms(figInfo, self.summary_data.single_atom_signal, single_atom_cutoffs, site_idxs, is_rearrangement, rearr_cutoffs, img_for_rearr_cutoff);
%             num_cols = num_images_per_seq;
%             plot_idx = 1;
%             for i = 1:num_rows
%                 for n = 1:num_cols
%                     cutoff = single_atom_cutoffs{n}(site_idxs(i));
%                     subplot(num_rows, num_cols, plot_idx);
%                     hold on;
%                     h_counts = histogram(self.summary_data.single_atom_signal(n,site_idxs(i),:),40);
%                     ymax = max(h_counts.Values(10:end)); % approx single atom hump
%                     ylim([0, 2*ymax]);
%                     plot([cutoff,cutoff],ylim,'-r');
%                     title(['site #',num2str(site_idxs(i))]);
%                     if i == num_sites
%                         if n == num_images_per_seq-1
%                             xlabel({'Counts', fname}, 'interpreter', 'none');
%                         else
%                             xlabel('Counts');
%                         end
%                     end
% %                     ylabel('Frequency')
%                     box on
%                     plot_idx = plot_idx + 1;
%                 end
%             end
            %% plot loading
            if is_rearrangement
                figInfo = DynProps();
                figInfo.fname = fname;
                figInfo.plot_scale = plot_scale;
                for i = 1:num_loading
                    figInfo.fignum = 30 + i;
                    figInfo.bClear = 1;
                    figInfo.subPlotTriple = [3,1,1];
                    PlotProcessTools.plotLoadingInTime(figInfo, self.loading_logical(i,:,:), num_seq_per_grp, loading_logical_cond(i), single_atom_species, site_idxs);
                    figInfo.subPlotTriple = [3,1,2];
                    figInfo.bClear = 0;
                    figInfo.param_name_unit = param_name_unit;
                    PlotProcessTools.plotLoadsInTime(figInfo, unique_params, self.analysis.LoadSite(i,:,:), self.analysis.LoadSiteErr(i,:,:), loading_logical_cond(i), single_atom_species, num_seq, site_idxs);
                    figInfo.subPlotTriple = [3,1,3];
                    % plot loads on all sites
                    % artificially make three dimensions
                    PlotProcessTools.plotLoadsInTime(figInfo, unique_params, self.analysis.LoadAll(i,:), self.analysis.LoadAllErr(i,:), loading_logical_cond(i), single_atom_species, num_seq * num_sites, 1);
                end
            else
                figInfo = DynProps();
                figInfo.fignum = 3;
                figInfo.bClear = 1;
                figInfo.subPlotTriple = [3 1 1];
                figInfo.fname = fname;
                figInfo.plot_scale = plot_scale;
                PlotProcessTools.plotLoadingInTime(figInfo, self.loading_logical, num_seq_per_grp, loading_logical_cond, single_atom_species, site_idxs);
                figInfo.bClear = 0;
                figInfo.subPlotTriple = [3 1 2];
                PlotProcessTools.plotLoadsInTime(figInfo, unique_params, self.analysis.LoadSite, self.analysis.LoadSiteErr, loading_logical_cond, single_atom_species, num_seq, site_idxs);
                figInfo.subPlotTriple = [3,1,3];
                PlotProcessTools.plotLoadsInTime(figInfo, unique_params, self.analysis.LoadAll, self.analysis.LoadAllErr, loading_logical_cond, single_atom_species, num_seq * num_sites, 1);
            end
%             num_grp = floor(num_images_total / (num_images_per_seq * num_seq_per_grp));
%             if num_grp > 0
%                 fignum = 30;
%                 if is_rearrangement
%                     for i = 1:num_loading
%                         temp_fig = figure(fignum + i); clf(temp_fig);
%                     end
%                 end
%                 fig3 = figure(3); clf(fig3);
%                 subplot(3,1,1);
%                 grp_loading(num_loading, num_sites, num_grp) = 0;
%                 legend_string21{num_loading * num_sites} = '';
                ColorSet2 = nacstools.display.varycolor(num_sites * num_loading);
%                 for i = 1:num_loading
%                     this_legend_string21{num_sites} = '';
%                     for j = 1:num_grp
%                         grp_ind = ((j-1)*num_seq_per_grp+1):j*num_seq_per_grp;
%                         grp_loading(i,:,j) = sum(self.loading_logical(i,:,grp_ind),3)/num_seq_per_grp;
%                     end
%                     for n = 1:num_sites
%                         figure(3);
%                         subplot(3,1,1);
%                         hold on;
%                         plot(num_seq_per_grp*[1:num_grp],squeeze(grp_loading(i,n,:)),'.-','Color',ColorSet2(num_sites * (i - 1) + n,:))
%                         if is_rearrangement
%                             figure(fignum + i);
%                             subplot(3,1,1);
%                             hold on;
%                             plot(num_seq_per_grp*[1:num_grp],squeeze(grp_loading(i,n,:)),'.-','Color',ColorSet2(num_sites * (i - 1) + n,:))
%                             ylim([0,1])
%                         end
%                         hold off
%                         this_legend_string21{n} = [logical_cond_2str(loading_logical_cond{i}, single_atom_species) ' (site ' int2str(n) ')'];
%                         legend_string21{num_sites*(i-1)+n} = [logical_cond_2str(loading_logical_cond{i}, single_atom_species) ' (site ' int2str(n) ')'];
%                     end
%                     if is_rearrangement
%                         figure(fignum + i);
%                         this_lgnd21=legend(this_legend_string21,'Location','eastoutside');
%                         set(this_lgnd21,'color','none');
%                         set(gca,'ygrid','on')
%                     end
%                 end
%                 figure(3);
%                 lgnd21=legend(legend_string21,'Location','eastoutside');
%                 set(lgnd21,'color','none');
% 
%                 box on
%                 if max(max(max(grp_loading))) == 0
%                     ylim([0,1])
%                 else
%                     ylim([0,1.3 * max(max(max(grp_loading)))+0.01])
%                 end
%                 set(gca,'ygrid','on')
%                 xlabel('Sequence number')
%                 ylabel(['Average (/',int2str(num_seq_per_grp), ') loading'])
%                 %%
%                 figure(3);
%                 subplot(3,1,2); hold on;
%                 %yyaxis left
%                 param_loads(num_loading, num_sites, num_params) = 0;
%                 param_loads_all(num_loading, num_params) = 0;
%                 if num_sites > 1
%                     legend_string22{num_loading*(num_sites + 1)} = '';
%                 else
%                     legend_string22{num_loading} = '';
%                 end
%                 %line_specs = {'rs','bs','ms','cs','gs','ys'};
%                 %ColorSet=nacstools.display.varycolor(num_sites);
%                 for i = 1:num_loading
%                     for j = 1:num_sites
%                         if num_sites > 1
%                             errorbar(unique_params/plot_scale, squeeze(self.analysis.LoadSite(i,j,:)), squeeze(self.analysis.LoadSiteErr(i,j,:)), 's','Color',ColorSet2(num_sites * (i - 1) + j,:),'Linewidth',0.7);
%                             legend_string22{(i-1)*(num_sites + 1)+j} = [logical_cond_2str(loading_logical_cond{i}, single_atom_species) '(site ' int2str(j) ')'];
%                         end
%                     end
% 
%                     errorbar(unique_params/plot_scale, squeeze(self.analysis.LoadAll(i,:)), abs(squeeze(self.analysis.LoadAllErr(i,:))), 's','Linewidth',0.7);
%                     % I added abs(param_loads_err_all) because imaginary for some weird
%                     % reason.  Fix later.
% 
%                     if num_sites > 1
%                         legend_string22{i*(num_sites+1)} = logical_cond_2str(loading_logical_cond{i}, single_atom_species);
%                     else
%                         legend_string22{i} = logical_cond_2str(loading_logical_cond{i}, single_atom_species);
%                     end
%                 end
%                 lgnd22=legend(legend_string22,'Location','eastoutside');
%                 set(lgnd22,'color','none');
%                 mean_loads = mean(param_loads_all(1, :));
%                 box on
%                 xlabel({param_name_unit, fname},'interpreter','none')
%                 ylabel('Loading rate')
%                 set(gca,'ygrid','on')
%                 if length(unique_params) > 1
%                     xlim([unique_params(1)- 0.1*(unique_params(end)-unique_params(1)),unique_params(end)+ 0.1*(unique_params(end)-unique_params(1))]/plot_scale)  ;
%                 end
%                 ylim([0, num_seq / num_params]); % yl(2)]); %set y min to 0.
% 
%                 yyaxis right
%                 ylim([0, 1])
%                 %%
%                 figure(3);
%                 subplot(3,1,3); hold on;
%                  for i = 1:num_loading
%                     errorbar(unique_params/plot_scale, squeeze(self.analysis.LoadAll(i,:)), abs(self.analysis.LoadAllErr(i,:)), 's','Linewidth',0.7);
%                     legend_string32{i} = logical_cond_2str(loading_logical_cond{i}, single_atom_species);
%                  end
%                 lgnd32=legend(legend_string32,'Location','eastoutside');
%                 set(lgnd32,'color','none');
%                 box on
%                 xlabel({param_name_unit, fname},'interpreter','none')
%                 ylabel('Total loads')
%                 set(gca,'ygrid','on')
%                 if length(unique_params) > 1
%                     xlim([unique_params(1)- 0.1*(unique_params(end)-unique_params(1)),unique_params(end)+ 0.1*(unique_params(end)-unique_params(1))]/plot_scale)  ;
%                 end
%                 ylim([0, num_sites * num_seq / num_params]); % yl(2)]); %set y min to 0.
% 
%                 yyaxis right
%                 ylim([0, 1])
% %             end
            %% plot survival
            figInfo = DynProps();
            figInfo.fignum = 4;
            figInfo.bClear = 1;
            figInfo.fname = fname;
            figInfo.plot_scale = plot_scale;
            figInfo.param_name_unit = param_name_unit;
            PlotProcessTools.plotSurvival(figInfo, unique_params, self.analysis.SurvivalSiteProbability, self.analysis.SurvivalSiteProbabilityErr, survival_logical_cond, survival_loading_logical_cond, single_atom_species, 1:num_sites); 
%             fig4 = figure(4); clf(fig4);
%             if num_survival > 0
%                 ncol = num_survival;
%                 nrow = 1;
%                 for n = 1 : num_survival
%                     if num_sites > 0
%                         subplot(nrow, ncol, (nrow-1)*ncol+n); hold on;
%                         title({['survive: image ' logical_cond_2str(survival_logical_cond{n}, single_atom_species)], ...
%                             ['load: image ' logical_cond_2str(survival_loading_logical_cond{n}, single_atom_species)]})
%                       %  line_specs = {'rs-','bs-','ms-','cs-','gs-','ys-'};
%                         %legend_string3n1{num_sites+1} = '';
%                         legend_string3n1{num_sites} = ''; %if not plotting average
%                         for i = 1:num_sites
%                          errorbar(unique_params/plot_scale, squeeze(self.analysis.SurvivalSiteProbability{i}(n,:)), ...
%                                 self.analysis.SurvivalSiteProbabilityErr{i}(n,:), 'Color', ColorSet(i,:),'Linewidth',1.0);
%                             legend_string3n1{i} = ['site #',num2str(i)];
%                         end
% %                         BRING BACK TO PLOT AVERAGE
% %                         legend_string3n1{end} = 'all sites';
% %                         errorbar(unique_params/plot_scale, self.analysis.SurvivalProbability(n,:), self.analysis.SurvivalProbabilityErr(n,:), 'ks-');
%                         % % save data
%                         % save('survival_20170731_143150.mat','unique_params','plot_scale','p_survival_all', 'p_survival_err_all', '-v7.3');
%                         hold off;
% 
%                         ylim([0 1])
%                         if length(unique_params) > 1
%                             xlim([unique_params(1)- 0.1*(unique_params(end)-unique_params(1)), unique_params(end)+ 0.1*(unique_params(end)-unique_params(1))]/plot_scale)  ;
%                         end
%                         grid on; box on;
%                         if n == cld(num_survival, 2)
%                             xlabel({param_name_unit, fname}, 'interpreter', 'none')
%                         else
%                             xlabel({param_name_unit})
%                         end
%                         ylabel('Survival probability')
%                         legend(legend_string3n1)
%                     end
% 
%                     ft = 0;
%                     if ischar(fit_type) && ~strcmp(fit_type, 'none')
%                         ft = fittype(fit_type);
%                     elseif iscell(fit_type) && (~ischar(fit_type{n}) || (ischar(fit_type{n}) && ~strcmp(fit_type{n}, 'none')))
%                         if ischar(fit_type{n})
%                             ft = fittype(fit_type{n});
%                         else
%                             ft = fit_type{n};
%                         end
%                     end
%                     if ~isnumeric(ft)
%                         try
%                             fit_obj = fit(unique_params'/plot_scale, p_survival_all(n,:)', ft);
%                             hold on; plot(fit_obj,'-r'); hold off;
%                             xlimits = xlim;
%                             s1 = ['fit to ', formula(fit_obj)];
%                             [avg, err] = get_mean_error_from_fit(fit_obj);
%                             s2 = sprintf(['\n', num2str(avg)]);
%                             s3 = sprintf(['\n', num2str(err)]);
%                             text(xlimits(1)+(xlimits(2)-xlimits(1))/10, 0.9, [s1, s2, s3])
%                             legend off
%                         catch
%                             fprintf('could not fit model\n');
%                         end
%                     end
% 
%                     ylim([0 1])
%                     if length(unique_params) > 1
%                         xlim([unique_params(1)- 0.1*(unique_params(end)-unique_params(1)), unique_params(end)+ 0.1*(unique_params(end)-unique_params(1))]/plot_scale)  ;
%                     end
%                     grid on; box on;
%                     if n == cld(num_survival, 2)
%                         xlabel({param_name_unit, fname}, 'interpreter','none')
%                     else
%                         xlabel({param_name_unit})
%                     end
%                     if is_rearrangement
% 
%                     else
%                         ylabel('Survival probability')
%                     end
%                     title({['survive: ' logical_cond_2str(survival_logical_cond{n}, single_atom_species)], ...
%                         ['load: ' logical_cond_2str(survival_loading_logical_cond{n}, single_atom_species)]})
%                 end
%             end
            
             %% plot avg survival
            figInfo = DynProps();
            figInfo.fignum = 5;
            figInfo.bClear = 1;
            figInfo.fname = fname;
            figInfo.plot_scale = plot_scale;
            figInfo.param_name_unit = param_name_unit;
            PlotProcessTools.plotSurvival(figInfo, unique_params, {self.analysis.SurvivalProbability}, {self.analysis.SurvivalProbabilityErr}, survival_logical_cond, survival_loading_logical_cond, single_atom_species, 1); 
%             if num_survival > 0 && num_sites > 1
%                 fig5 = figure(5); clf(fig5);
%                 for n = 1 : num_survival
%                     subplot(nrow, ncol, (nrow-1)*ncol+n); hold on;
%                     title({['survive: image ' logical_cond_2str(survival_logical_cond{n}, single_atom_species)], ...
%                         ['load: image ' logical_cond_2str(survival_loading_logical_cond{n}, single_atom_species)]});
%                     errorbar(unique_params/plot_scale, self.analysis.SurvivalProbability(n,:), self.analysis.SurvivalProbabilityErr(n,:), 'ks-');
%                     ylim([0 1])
%                     if length(unique_params) > 1
%                         xlim([unique_params(1)- 0.1*(unique_params(end)-unique_params(1)), unique_params(end)+ 0.1*(unique_params(end)-unique_params(1))]/plot_scale)  ;
%                     end
%                     grid on; box on;
%                     if n == cld(num_survival, 2)
%                         xlabel({param_name_unit, fname}, 'interpreter', 'none')
%                     else
%                         xlabel({param_name_unit})
%                     end
%                     ylabel('Survival probability')
%                     legend('all sites')
%                 end
%             end
            %% rearrangement specific analysis
            if is_rearrangement
                figInfo = DynProps();
                figInfo.fignum = 6;
                figInfo.bClear = 1;
                figInfo.subPlotTriple = [2,1,1];
                figInfo.plot_scale = plot_scale;
                figInfo.param_name_unit = param_name_unit;
                figInfo.fname = fname;
                PlotProcessTools.plotRearrSuc(figInfo, unique_params, self.summary_data);
                
                figInfo.bClear = 0;
                figInfo.subPlotTriple = [2,1,2];
                PlotProcessTools.plotNumAtomLoads(figInfo, self.n_loads);
                
                figInfo = DynProps();
                figInfo.fignum = 7;
                figInfo.bClear = 1;
                figInfo.plot_scale = plot_scale;
                figInfo.param_name_unit = param_name_unit;
                figInfo.fname = fname;
                figInfo.AuxPlotIdx = 2;
                figInfo.AuxData = self.param_loads_rearr;
                PlotProcessTools.plotLoadingBySite(figInfo, unique_params, self.analysis.LoadSite, self.analysis.LoadSiteErr, self.analysis.NumAttemptsByParam, loading_logical_cond, single_atom_species);
                
%                 summary_data = self.summary_data;
%                 fig6 = figure(6); clf(fig6);
%                 subplot(2,1,1)
%                 hold on;
%                 rearr_sd = sqrt(summary_data.rearr_success .* (1 - summary_data.rearr_success)) ./ sqrt(summary_data.rearr_n);
%                 errorbar(unique_params/plot_scale, summary_data.rearr_success, rearr_sd, 'Linewidth', 1.0)
%                 ylim([0 1])
%                 if length(unique_params) > 1
%                     xlim([unique_params(1)- 0.1*(unique_params(end)-unique_params(1)), unique_params(end)+ 0.1*(unique_params(end)-unique_params(1))]/plot_scale);
%                 end
%                 grid on; box on;
%                 xlabel({param_name_unit})
%                 ylabel('Rearrangement Survival')
%                 subplot(2,1,2)
%                 hold on;
%                 histogram(self.n_loads(1,:), length(unique(self.n_loads(1,:))));
%                 xlabel('Number of atoms loaded')
%                 ylabel('Counts')
            end
            
            self.plot_counter = 0;
        end
    end

    properties(Constant, Access=private)
        cache = containers.Map('KeyType', 'int64', 'ValueType', 'any');
    end
    methods(Static)
        function dropAll()
            remove(ScanDataMgr.cache, keys(ScanDataMgr.cache));
        end
        function res = get(scan_id)
            cache = ScanDataMgr.cache;
            if isKey(cache, scan_id)
                res = cache(scan_id);
                if ~isempty(res) && isvalid(res)
                    return;
                end
            end
            res = ScanDataMgr(scan_id);
            cache(scan_id) = res;
        end
    end
end