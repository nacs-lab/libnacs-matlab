%% Copyright (c) 2018-2021, Yichao Yu <yyc1992@gmail.com>
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
    % Scalar only. This should still work when `v1` or `v2` are `SeqVal`s.
    if length(cond) > 1 && ~isa(cond, 'SeqVal')
        % vectorized implementation. SeqVals return length of 1.
        res = zeros(1, length(cond));
        for i = 1:length(cond)
            if cond(i)
                if length(v1) > 1
                    res(i) = v1(i);
                else
                    res(i) = v1;
                end
            else
                if length(v2) > 1
                    res(i) = v2(i);
                else
                    res(i) = v2;
                end
            end
        end
    else
        if cond
            res = v1;
        else
            res = v2;
        end
    end
end
