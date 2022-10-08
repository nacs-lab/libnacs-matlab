classdef NaCsDataLive < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                  matlab.ui.Figure
        DateEditFieldLabel        matlab.ui.control.Label
        DateEditField             matlab.ui.control.NumericEditField
        NaCsDataLiveLabel         matlab.ui.control.Label
        TimeEditFieldLabel        matlab.ui.control.Label
        TimeEditField             matlab.ui.control.NumericEditField
        PathPrefixEditFieldLabel  matlab.ui.control.Label
        PathPrefixEditField       matlab.ui.control.EditField
        RefreshButton             matlab.ui.control.Button
        NumSeqsLabel              matlab.ui.control.Label
        NumScansLabel             matlab.ui.control.Label
        ScanDimsLabel             matlab.ui.control.Label
        ScanParamsLabel           matlab.ui.control.Label
        PlotLoadsButton           matlab.ui.control.Button
        SeqStartEditFieldLabel    matlab.ui.control.Label
        SeqStartEditField         matlab.ui.control.NumericEditField
        SeqEndEditFieldLabel      matlab.ui.control.Label
        SeqEndEditField           matlab.ui.control.NumericEditField
        toincludeallseqsLabel     matlab.ui.control.Label
        SitesEditFieldLabel       matlab.ui.control.Label
        SitesEditField            matlab.ui.control.EditField
        LeaveemptytoincludeallsitesOtherwiseseparatesitesbycommaLabel  matlab.ui.control.Label
        ParamsEditFieldLabel      matlab.ui.control.Label
        ParamsEditField           matlab.ui.control.EditField
        Label                     matlab.ui.control.Label
        PlotHistogramsButton      matlab.ui.control.Button
        PlotSurvsButton           matlab.ui.control.Button
        RearrangedLabel           matlab.ui.control.Label
        IdxLoadsEditFieldLabel    matlab.ui.control.Label
        IdxLoadsEditField         matlab.ui.control.EditField
        IdxSurvsEditFieldLabel    matlab.ui.control.Label
        IdxSurvsEditField         matlab.ui.control.EditField
        Label_2                   matlab.ui.control.Label
        SeqNumEditFieldLabel      matlab.ui.control.Label
        SeqNumEditField           matlab.ui.control.EditField
        PlotImagesButton          matlab.ui.control.Button
        MessageLabel              matlab.ui.control.Label
        
        data % current data
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: PlotHistogramsButton
        function PlotHistogramsButtonPushed(app, event)
            function app = cb(app)
                nsites = app.data.data.Scan.NumSites;
                nimgs = app.data.data.Scan.NumImages;
                if isempty(app.SitesEditField.Value)
                    sites_idx = 1:nsites;
                else
                    sites_idx = convertCSVStr(app,app.SitesEditField.Value);
                end
                app.data.plotHistogramOnSite(1:nimgs, sites_idx, 1)
            end
            guarded_call(app, @cb, 'PlotHistogram');
        end

        % Button pushed function: PlotLoadsButton
        function PlotLoadsButtonPushed(app, event)
            function app = cb(app)
                nsites = app.data.data.Scan.NumSites;
                if isempty(app.SitesEditField.Value)
                    site_idxs = 1:nsites;
                else
                    site_idxs = convertCSVStr(app,app.SitesEditField.Value);
                end
                if isempty(app.IdxLoadsEditField.Value)
                    num_loading = length(app.data.data.Scan.LoadingLogicals);
                    log_idxs = 1:num_loading;
                else
                    log_idxs = convertCSVStr(app,app.IdxLoadsEditField.Value);
                end
                app.data.plotLoads(log_idxs, site_idxs, 2)
            end
            guarded_call(app, @cb, 'PlotLoads');
        end

        % Button pushed function: PlotSurvsButton
        function PlotSurvsButtonPushed(app, event)
            function app = cb(app)
                app.data.beAtPreReq(2);
                nsites = app.data.data.Scan.NumSites;
                nparams = length(unique(app.data.data.ParamList));
                if isempty(app.SitesEditField.Value)
                    site_idxs = 1:nsites;
                else
                    site_idxs = convertCSVStr(app,app.SitesEditField.Value);
                    if ismember(-1, site_idxs)
                        site_idxs = -1;
                    end
                end
                if isempty(app.IdxSurvsEditField.Value)
                    num_loading = length(app.data.data.Scan.SurvivalLogicals);
                    surv_idxs = 1:num_loading;
                else
                    surv_idxs = convertCSVStr(app,app.IdxSurvsEditField.Value);
                end
                if isempty(app.ParamsEditField.Value)
                    % default option
                    param_idxs = 1:nparams;
                    is_default = 1;
                else
                    param_vals = convertCSVStr(app,app.ParamsEditField.Value);
                    param_idxs = app.data.getIdxsForScanDim(param_vals(1), param_vals(2:end));
                    is_default = 0;
                end
                
                % decision tree for determining X values and whether to
                % plot
                Xdata = [];
                if is_default
                    % only plot if there is only one scan, one scan dim and one scan variable
                    if app.data.scgrp.groupsize() == 1 && app.data.scgrp.scandim(1) == 1 && app.data.scgrp.axisnum(1, 1) == 1
                        [Xdata, Xname] = app.data.getScanParam(1, 1, 1);
                    end
                else
                    paramdims = param_vals(2:end);
                    if sum(paramdims == 0) ~= 1
                        % multiple scanned parameters, or no scanned parameters no good parameter to
                        % plot
                    else
                        scan_dim = find(paramdims == 0);
                        if app.data.scgrp.axisnum(param_vals(1), scan_dim) == 1
                            % only one scan variable and can plot
                            [Xdata, Xname] = app.data.getScanParam(param_vals(1), scan_dim, 1);
                        end
                    end
                end
                
                if isempty(Xdata)
                    Xdata = 1:nparams;
                    Xname = 'Index';
                end
                
                surv_prob = cellfun(@(x) x(surv_idxs, param_idxs), app.data.data.Analysis.SurvivalSiteProbability, 'UniformOutput', false);
                surv_err = cellfun(@(x) x(surv_idxs, param_idxs), app.data.data.Analysis.SurvivalSiteProbabilityErr, 'UniformOutput', false);
                survival_logical_cond = app.data.data.Scan.SurvivalLogicals(surv_idxs);
                survival_loading_logical_cond = app.data.data.Scan.SurvivalLoadingLogicals(surv_idxs);
                single_atom_species = app.data.data.Scan.SingleAtomSpecies;
                
                figInfo = DynProps();
                figInfo.fignum = 3;
                figInfo.bClear = 1;
                figInfo.param_name_unit = Xname;
                figInfo.fname = app.data.master_fname;
                
                if length(site_idxs) == 1 && site_idxs == -1
                    PlotProcessTools.plotSurvival(figInfo, Xdata, {app.data.data.Analysis.SurvivalProbability(surv_idxs, param_idxs)}, {app.data.data.Analysis.SurvivalProbabilityErr(surv_idxs, param_idxs)}, survival_logical_cond, survival_loading_logical_cond, single_atom_species, 1);
                else
                    PlotProcessTools.plotSurvival(figInfo, Xdata, surv_prob, surv_err, survival_logical_cond, survival_loading_logical_cond, single_atom_species, site_idxs)
                end
            end
            guarded_call(app, @cb, 'PlotSurvs');
        end

        % Button pushed function: PlotImagesButton
        function PlotImagesButtonPushed(app, event)
            function app = cb(app)
                nsites = app.data.data.Scan.NumSites;
                nimages = app.data.data.Scan.NumImages;
                if isempty(app.SeqNumEditField.Value)
                    img_num = 1;
                else
                    num_from_field = str2double(app.SeqNumEditField.Value);
                    if num_from_field <= 0
                        app.data.plotAvgImg(1:nimages, 1:nsites, 4);
                        return
                    else
                        img_num = str2double(app.SeqNumEditField.Value);
                    end
                end
                app.data.plotImgFromSeq(img_num, 1:nimages, 1:nsites, 0, 4)
            end
            guarded_call(app, @cb, 'PlotImages');
        end

        % Button pushed function: RefreshButton
        function RefreshButtonPushed(app, event)
            function app = cb(app)
                date = app.DateEditField.Value;
                time = app.TimeEditField.Value;
                app.data = NaCsData(date, time, app.PathPrefixEditField.Value);
                app.NumSeqsLabel.Text = ['NumSeqs: ', num2str(app.data.data.Analysis.SummaryData.n_seq)];
                grpsize = app.data.scgrp.groupsize();
                app.NumScansLabel.Text = ['NumScans: ', num2str(grpsize)];
                lbl = '';
                lblparam = '';
                for i = 1:grpsize
                    ndim = app.data.scgrp.scandim(i);
                    nseqs = app.data.scgrp.scansize(i);
                    if i ~= grpsize
                        lbl = [lbl, num2str(ndim), ', '];
                        lblparam = [lblparam, num2str(nseqs), ', '];
                    else
                        lbl = [lbl, num2str(ndim)];
                        lblparam = [lblparam, num2str(nseqs)];
                    end
                end
                app.ScanDimsLabel.Text = ['ScanDims: ', lbl];
                app.ScanParamsLabel.Text = ['ScanParams: ', lblparam];
                app.RearrangedLabel.Text = ['Rearranged: ', num2str(app.data.data.Scan.Rearrangement)];
            end
            guarded_call(app, @cb, 'Refresh');
        end
        
        function res = convertCSVStr(app,a)
            acell = strsplit(a, ',');
            res = cellfun(@(s) str2num(s), acell);
        end
        
        function guarded_call(app, cb, name, varargin)
            % name is for printing purposes only
            try
                cb(app, varargin{:})
                app.MessageLabel.Text = {'Message', [name ' Succeeded']};
            catch e
                app.MessageLabel.Text = {'Message', [name ' Failed'], e.message};
            end
        end
    end
    

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 640 480];
            app.UIFigure.Name = 'MATLAB App';

            % Create DateEditFieldLabel
            app.DateEditFieldLabel = uilabel(app.UIFigure);
            app.DateEditFieldLabel.HorizontalAlignment = 'right';
            app.DateEditFieldLabel.FontSize = 18;
            app.DateEditFieldLabel.Position = [33 389 55 23];
            app.DateEditFieldLabel.Text = {'Date'; ''};

            % Create DateEditField
            app.DateEditField = uieditfield(app.UIFigure, 'numeric');
            app.DateEditField.Position = [103 387 84 27];

            % Create NaCsDataLiveLabel
            app.NaCsDataLiveLabel = uilabel(app.UIFigure);
            app.NaCsDataLiveLabel.FontSize = 24;
            app.NaCsDataLiveLabel.Position = [241 431 160 30];
            app.NaCsDataLiveLabel.Text = 'NaCsDataLive';

            % Create TimeEditFieldLabel
            app.TimeEditFieldLabel = uilabel(app.UIFigure);
            app.TimeEditFieldLabel.HorizontalAlignment = 'right';
            app.TimeEditFieldLabel.FontSize = 18;
            app.TimeEditFieldLabel.Position = [206 389 55 23];
            app.TimeEditFieldLabel.Text = 'Time';

            % Create TimeEditField
            app.TimeEditField = uieditfield(app.UIFigure, 'numeric');
            app.TimeEditField.Position = [276 387 84 27];

            % Create PathPrefixEditFieldLabel
            app.PathPrefixEditFieldLabel = uilabel(app.UIFigure);
            app.PathPrefixEditFieldLabel.HorizontalAlignment = 'right';
            app.PathPrefixEditFieldLabel.FontSize = 18;
            app.PathPrefixEditFieldLabel.Position = [385 389 89 23];
            app.PathPrefixEditFieldLabel.Text = 'PathPrefix';

            % Create PathPrefixEditField
            app.PathPrefixEditField = uieditfield(app.UIFigure, 'text');
            app.PathPrefixEditField.Position = [489 387 124 27];
            app.PathPrefixEditField.Value = 'N:\NaCsLab\Data\';

            % Create RefreshButton
            app.RefreshButton = uibutton(app.UIFigure, 'push');
            app.RefreshButton.ButtonPushedFcn = createCallbackFcn(app, @RefreshButtonPushed, true);
            app.RefreshButton.FontSize = 18;
            app.RefreshButton.Position = [33 23 146 56];
            app.RefreshButton.Text = 'Refresh';

            % Create NumSeqsLabel
            app.NumSeqsLabel = uilabel(app.UIFigure);
            app.NumSeqsLabel.FontSize = 18;
            app.NumSeqsLabel.Position = [400 355 202 33];
            app.NumSeqsLabel.Text = 'NumSeqs:';
            
            % Create NumScansLabel
            app.NumScansLabel = uilabel(app.UIFigure);
            app.NumScansLabel.FontSize = 18;
            app.NumScansLabel.Position = [400 325 202 33];
            app.NumScansLabel.Text = 'NumScans:';

            % Create ScanDimsLabel
            app.ScanDimsLabel = uilabel(app.UIFigure);
            app.ScanDimsLabel.FontSize = 18;
            app.ScanDimsLabel.Position = [400 295 202 38];
            app.ScanDimsLabel.Text = 'ScanDims:';

            % Create ScanParamsLabel
            app.ScanParamsLabel = uilabel(app.UIFigure);
            app.ScanParamsLabel.FontSize = 18;
            app.ScanParamsLabel.Position = [400 265 202 38];
            app.ScanParamsLabel.Text = 'ScanParams:';

            % Create PlotLoadsButton
            app.PlotLoadsButton = uibutton(app.UIFigure, 'push');
            app.PlotLoadsButton.ButtonPushedFcn = createCallbackFcn(app, @PlotLoadsButtonPushed, true);
            app.PlotLoadsButton.FontSize = 18;
            app.PlotLoadsButton.Position = [190 86 170 64];
            app.PlotLoadsButton.Text = {'Plot Loads'; ''};

            % Create SeqStartEditFieldLabel
            app.SeqStartEditFieldLabel = uilabel(app.UIFigure);
            app.SeqStartEditFieldLabel.HorizontalAlignment = 'right';
            app.SeqStartEditFieldLabel.FontSize = 18;
            app.SeqStartEditFieldLabel.Position = [12 343 76 23];
            app.SeqStartEditFieldLabel.Text = {'SeqStart'; ''};

            % Create SeqStartEditField
            app.SeqStartEditField = uieditfield(app.UIFigure, 'numeric');
            app.SeqStartEditField.Position = [103 341 84 27];
            app.SeqStartEditField.Value = 1;

            % Create SeqEndEditFieldLabel
            app.SeqEndEditFieldLabel = uilabel(app.UIFigure);
            app.SeqEndEditFieldLabel.HorizontalAlignment = 'right';
            app.SeqEndEditFieldLabel.FontSize = 18;
            app.SeqEndEditFieldLabel.Position = [193 343 70 23];
            app.SeqEndEditFieldLabel.Text = 'SeqEnd';

            % Create SeqEndEditField
            app.SeqEndEditField = uieditfield(app.UIFigure, 'numeric');
            app.SeqEndEditField.Position = [278 341 84 27];
            app.SeqEndEditField.Value = -1;

            % Create toincludeallseqsLabel
            app.toincludeallseqsLabel = uilabel(app.UIFigure);
            app.toincludeallseqsLabel.HorizontalAlignment = 'center';
            app.toincludeallseqsLabel.Position = [206 313 154 22];
            app.toincludeallseqsLabel.Text = '-1 to include all seqs';

            % Create SitesEditFieldLabel
            app.SitesEditFieldLabel = uilabel(app.UIFigure);
            app.SitesEditFieldLabel.HorizontalAlignment = 'right';
            app.SitesEditFieldLabel.FontSize = 18;
            app.SitesEditFieldLabel.Position = [12 280 55 23];
            app.SitesEditFieldLabel.Text = 'Sites';

            % Create SitesEditField
            app.SitesEditField = uieditfield(app.UIFigure, 'text');
            app.SitesEditField.FontSize = 18;
            app.SitesEditField.Position = [82 276 303 31];

            % Create LeaveemptytoincludeallsitesOtherwiseseparatesitesbycommaLabel
            app.LeaveemptytoincludeallsitesOtherwiseseparatesitesbycommaLabel = uilabel(app.UIFigure);
            app.LeaveemptytoincludeallsitesOtherwiseseparatesitesbycommaLabel.HorizontalAlignment = 'center';
            app.LeaveemptytoincludeallsitesOtherwiseseparatesitesbycommaLabel.Position = [12 248 379 30];
