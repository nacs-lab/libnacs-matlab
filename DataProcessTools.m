classdef DataProcessTools
   
    methods(Static)
        function res = getCondLogicals(cond, sal, is_rearr, Alg, new_idx)
            % cond: is a config containing all the logical indicators for
            % what images to use as loading and survival
            % sal: single atom logicals
            % is_rearr: determine if rearrangement (of logicals) is
            % required
            % Alg: option argument for the rearrangement algorithm
            % new_idx: is the start point of new idxs that need to be rearranged. Do not
            % redo work that already was done. 
            if ~exist('new_idx', 'var')
                new_idx = 0;
            end
            res = struct();
            loading_logical_cond = cond.LoadingLogicals;
            survival_loading_logical_cond = cond.SurvivalLoadingLogicals;
            survival_logical_cond = cond.SurvivalLogicals;
            
            num_sites = size(sal, 2);
            num_seq = size(sal, 3);
            % for rearrangement, 
            % RearrLogicals: determines which loading
            % logicals should be rearranged FOR THE PURPOSES of survival
            % calculations and for any rearrangement statistics
            % RearrResult: determines which image is the result for
            % calculating any rearrangement statistics
            if is_rearr
%                 rearr_surv_logical_cond = cond.RearrSurvLoadingLogicals; %Defined in StartScan
                rearr_logical_cond = cond.RearrLogicals;
                rearr_result_cond = cond.RearrResult;
                
                % Rearrange those in cond.RearrLogicals
                [rearr_sal, n_loads] = Alg.getRearrangedLogicals(sal(:,:, (new_idx + 1):end), rearr_logical_cond);
                res.n_loads = n_loads;
                rearr_loading_logical = find_logical(loading_logical_cond, rearr_sal, num_sites, size(rearr_sal, 3));
                rearr_loading_logical = cat(3, zeros(size(rearr_loading_logical, 1), size(rearr_loading_logical, 2), new_idx), rearr_loading_logical);
            
                rearr_source_logical = find_logical(rearr_logical_cond, rearr_sal, num_sites, size(rearr_sal, 3));
                rearr_source_logical = cat(3, zeros(size(rearr_source_logical, 1), size(rearr_source_logical, 2), new_idx), rearr_source_logical);

                rearr_result_logical = find_logical(rearr_result_cond, rearr_sal, num_sites, size(rearr_sal, 3));
                rearr_result_logical = cat(3, zeros(size(rearr_result_logical, 1), size(rearr_result_logical, 2), new_idx), rearr_result_logical);
            end

            % function to convert from condition and sal to actual logicals
            loading_logical = find_logical(loading_logical_cond, sal, num_sites, num_seq);
            if is_rearr
                survival_loading_logical = find_logical(survival_loading_logical_cond, rearr_sal, num_sites, size(rearr_sal, 3));
                survival_loading_logical = cat(3, zeros(size(survival_loading_logical, 1), size(survival_loading_logical, 2), new_idx), survival_loading_logical);
            else
                survival_loading_logical = find_logical(survival_loading_logical_cond, sal, num_sites, num_seq);
            end
            survival_logical = find_logical(survival_logical_cond, sal, num_sites, num_seq);

            res.loading_logical = loading_logical;
            if is_rearr
                res.rearr_loading_logical = rearr_loading_logical;
                res.rearr_source_logical = rearr_source_logical;
                res.rearr_result_logical = rearr_result_logical;
            end
            res.survival_loading_logical = survival_loading_logical;
            res.survival_logical = survival_logical;
        end

        function res = getLoadsByParam(params, logicals, sites_to_avg)
            % params is a list of params in a group
            num_seq = size(logicals, 3);

            unique_params = unique(params);
            num_params = length(unique_params);
            param_list_all = repmat(params, 1, ceil(num_seq / length(params)));
            num_loading = size(logicals, 1);
            num_sites = size(logicals, 2);
            if ~exist('sites_to_avg', 'var')
                sites_to_avg = 1:num_sites;
            end
            
            if ~iscell(sites_to_avg)
                tmpIdx = cell(num_loading,1);
                for i = 1:num_loading
                    tmpIdx{i} = sites_to_avg;
                end
                sites_to_avg = tmpIdx;
            end
            
            param_loads(num_loading, num_sites, num_params) = 0;
            param_loads_err(num_loading, num_sites, num_params) = 0;
            param_loads_all(num_loading, num_params) = 0;
            param_loads_err_all(num_loading, num_params) = 0;
            param_loads_prob(num_loading, num_sites, num_params) = 0;
            param_loads_err_prob(num_loading, num_sites, num_params) = 0;
            param_loads_all_prob(num_loading, num_params) = 0;
            param_loads_err_all_prob(num_loading, num_params) = 0;
            
            for i = 1:num_loading
                for j = 1:num_sites
                    [param_loads(i,j,:), param_loads_err(i,j,:), param_loads_prob(i,j,:), param_loads_err_prob(i,j,:), num_attempts] = find_param_loads(logicals(i, j, :), param_list_all);
                end
                [param_loads_all(i,:), param_loads_err_all(i,:), param_loads_all_prob(i,:), param_loads_err_all_prob(i,:)] = ...
                    find_param_loads(reshape(permute(logicals(i,sites_to_avg{i},:), [1,3,2]), 1, numel(logicals(i,sites_to_avg{i},:))), repmat(param_list_all, [1, length(sites_to_avg{i})]));
            end
            res = struct();
            res.param_loads = param_loads;
            res.param_loads_err = param_loads_err;
            res.param_loads_all = param_loads_all;
            res.param_loads_err_all = param_loads_err_all;
            res.param_loads_prob = param_loads_prob;
            res.param_loads_err_prob = param_loads_err_prob;
            res.param_loads_all_prob = param_loads_all_prob;
            res.param_loads_err_all_prob = param_loads_err_all_prob;
            res.num_attempts_by_param = num_attempts;
        end

        function res = getSurvivalByParam(param_list, survival_loading_logical, survival_logical, sites_to_avg)
            % param_list is a list of parameters of the same size as the
            % third dimension of survival_loading_logical, survival_logical
            unique_params = unique(param_list);
            num_params = length(unique(param_list));
            num_survival = size(survival_loading_logical, 1);
            num_sites = size(survival_loading_logical, 2);
            
            if ~exist('sites_to_avg', 'var')
                sites_to_avg = 1:num_sites;
            end
            
            if ~iscell(sites_to_avg)
                tmpIdx = cell(num_survival,1);
                for i = 1:num_survival
                    tmpIdx{i} = sites_to_avg;
                end
                sites_to_avg = tmpIdx;
            end

            p_survival_all(num_survival, num_params) = 0;
            p_survival_err_all(num_survival, num_params) = 0;
            p_survival{num_sites} = [];
            p_survival_err{num_sites} = [];

            for n = 1:num_survival
            % combine different sites
                [p_survival_all(n,:), p_survival_err_all(n,:)] = ...
                    find_survival(reshape(permute(survival_logical(n,sites_to_avg{n},:), [1,3,2]), 1, numel(survival_logical(n,sites_to_avg{n},:))),...
                        reshape(permute(survival_loading_logical(n,sites_to_avg{n},:), [1,3,2]), 1, numel(survival_loading_logical(n,sites_to_avg{n},:))),...
                        repmat(param_list, 1, length(sites_to_avg{n})), unique_params, num_params);

                if num_sites > 0
                    for i = 1:num_sites
                        this_p_surv = p_survival{i};
                        this_p_surv_err = p_survival_err{i};
                        [this_surv, this_surv_err] = find_survival(survival_logical(n,i,:), ...
                            survival_loading_logical(n,i,:), param_list, unique_params, num_params);
                        this_p_surv(end + 1, :) = this_surv;
                        this_p_surv_err(end + 1, :) = this_surv_err;
                        p_survival{i} = this_p_surv;
                        p_survival_err{i} = this_p_surv_err;
                    end
                end
            end
            res = struct();
            res.p_survival_all = p_survival_all;
            res.p_survival_err_all = p_survival_err_all;
            res.p_survival = p_survival;
            res.p_survival_err = p_survival_err;
        end
    end
    
end