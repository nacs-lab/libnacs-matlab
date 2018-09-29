%% Copyright (c) 2018-2018, Yichao Yu <yyc1992@gmail.com>
%
% This library is free software; you can redistribute it and/or
% modify it under the terms of the GNU Lesser General Public
% License as published by the Free Software Foundation; either
% version 3.0 of the License, or (at your option) any later version.
% This library is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
% Lesser General Public License for more details.
% You should have received a copy of the GNU Lesser General Public
% License along with this library.

function res = ifelse(cond, v1, v2)
    if isscalar(cond)
        % This case is needed for constant condition when `v1` or `v2` are `IRNode`s
        if cond
            res = v1;
        else
            res = v2;
        end
        return;
    end
    if isa(v1, 'IRNode') || isa(v2, 'IRNode')
        error('Non-scalar condition unsupported for IRNode inputs.');
    end
    res = v2;
    res(cond) = v1(cond);
end
