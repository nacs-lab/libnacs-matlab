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
            for n = 1:num_col
                num_sites = size(single_atom_sites{n},1);
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
            num_cols = size(signals, 1);
            if ~iscell(site_idxs)
                tmpIdx = cell(num_cols,1);
                for i = 1:num_cols
                    tmpIdx{i} = site_idxs;
                end
                site_idxs = tmpIdx;
            end
            for n = 1:num_cols
                num_rows = length(site_idxs{n});
                num_sites = num_rows;
                for i = 1:num_rows
                    plot_idx = (i-1)*num_cols + n;
                    cutoff = cutoffs{n}(site_idxs{n}(i));
                    subplot(num_rows, num_cols, plot_idx);
                    hold on;
                    h_counts = histogram(signals(n,site_idxs{n}(i),:),40);
                    ymax = max(h_counts.Values(10:end)); % approx single atom hump
                    ylim([0, 2*ymax]);
                    plot([cutoff,cutoff],ylim,'-r');
                    if is_rearr
                        ind = find(img_for_cutoff == n);
                        if ~isempty(ind)
                            plot([rearr_cutoff{ind}(site_idxs{n}(i)), rearr_cutoff{ind}(site_idxs{n}(i))],ylim,'-g');
                        end
                    end
                    title(['site #',num2str(site_idxs{n}(i))]);
                    if i == num_sites
                        xlabel('Counts');
                    end