%             app.LeaveemptytoincludeallsitesOtherwiseseparatesitesbycommaLabel.WordWrap = 'on';
            app.LeaveemptytoincludeallsitesOtherwiseseparatesitesbycommaLabel.Text = 'Leave empty to include all sites. Otherwise, separate sites by comma. -1 for average sites.';

            % Create ParamsEditFieldLabel
            app.ParamsEditFieldLabel = uilabel(app.UIFigure);
            app.ParamsEditFieldLabel.HorizontalAlignment = 'right';
            app.ParamsEditFieldLabel.FontSize = 18;
            app.ParamsEditFieldLabel.Position = [-1 216 68 23];
            app.ParamsEditFieldLabel.Text = 'Params';

            % Create ParamsEditField
            app.ParamsEditField = uieditfield(app.UIFigure, 'text');
            app.ParamsEditField.FontSize = 18;
            app.ParamsEditField.Position = [82 212 125 31];

            % Create Label
            app.Label = uilabel(app.UIFigure);
%             app.Label.WordWrap = 'on';
            app.Label.Position = [12 157 215 48];
            app.Label.Text = 'First number is scanidx, then comma separated list of dimension ScanDims. 0 specifies all members of that dimension';

            % Create PlotHistogramsButton
            app.PlotHistogramsButton = uibutton(app.UIFigure, 'push');
            app.PlotHistogramsButton.ButtonPushedFcn = createCallbackFcn(app, @PlotHistogramsButtonPushed, true);
            app.PlotHistogramsButton.FontSize = 18;
            app.PlotHistogramsButton.Position = [33 87 146 61];
            app.PlotHistogramsButton.Text = 'Plot Histograms';

            % Create PlotSurvsButton
            app.PlotSurvsButton = uibutton(app.UIFigure, 'push');
            app.PlotSurvsButton.ButtonPushedFcn = createCallbackFcn(app, @PlotSurvsButtonPushed, true);
            app.PlotSurvsButton.FontSize = 18;
            app.PlotSurvsButton.Position = [190 15 170 64];
            app.PlotSurvsButton.Text = {'Plot Survs'; ''};

            % Create RearrangedLabel
            app.RearrangedLabel = uilabel(app.UIFigure);
            app.RearrangedLabel.FontSize = 18;
            app.RearrangedLabel.Position = [400 240 202 38];
            app.RearrangedLabel.Text = 'Rearranged:';

            % Create IdxLoadsEditFieldLabel
            app.IdxLoadsEditFieldLabel = uilabel(app.UIFigure);
            app.IdxLoadsEditFieldLabel.HorizontalAlignment = 'right';
            app.IdxLoadsEditFieldLabel.FontSize = 18;
            app.IdxLoadsEditFieldLabel.Position = [223 216 95 23];
            app.IdxLoadsEditFieldLabel.Text = 'Idx - Loads';

            % Create IdxLoadsEditField
            app.IdxLoadsEditField = uieditfield(app.UIFigure, 'text');
            app.IdxLoadsEditField.FontSize = 18;
            app.IdxLoadsEditField.Position = [333 212 125 31];

            % Create IdxSurvsEditFieldLabel
            app.IdxSurvsEditFieldLabel = uilabel(app.UIFigure);
            app.IdxSurvsEditFieldLabel.HorizontalAlignment = 'right';
            app.IdxSurvsEditFieldLabel.FontSize = 18;
            app.IdxSurvsEditFieldLabel.Position = [226 178 92 23];
            app.IdxSurvsEditFieldLabel.Text = 'Idx - Survs';

            % Create IdxSurvsEditField
            app.IdxSurvsEditField = uieditfield(app.UIFigure, 'text');
            app.IdxSurvsEditField.FontSize = 18;
            app.IdxSurvsEditField.Position = [333 174 125 31];

            % Create Label_2
            app.Label_2 = uilabel(app.UIFigure);
