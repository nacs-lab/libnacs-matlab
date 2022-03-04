classdef PlotProcessTools 
    methods(Static)
        function plotAvgImg(figInfo, av_imgs, single_atom_sites, frame_size, box_size, single_atom_species)
            % figInfo is a DynProps to allow for default value settings
            num = figInfo.fignum(1);
            bClear = figInfo.bClear(1);
            fig1 = figure(num); 
            if bClear
                clf(fig1);
            end
            num_col = size(av_imgs, 3);
            num_sites = size(single_atom_sites{1}, 1);
            for n = 1:num_col
                subplot(1, num_col, n);
                imagesc(-ceil(frame_size(2)/2) + 1, -floor(frame_size(1)/2), av_imgs(:,:,n));
                colormap gray; shading flat; pbaspect([1,1,1]);   %axis equal;

                title(['Image #',num2str(n),' ',single_atom_species{n}])

                sites = single_atom_sites{n};
                if ~isempty(sites)
                    for i = 1:num_sites
                        % plot ROI for atom detection
                        site = sites(i,:);
                        rad = ceil((box_size-1)/2);
                        x = site(1) - 0.5 - rad;%site(1)+round(frame_size/2)-0.5-rad;
                        y = site(2) - 0.5 - rad;%site(2)+round(frame_size/2)-0.5-rad;

                        subplot(1, num_col, n); %(n-1)*num_col+1);
                        hold on;
                        rectangle('Position',[x, y, 2*rad+1, 2*rad+1],'EdgeColor','r');
                        t = text(x-1, y-1, num2str(i));
                        t.Color = 'red';
                        hold off;
                        axis equal
                        axis tight
                    end 
                end
            end
            if isfield(figInfo, 'fname')
                annotation('textbox', [0.1, 0, 0.9, 0.05], 'string', figInfo.fname, 'EdgeColor', 'none', 'Interpreter', 'none')
            end
        end
        function plotHistograms(figInfo, signals, cutoffs, site_idxs, is_rearr, rearr_cutoff, img_for_cutoff)
            num = figInfo.fignum(1);
            bClear = figInfo.bClear(1);
            fig1 = figure(num); 
            if bClear
                clf(fig1);
            end
            num_rows = length(site_idxs);
            num_cols = size(signals, 1);
            num_sites = num_rows;
            plot_idx = 1;
            for i = 1:num_rows
                for n = 1:num_cols
                    cutoff = cutoffs{n}(site_idxs(i));
                    subplot(num_rows, num_cols, plot_idx);
                    hold on;
                    h_counts = histogram(signals(n,site_idxs(i),:),40);
                    ymax = max(h_counts.Values(10:end)); % approx single atom hump
                    ylim([0, 2*ymax]);
                    plot([cutoff,cutoff],ylim,'-r');
                    if is_rearr
                        ind = find(img_for_cutoff == n);
                        if ~isempty(ind)
                            plot([rearr_cutoff{ind}(site_idxs(i)), rearr_cutoff{ind}(site_idxs(i))],ylim,'-g');
                        end
                    end
                    title(['site #',num2str(site_idxs(i))]);
                    if i == num_sites
                        xlabel('Counts');
                    end
%                     ylabel('Frequency')
                    box on
                    plot_idx = plot_idx + 1;
                end
            end
            if isfield(figInfo, 'fname')
                annotation('textbox', [0.1, 0, 0.9, 0.05], 'string', figInfo.fname, 'EdgeColor', 'none', 'Interpreter', 'none')
            end
        end
        function plotLoadingInTime(figInfo, logicals, num_seq_per_grp, loading_logical_cond, single_atom_species, site_idxs)
            num = figInfo.fignum(1);
            bClear = figInfo.bClear(0);
            fig1 = figure(num); 
            if bClear
                clf(fig1);
            end
%             subplot_row = figInfo.subPlotRow(1);
%             subplot_col = figInfo.subPlotCol(1);
%             subplot_idx = figInfo.subPlotIdx(1);
            subplot_triple = figInfo.subPlotTriple([1 1 1]);
            subplot(subplot_triple(1), subplot_triple(2), subplot_triple(3))
            num_loading = size(logicals, 1);
            num_sites = length(site_idxs);
            num_grp = floor(size(logicals, 3) / num_seq_per_grp);
            grp_loading = zeros(num_loading, num_sites, num_grp);