%                     ylabel('Frequency')
                    box on
                end
            end
            if isfield(figInfo, 'fname')
                annotation('textbox', [0.1, 0, 0.9, 0.05], 'string', figInfo.fname, 'EdgeColor', 'none', 'Interpreter', 'none')
            end
        end
        function plotLoadingInTime(figInfo, logicals, num_seq_per_grp, loading_logical_cond, single_atom_species, site_idxs)
            num = figInfo.fignum(1);
            bClear = figInfo.bClear(0);
            bLeg = figInfo.bLeg(1);
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
            if ~iscell(site_idxs)
                tmpIdx = cell(num_loading,1);
                for i = 1:num_loading
                    tmpIdx{i} = site_idxs;
                end
                site_idxs = tmpIdx;
            end
            num_sites = [];
            for i = 1:num_loading
                num_sites(i) = length(site_idxs{i});
            end
            num_grp = floor(size(logicals, 3) / num_seq_per_grp);
            grp_loading = zeros(num_loading, max(num_sites), num_grp);
            legend_string21{sum(num_sites)} = '';
            ColorSet2 = nacstools.display.varycolorrainbow(sum(num_sites));
            for i = 1:num_loading
                this_legend_string21{num_sites(i)} = '';
                for j = 1:num_grp
                    grp_ind = ((j-1)*num_seq_per_grp+1):j*num_seq_per_grp;
                    grp_loading(i,:,j) = sum(logicals(i,site_idxs{i},grp_ind),3)/num_seq_per_grp;
                end
                for n = 1:num_sites(i)
                    hold on;
                    plot(num_seq_per_grp*[1:num_grp],squeeze(grp_loading(i,n,:)),'.-','Color',ColorSet2(num_sites(i) * (i - 1) + n,:))
                    hold off
                    this_legend_string21{n} = [logical_cond_2str(loading_logical_cond{i}, single_atom_species) ' (site ' int2str(site_idxs{i}(n)) ')'];
                    legend_string21{num_sites(i)*(i-1)+n} = [logical_cond_2str(loading_logical_cond{i}, single_atom_species) ' (site ' int2str(site_idxs{i}(n)) ')'];
                end
            end
            if bLeg
                lgnd21=legend(legend_string21,'Location','eastoutside');
                set(lgnd21,'color','none');
            end

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
            bLeg = figInfo.bLeg(1);
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
            
            if ~iscell(site_idx)
                tmpIdx = cell(num_loading,1);
                for i = 1:num_loading
                    tmpIdx{i} = site_idx;
                end
                site_idx = tmpIdx;
            end
            num_sites = zeros(num_loading,1);
            for i = 1:num_loading
                num_sites(i) = length(site_idx{i});
            end
            
            ColorSet2 = nacstools.display.varycolorrainbow(sum(num_sites));
            %line_specs = {'rs','bs','ms','cs','gs','ys'};
            %ColorSet=nacstools.display.varycolor(num_sites);
            for i = 1:num_loading
                if any(num_sites > 1)
                    param_loads_crop = param_loads(:, site_idx{i}, :);
                    legend_string22{sum(num_sites) + num_loading} = '';
                else
                    param_loads_crop = param_loads;
                    legend_string22{num_loading} = '';
                end
                for j = 1:num_sites(i)
                    if num_params == 1
                        hold on;
                        errorbar(unique_params/plot_scale, squeeze(param_loads_crop(i,j)), abs(param_loads_err(i,j)), 's','Linewidth',0.7);
                        hold off;
                        legend_string22{(i-1)*(num_sites(i) + 1)+j} = [logical_cond_2str(loading_logical_cond{i}, single_atom_species) '(site ' int2str(site_idx{i}(j)) ')'];
                    elseif num_sites == 1
                        errorbar(unique_params/plot_scale, squeeze(param_loads_crop(i,:)), abs(param_loads_err(i,:)), 's','Linewidth',0.7);
                    else
                        hold on;
                        errorbar(unique_params/plot_scale, squeeze(param_loads_crop(i,j,:)), squeeze(param_loads_err(i,j,:)), 's','Color',ColorSet2(num_sites(i) * (i - 1) + j,:),'Linewidth',0.7);
                        hold off
                        legend_string22{(i-1)*(num_sites(i) + 1)+j} = [logical_cond_2str(loading_logical_cond{i}, single_atom_species) '(site ' int2str(site_idx{i}(j)) ')'];
                    end
                end

                if num_sites(i) > 1
                    legend_string22{i*(num_sites(i)+1)} = logical_cond_2str(loading_logical_cond{i}, single_atom_species);
                else
                    legend_string22{i} = logical_cond_2str(loading_logical_cond{i}, single_atom_species);
                end
            end
            if bLeg
                lgnd22=legend(legend_string22,'Location','eastoutside');
                set(lgnd22,'color','none');
            end
            
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
            
            if ~iscell(site_idx)
                tmpIdx = cell(num_survival,1);
                for i = 1:num_survival
                    tmpIdx{i} = site_idx;
                end
                site_idx = tmpIdx;
            end
            
            num_sites = [];
            for i = 1:num_survival
                num_sites(i) = length(site_idx{i});
            end
            
            ColorSet = nacstools.display.varycolorrainbow(max(num_sites));
            ncol = num_survival;
            nrow = 1;
            for n = 1 : num_survival
                if num_sites(n) > 0
                    subplot(nrow, ncol, (nrow-1)*ncol+n); hold on;
                    title({['survive: image ' logical_cond_2str(survival_logical_cond{n}, single_atom_species)], ...
                        ['load: image ' logical_cond_2str(survival_loading_logical_cond{n}, single_atom_species)]})
                  %  line_specs = {'rs-','bs-','ms-','cs-','gs-','ys-'};
                    %legend_string3n1{num_sites+1} = '';
                    legend_string3n1{num_sites(n)} = ''; %if not plotting average
                    for i = 1:num_sites(n)
                     errorbar(unique_params/plot_scale, squeeze(surv_prob{site_idx{n}(i)}(n,:)), ...
                            surv_err{site_idx{n}(i)}(n,:), 'Color', ColorSet(i,:),'Linewidth',1.0);
                        legend_string3n1{i} = ['site #',num2str(site_idx{n}(i))];
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
            nSpecies = size(sData.rearr_success,1);
            subplot_triple = figInfo.subPlotTriple([1 1 1]);
            legend_cell_arr = figInfo.Legend({'Na', 'Cs'});
            subplot(subplot_triple(1), subplot_triple(2), subplot_triple(3))
            plot_scale = figInfo.plot_scale(1);
            param_name_unit = figInfo.param_name_unit('');
            fname = figInfo.fname('');
            hold on;
            rearr_sd = sqrt(sData.rearr_success .* (1 - sData.rearr_success)) ./ sqrt(sData.rearr_n);
            if nSpecies == 1
                errorbar(unique_params/plot_scale, sData.rearr_success, rearr_sd, 'Linewidth', 1.0)
            else
                for i = 1:nSpecies
                    errorbar(unique_params/plot_scale, sData.rearr_success(i,:), rearr_sd(i,:), 'Linewidth', 1.0)
                end
            end
            ylim([0 1])
            if length(unique_params) > 1
                xlim([unique_params(1)- 0.1*(unique_params(end)-unique_params(1)), unique_params(end)+ 0.1*(unique_params(end)-unique_params(1))]/plot_scale);
            end
            legend(legend_cell_arr)
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
            bLeg = figInfo.bLeg(1);
            fig1 = figure(num); 
            if bClear
                clf(fig1);
            end
            plot_scale = figInfo.plot_scale(1);
            param_name_unit = figInfo.param_name_unit('');
            fname = figInfo.fname('');
            AuxPlotIdx = figInfo.AuxPlotIdx(0);
            AuxData = figInfo.AuxData([]);
            AuxPlotInd = figInfo.AuxPlotInd([1,2]);
            
            %Throw out images not being plotted
            ImgPlotInd = figInfo.ImgPlotInd(1:size(param_loads, 1));
            param_loads = param_loads(ImgPlotInd,:,:);
            
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
                if ismember(i,AuxPlotIdx)
                    thisInd = AuxPlotInd(AuxPlotIdx == i);
                    for j = 1:num_params
                        plot(1:num_sites, squeeze(AuxData(thisInd,:,j)) / num_attempts_by_param(j), 'Color', ColorSet(j,:), 'Linewidth', 1.0, 'LineStyle', '--')
                    end
                end
                xlabel('Site index')
                ylabel('Loading rate');
                if bLeg
                    legend(legendstr);
                end
            end
            if isfield(figInfo, 'fname')
                annotation('textbox', [0.1, 0, 0.9, 0.05], 'string', figInfo.fname, 'EdgeColor', 'none', 'Interpreter', 'none')
            end
        end
    end
end