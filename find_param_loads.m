%% find loads as a function of unique parameters
function [param_loads, param_loads_err, param_loading, param_loading_err, num_attempts] = ...
    find_param_loads(logical, param_list, num_attempts)
% param_list should be a param_list that includes all possible parameters.
unique_params = unique(param_list);

loads_ind = find(logical)';

d = diff(unique_params) / 2;
if length(unique_params) > 1
    edges = [unique_params(1)-d(1),unique_params(1:end-1)+d, unique_params(end)+d(end)];
else
    edges = 1;
end
% if num_attempts exist, use it, otherwise compute it from param_list
if ~exist('num_attempts', 'var')
    if length(logical) ~= length(param_list)
        param_list = param_list(1:length(logical));
    end
    num_attempts = histcounts(param_list, edges);
end

param_loads = histcounts(param_list(loads_ind), edges);
param_loading = param_loads ./ (num_attempts);
param_loading_err = sqrt(param_loading .* (1-param_loading));
% resolve NaN in case no attempts were made
param_loading(isnan(param_loading)) = 0;
param_loads_err = num_attempts .* sqrt(param_loading.*(1-param_loading)./(num_attempts));
param_loads_err(isnan(param_loads_err)) = 0;



end

