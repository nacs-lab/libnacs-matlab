classdef DataProcessTools
   
    methods(Static)
        function res = getCondLogicals(cond, sal, is_rearr, Alg)
            res = struct();
            loading_logical_cond = cond.LoadingLogicals;
            survival_loading_logical_cond = cond.SurvivalLoadingLogicals;
            survival_logical_cond = cond.SurvivalLogicals;
            if is_rearr
                rearr_surv_logical_cond = cond.RearrSurvLoadingLogicals; %Defined in StartScan
            end

            num_sites = size(sal, 2);
            num_seq = size(sal, 3);

            loading_logical = find_logical(loading_logical_cond, sal, num_sites, num_seq);
            if is_rearr
                [rearr_loading_logical, n_loads] = Alg.getRearrangedLogicals(loading_logical);
                res.rearr_loading_logical = rearr_loading_logical;
                res.n_loads = n_loads;
                if min(abs(cell2mat(survival_loading_logical_cond))) > min(abs(cell2mat(rearr_surv_logical_cond)))
                    survival_loading_logical = find_logical(survival_loading_logical_cond, sal, num_sites, num_seq);
                else
                    survival_loading_logical = find_logical(rearr_surv_logical_cond, rearr_loading_logical, num_sites, num_seq); 
                end
            else
                survival_loading_logical = find_logical(survival_loading_logical_cond, sal, num_sites, num_seq);
            end
            survival_logical = find_logical(survival_logical_cond, sal, num_sites, num_seq);

            res.loading_logical = loading_logical;
            if is_rearr
                res.rearr_loading_logical = rearr_loading_logical;
            end
            res.survival_loading_logical = survival_loading_logical;
            res.survival_logical = survival_logical;
        end

        function res = getLoadsByParam(params, logicals)
            % params is a list of params in a group
            num_seq = size(logicals, 3);

            unique_params = unique(params);
            num_params = length(unique_params);
            param_list_all = repmat(params, 1, ceil(num_seq / length(params)));
            num_loading = size(logicals, 1);
            num_sites = size(logicals, 2);
            
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
                    find_param_loads(reshape(permute(logicals(i,:,:), [1,3,2]), 1, numel(logicals(i,:,:))), repmat(param_list_all, [1, num_sites]));
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

        function res = getSurvivalByParam(param_list, survival_loading_logical, survival_logical,site_idxs)
            % param_list is a list of parameters of the same size as the
            % third dimension of survival_loading_logical, survival_logical
            unique_params = unique(param_list);
            num_params = length(unique(param_list));
            num_survival = size(survival_loading_logical, 1);
            num_sites = size(survival_loading_logical, 2);
            
            if nargin < 4
                site_idxs = cell(1,num_survival);
                for i = 1:num_survival
                    site_idxs{i} = 1:num_sites;
                end
            elseif ~iscell(site_idxs)
                tmp_idx = {};
                for i = 1:num_survival
                    tmp_idx{i} = site_idxs;
                end
                site_idxs = tmp_idx;
            end

            p_survival_all(num_survival, num_params) = 0;
            p_survival_err_all(num_survival, num_params) = 0;
            p_survival{num_sites} = [];
            p_survival_err{num_sites} = [];

            for n = 1:num_survival
            % combine different sites
                [p_survival_all(n,:), p_survival_err_all(n,:)] = ...
                    find_survival(reshape(permute(survival_logical(n,site_idxs{n},:), [1,3,2]), 1, numel(survival_logical(n,site_idxs{n},:))),...
                        reshape(permute(survival_loading_logical(n,site_idxs{n},:), [1,3,2]), 1, numel(survival_loading_logical(n,site_idxs{n},:))),...
                        repmat(param_list, 1, num_sites), unique_params, num_params);

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