%             grp_loading(num_loading, num_sites, num_grp) = 0;
            legend_string21{num_loading * num_sites} = '';
            ColorSet2 = nacstools.display.varycolorrainbow(num_sites * num_loading);
            logicals = logicals(:,site_idxs,:);
            for i = 1:num_loading
                this_legend_string21{num_sites} = '';
                for j = 1:num_grp
                    grp_ind = ((j-1)*num_seq_per_grp+1):j*num_seq_per_grp;
                    grp_loading(i,:,j) = sum(logicals(i,:,grp_ind),3)/num_seq_per_grp;
                end
                for n = 1:num_sites
                    hold on;
                    plot(num_seq_per_grp*[1:num_grp],squeeze(grp_loading(i,n,:)),'.-','Color',ColorSet2(num_sites * (i - 1) + n,:))
                    hold off
                    this_legend_string21{n} = [logical_cond_2str(loading_logical_cond{i}, single_atom_species) ' (site ' int2str(site_idxs(n)) ')'];
                    legend_string21{num_sites*(i-1)+n} = [logical_cond_2str(loading_logical_cond{i}, single_atom_species) ' (site ' int2str(site_idxs(n)) ')'];
                end
            end
            lgnd21=legend(legend_string21,'Location','eastoutside');
            set(lgnd21,'color','none');

            box on
            if num_grp > 0
                if max(max(max(grp_loading))) == 0
                    ylim([0,1])
                else
                    ylim([0,1.3 * max(max(max(grp_loading)))+0.01])
                end
            end
            set(gca,'ygrid','on')
            xlabel('Sequence number')
            ylabel(['Average (/',int2str(num_seq_per_grp), ') loading'])
            if isfield(figInfo, 'fname')
                annotation('textbox', [0.1, 0, 0.9, 0.05], 'string', figInfo.fname, 'EdgeColor', 'none', 'Interpreter', 'none')
            end
        end
        function plotLoadsInTime(figInfo, unique_params, param_loads, param_loads_err, loading_logical_cond, single_atom_species, num_seq, site_idx)
            num = figInfo.fignum(1);
            bClear = figInfo.bClear(0);
            fig1 = figure(num); 
            if bClear
                clf(fig1);
            end
            subplot_triple = figInfo.subPlotTriple([1 1 1]);
            subplot(subplot_triple(1), subplot_triple(2), subplot_triple(3))
            
            param_name_unit = figInfo.param_name_unit('');
            
            plot_scale = figInfo.plot_scale(1);
            num_params = length(unique_params);
            num_loading = size(param_loads, 1);
            num_sites = length(site_idx);
            ColorSet2 = nacstools.display.varycolorrainbow(num_sites * num_loading);
            if num_sites > 1
                param_loads = param_loads(:, site_idx, :);
            end
            if num_sites > 1
                legend_string22{num_loading*(num_sites + 1)} = '';
            else
                legend_string22{num_loading} = '';
            end
            %line_specs = {'rs','bs','ms','cs','gs','ys'};
            %ColorSet=nacstools.display.varycolor(num_sites);
            for i = 1:num_loading
                for j = 1:num_sites
                    if num_params == 1
                        hold on;
                        errorbar(unique_params/plot_scale, squeeze(param_loads(i,j)), abs(param_loads_err(i,j)), 's','Linewidth',0.7);
                        hold off;
                        legend_string22{(i-1)*(num_sites + 1)+j} = [logical_cond_2str(loading_logical_cond{i}, single_atom_species) '(site ' int2str(site_idx(j)) ')'];
                    elseif num_sites == 1
                        errorbar(unique_params/plot_scale, squeeze(param_loads(i,:)), abs(param_loads_err(i,:)), 's','Linewidth',0.7);
                    else
                        hold on;
                        errorbar(unique_params/plot_scale, squeeze(param_loads(i,j,:)), squeeze(param_loads_err(i,j,:)), 's','Color',ColorSet2(num_sites * (i - 1) + j,:),'Linewidth',0.7);
                        hold off
                        legend_string22{(i-1)*(num_sites + 1)+j} = [logical_cond_2str(loading_logical_cond{i}, single_atom_species) '(site ' int2str(site_idx(j)) ')'];
                    end
                end

                if num_sites > 1
                    legend_string22{i*(num_sites+1)} = logical_cond_2str(loading_logical_cond{i}, single_atom_species);
                else
                    legend_string22{i} = logical_cond_2str(loading_logical_cond{i}, single_atom_species);
                end
            end
            lgnd22=legend(legend_string22,'Location','eastoutside');
            set(lgnd22,'color','none');
            box on
            xlabel({param_name_unit},'interpreter','none')
            ylabel('Loading rate')
            set(gca,'ygrid','on')
            if length(unique_params) > 1
                xlim([unique_params(1)- 0.1*(unique_params(end)-unique_params(1)),unique_params(end)+ 0.1*(unique_params(end)-unique_params(1))]/plot_scale)  ;
            end
            ylim([0, num_seq / num_params]); % yl(2)]); %set y min to 0.

            yyaxis right
            ylim([0, 1])
            if isfield(figInfo, 'fname')
                annotation('textbox', [0.1, 0, 0.9, 0.05], 'string', figInfo.fname, 'EdgeColor', 'none', 'Interpreter', 'none')
            end
        end
        function plotSurvival(figInfo, unique_params, surv_prob, surv_err, survival_logical_cond, survival_loading_logical_cond, single_atom_species, site_idx)
            num = figInfo.fignum(1);
            bClear = figInfo.bClear(1);
            fig1 = figure(num); 
            if bClear
                clf(fig1);
            end
            plot_scale = figInfo.plot_scale(1);
            param_name_unit = figInfo.param_name_unit('');
            fname = figInfo.fname('');
            num_survival = size(surv_prob{1}, 1);
            num_sites = length(site_idx);
            ColorSet = nacstools.display.varycolorrainbow(num_sites);
            ncol = num_survival;
            nrow = 1;
            for n = 1 : num_survival
                if num_sites > 0
                    subplot(nrow, ncol, (nrow-1)*ncol+n); hold on;
                    title({['survive: image ' logical_cond_2str(survival_logical_cond{n}, single_atom_species)], ...
                        ['load: image ' logical_cond_2str(survival_loading_logical_cond{n}, single_atom_species)]})
                  %  line_specs = {'rs-','bs-','ms-','cs-','gs-','ys-'};
                    %legend_string3n1{num_sites+1} = '';
                    legend_string3n1{num_sites} = ''; %if not plotting average
                    for i = 1:num_sites
                     errorbar(unique_params/plot_scale, squeeze(surv_prob{site_idx(i)}(n,:)), ...
                            surv_err{site_idx(i)}(n,:), 'Color', ColorSet(i,:),'Linewidth',1.0);
                        legend_string3n1{i} = ['site #',num2str(site_idx(i))];
                    end
                    hold off;

                    ylim([0 1])
                    if length(unique_params) > 1
                        lims = sort([unique_params(1)- 0.1*(unique_params(end)-unique_params(1)), unique_params(end)+ 0.1*(unique_params(end)-unique_params(1))]/plot_scale);
                        xlim(lims);
                    end
                    grid on; box on;
                    if n == cld(num_survival, 2)
                        xlabel({param_name_unit, fname}, 'interpreter', 'none')
                    else
                        xlabel({param_name_unit})
                    end
                    ylabel('Survival probability')
                    legend(legend_string3n1)
                end

                ylim([0 1])
                if length(unique_params) > 1
                    lims = sort([unique_params(1)- 0.1*(unique_params(end)-unique_params(1)), unique_params(end)+ 0.1*(unique_params(end)-unique_params(1))]/plot_scale);
                    xlim(lims);
                end
                grid on; box on;
                if n == cld(num_survival, 2)
                    xlabel({param_name_unit, fname}, 'interpreter','none')
                else
                    xlabel({param_name_unit})
                end
                ylabel('Survival probability')
                title({['survive: ' logical_cond_2str(survival_logical_cond{n}, single_atom_species)], ...
                    ['load: ' logical_cond_2str(survival_loading_logical_cond{n}, single_atom_species)]})
            end
        end
        function plotRearrSuc(figInfo, unique_params, sData)
            num = figInfo.fignum(1);
            bClear = figInfo.bClear(0);
            fig1 = figure(num); 
            if bClear
                clf(fig1);
            end
            subplot_triple = figInfo.subPlotTriple([1 1 1]);
            subplot(subplot_triple(1), subplot_triple(2), subplot_triple(3))
            plot_scale = figInfo.plot_scale(1);
            param_name_unit = figInfo.param_name_unit('');
            fname = figInfo.fname('');
            hold on;
            rearr_sd = sqrt(sData.rearr_success .* (1 - sData.rearr_success)) ./ sqrt(sData.rearr_n);
            errorbar(unique_params/plot_scale, sData.rearr_success, rearr_sd, 'Linewidth', 1.0)
            ylim([0 1])
            if length(unique_params) > 1
                xlim([unique_params(1)- 0.1*(unique_params(end)-unique_params(1)), unique_params(end)+ 0.1*(unique_params(end)-unique_params(1))]/plot_scale);
            end
            grid on; box on;
            xlabel({param_name_unit})
            ylabel('Rearrangement Survival')
            if isfield(figInfo, 'fname')
                annotation('textbox', [0.1, 0, 0.9, 0.05], 'string', figInfo.fname, 'EdgeColor', 'none', 'Interpreter', 'none')
            end
        end
        function plotNumAtomLoads(figInfo, n_loads)
            num = figInfo.fignum(1);
            bClear = figInfo.bClear(0);
            fig1 = figure(num); 
            if bClear
                clf(fig1);
            end
            subplot_triple = figInfo.subPlotTriple([1 1 1]);
            subplot(subplot_triple(1), subplot_triple(2), subplot_triple(3))
            hold on;
            histogram(n_loads(1,:), length(unique(n_loads(1,:))));
            xlabel('Number of atoms loaded')
            ylabel('Counts')
            if isfield(figInfo, 'fname')
                annotation('textbox', [0.1, 0, 0.9, 0.05], 'string', figInfo.fname, 'EdgeColor', 'none', 'Interpreter', 'none')
            end
        end
        function plotLoadingBySite(figInfo, unique_params, param_loads, param_loads_err, num_attempts_by_param, loading_logical_cond, single_atom_species)
            % param_loads should be a total
            num = figInfo.fignum(1);
            bClear = figInfo.bClear(0);
            fig1 = figure(num); 
            if bClear
                clf(fig1);
            end
            plot_scale = figInfo.plot_scale(1);
            param_name_unit = figInfo.param_name_unit('');
            fname = figInfo.fname('');
            AuxPlotIdx = figInfo.AuxPlotIdx(0);
            AuxData = figInfo.AuxData([]);
            num_imgs = size(param_loads, 1);
            num_sites = size(param_loads, 2);
            num_params = length(unique_params);
            % 3rd dimension of param_loads is as a function of params
            ColorSet = nacstools.display.varycolorrainbow(num_params);
            for i = 1:num_imgs
                subplot(num_imgs, 1, i);
                hold on;
                legendstr = cell(1, num_params);
                title(['load: ' logical_cond_2str(loading_logical_cond{i}, single_atom_species)]);
                for j = 1:num_params
                    errorbar(1:num_sites, squeeze(param_loads(i,:,j)) / num_attempts_by_param(j), squeeze(param_loads_err(i,:,j)) / num_attempts_by_param(j), 'Color', ColorSet(j,:), 'Linewidth', 1.0)
                    legendstr{j} = sprintf('%s: %f', param_name_unit, unique_params(j) / plot_scale);
                end
                if i == AuxPlotIdx
                    for j = 1:num_params
                        plot(1:num_sites, squeeze(AuxData(1,:,j)) / num_attempts_by_param(j), 'Color', ColorSet(j,:), 'Linewidth', 1.0, 'LineStyle', '--')
                    end
                end
                xlabel('Site index')
                ylabel('Loading rate');
                legend(legendstr);
            end
            if isfield(figInfo, 'fname')
                annotation('textbox', [0.1, 0, 0.9, 0.05], 'string', figInfo.fname, 'EdgeColor', 'none', 'Interpreter', 'none')
            end
        end
    end
end