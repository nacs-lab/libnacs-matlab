classdef Ops < handle
    methods(Static)
        function res = n(ctx, i)
            res = ctx.Z(i);
        end
        function res = nn(ctx, i, j)
            res = Ops.n(ctx, i) * Ops.n(ctx, j); 
        end
        function res = sigma_bond(ctx, j)
            res = (-1)^(floor(j)) * (Ops.n(ctx, floor(j)) - Ops.n(ctx, ceil(j)));
        end
        function res = sum_sigma_bond(ctx)
            res = 0;
            for i = 1:(ctx.L - 1)
                res = res + Ops.sigma_bond(ctx, i + 0.5);
            end
        end
    end
end