%             app.Label_2.WordWrap = 'on';
            app.Label_2.Position = [476 178 145 64];
            app.Label_2.Text = 'Index into loading logicals and survival logicals defined in StartScan';

            % Create SeqNumEditFieldLabel
            app.SeqNumEditFieldLabel = uilabel(app.UIFigure);
            app.SeqNumEditFieldLabel.HorizontalAlignment = 'right';
            app.SeqNumEditFieldLabel.Position = [368 124 55 22];
            app.SeqNumEditFieldLabel.Text = {'SeqNum'; ''};

            % Create SeqNumEditField
            app.SeqNumEditField = uieditfield(app.UIFigure, 'text');
            app.SeqNumEditField.Position = [430 123 62 24];

            % Create PlotImagesButton
            app.PlotImagesButton = uibutton(app.UIFigure, 'push');
            app.PlotImagesButton.ButtonPushedFcn = createCallbackFcn(app, @PlotImagesButtonPushed, true);
            app.PlotImagesButton.FontSize = 18;
            app.PlotImagesButton.Position = [368 23 129 88];
            app.PlotImagesButton.Text = 'Plot Images';

            % Create MessageLabel
            app.MessageLabel = uilabel(app.UIFigure);
            app.MessageLabel.HorizontalAlignment = 'center';
            app.MessageLabel.VerticalAlignment = 'top';
%             app.MessageLabel.WordWrap = 'on';
            app.MessageLabel.FontSize = 14;
            app.MessageLabel.Position = [509 34 112 135];
            app.MessageLabel.Text = 'Message';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = NaCsDataLive

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end