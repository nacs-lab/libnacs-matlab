classdef ExptControl < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                      matlab.ui.Figure
        PauseSeqButton                matlab.ui.control.Button
        StartSeqButton                matlab.ui.control.Button
        AbortSeqButton                matlab.ui.control.Button
        StatusLabel                   matlab.ui.control.Label
        LastScanIDLabel               matlab.ui.control.Label
        LastSeqIDLabel                matlab.ui.control.Label
        RefreshRateinsEditFieldLabel  matlab.ui.control.Label
        RefreshRateinsEditField       matlab.ui.control.NumericEditField
        LastSavedFileLabel            matlab.ui.control.Label
        OpenAnalysisPanelButton       matlab.ui.control.Button
    end

    
    properties (Access = private)
        AU % AnalysisUser for this control panel
        refresh_rate % for AU 
        cur_seq_id = 0
        cur_scan_id = 0
        
        ImgTimer;
        StatusTimer;
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            app.AU = AnalysisUser.get(Consts().MatlabURL);
            
            % start timers if needed
            app.ImgTimer = timer('ExecutionMode', 'fixedSpacing', 'Period', 2, ...
                                'TimerFcn', {@(obj, event, app_obj) app_obj.processImgLoop(), app});
            app.StatusTimer = timer('ExecutionMode', 'fixedDelay', 'Period', 1 ...
                                'TimerFcn', {@(obj, event, app_obj) app_obj.updateStatusLoop(), app});
            app.ImgTimer.start();
            app.StatusTimer.start();
        end
        
        % grabs, processes, saves images on a timer
        function processImgLoop(app)
            info = app.AU.grab_imgs();
            nseqs = length(info.imgs);
            if nseqs == 0
                return
            end
            start_idx = 1;
            if app.cur_scan_id ~= 0 && app.cur_scan_id ~= info.scan_ids(1)
                % if next batch consists of a new scan. Flush out the data
                % manager associated with the scan. 
                DM = DataMgr.get(app.cur_scan_id);
                DM.process_data(1);
                DM.plot_data(1);
                DM.save_data(1);
            end
            while start_idx <= nseqs
                end_idx = nseqs;
                app.cur_scan_id = info.scan_ids(start_idx);
                new_scan_idx = find(info.scan_ids(start_idx:end_idx) ~= app.cur_scan_id, 1);
                % if new_scan_idx is empty, then all members belong to the
                % cur_scan_id
                if isempty(new_scan_idx)
                    end_idx = nseqs;
                else
                    end_idx = start_idx + new_scan_idx - 1;
                end
                % process, plot and save cur_scan_id images
                if app.cur_scan_id > 0
                    DM = DataMgr.get(app.cur_scan_id);
                else
                    DM = SingleShotDataMgr.get(app.cur_scan_id);
                end
                this_info = struct();
                this_info.imgs = info.imgs(start_idx:end_idx);
                this_info.seq_ids = info.seq_ids(start_idx:end_idx);
                DM.store_new_data(this_info);
                DM.process_data();
                DM.plot_data();
                fname = DM.save_data();
                start_idx = end_idx + 1;
            end
            app.cur_seq_id = info.seq_ids(end);
            app.LastScanIDLabel.Text = ['Last Scan ID: ' num2str(app.cur_scan_id)];
            app.LastSeqIDLabel.Text = ['Last Seq ID: ' num2str(app.cur_seq_id)];
            app.LastSavedFileLabel.Text = ['Last Saved File: ' fname];
        end
        
        function updateStatusLoop(app)
            res = app.AU.get_status();
            if res == 0
                state_str = 'Stopped';
            elseif res == 1
                state_str = 'Running';
            elseif res == 2
                state_str = 'Paused';
            else
                state_str = 'Unknown';
            end
            app.StatusLabel.Text = ['Status: ' state_str];
        end

        % Button pushed function: PauseSeqButton
        function PauseSeqButtonPushed(app, event)
            app.AU.pause_seq();
        end

        % Button pushed function: StartSeqButton
        function StartSeqButtonPushed(app, event)
            app.AU.start_seq();
        end

        % Button pushed function: AbortSeqButton
        function AbortSeqButtonPushed(app, event)
            app.AU.abort_seq();
        end

        % Value changed function: RefreshRateinsEditField
        function RefreshRateinsEditFieldValueChanged(app, event)
            value = app.RefreshRateinsEditField.Value;
            app.AU.set_refresh_rate(value)
        end

        % Button pushed function: OpenAnalysisPanelButton
        function OpenAnalysisPanelButtonPushed(app, event)
            
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 536 455];
            app.UIFigure.Name = 'MATLAB App';

            % Create PauseSeqButton
            app.PauseSeqButton = uibutton(app.UIFigure, 'push');
            app.PauseSeqButton.ButtonPushedFcn = createCallbackFcn(app, @PauseSeqButtonPushed, true);
            app.PauseSeqButton.FontSize = 24;
            app.PauseSeqButton.Position = [28 280 154 88];
            app.PauseSeqButton.Text = 'Pause Seq';

            % Create StartSeqButton
            app.StartSeqButton = uibutton(app.UIFigure, 'push');
            app.StartSeqButton.ButtonPushedFcn = createCallbackFcn(app, @StartSeqButtonPushed, true);
            app.StartSeqButton.FontSize = 24;
            app.StartSeqButton.Position = [28 182 154 88];
            app.StartSeqButton.Text = 'Start Seq';

            % Create AbortSeqButton
            app.AbortSeqButton = uibutton(app.UIFigure, 'push');
            app.AbortSeqButton.ButtonPushedFcn = createCallbackFcn(app, @AbortSeqButtonPushed, true);
            app.AbortSeqButton.FontSize = 24;
            app.AbortSeqButton.FontColor = [1 0 0];
            app.AbortSeqButton.Position = [28 82 154 88];
            app.AbortSeqButton.Text = 'Abort Seq';

            % Create StatusLabel
            app.StatusLabel = uilabel(app.UIFigure);
            app.StatusLabel.HorizontalAlignment = 'center';
            app.StatusLabel.WordWrap = 'on';
            app.StatusLabel.FontSize = 20;
            app.StatusLabel.Position = [18 377 513 67];
            app.StatusLabel.Text = 'Status: ';

            % Create LastScanIDLabel
            app.LastScanIDLabel = uilabel(app.UIFigure);
            app.LastScanIDLabel.FontSize = 18;
            app.LastScanIDLabel.Position = [237 260 242 42];
            app.LastScanIDLabel.Text = 'Last Scan ID: ';

            % Create LastSeqIDLabel
            app.LastSeqIDLabel = uilabel(app.UIFigure);
            app.LastSeqIDLabel.FontSize = 18;
            app.LastSeqIDLabel.Position = [237 217 242 42];
            app.LastSeqIDLabel.Text = 'Last Seq ID:';

            % Create RefreshRateinsEditFieldLabel
            app.RefreshRateinsEditFieldLabel = uilabel(app.UIFigure);
            app.RefreshRateinsEditFieldLabel.HorizontalAlignment = 'right';
            app.RefreshRateinsEditFieldLabel.FontSize = 18;
            app.RefreshRateinsEditFieldLabel.Position = [231 324 162 23];
            app.RefreshRateinsEditFieldLabel.Text = 'Refresh Rate (in s):';

            % Create RefreshRateinsEditField
            app.RefreshRateinsEditField = uieditfield(app.UIFigure, 'numeric');
            app.RefreshRateinsEditField.Limits = [0 Inf];
            app.RefreshRateinsEditField.RoundFractionalValues = 'on';
            app.RefreshRateinsEditField.ValueChangedFcn = createCallbackFcn(app, @RefreshRateinsEditFieldValueChanged, true);
            app.RefreshRateinsEditField.Position = [408 316 82 40];

            % Create LastSavedFileLabel
            app.LastSavedFileLabel = uilabel(app.UIFigure);
            app.LastSavedFileLabel.HorizontalAlignment = 'center';
            app.LastSavedFileLabel.VerticalAlignment = 'top';
            app.LastSavedFileLabel.FontSize = 18;
            app.LastSavedFileLabel.Position = [18 9 489 63];
            app.LastSavedFileLabel.Text = 'Last Saved File:';

            % Create OpenAnalysisPanelButton
            app.OpenAnalysisPanelButton = uibutton(app.UIFigure, 'push');
            app.OpenAnalysisPanelButton.ButtonPushedFcn = createCallbackFcn(app, @OpenAnalysisPanelButtonPushed, true);
            app.OpenAnalysisPanelButton.FontSize = 24;
            app.OpenAnalysisPanelButton.Position = [237 94 275 99];
            app.OpenAnalysisPanelButton.Text = 'Open Analysis Panel';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ExptControl

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)
            app.ImgTimer.stop()
            app.StatusTimer.stop()
            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end