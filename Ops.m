classdef Ops < handle
    methods(Static)
        function res = n(ctx, i)
            res = ctx.Z(i);
        end
        function res = avg_n(ctx, site_nums)
            res = 0;
            for i = 1:length(site_nums)
                res = res + Ops.n(ctx, site_nums(i));
            end
            res = res / length(site_nums);
        end
        function res = nn(ctx, i, j)
            res = Ops.n(ctx, i) * Ops.n(ctx, j); 
        end
        function res = sigma_bond(ctx, j)
            res = (-1)^(floor(j)) * (Ops.n(ctx, floor(j)) - Ops.n(ctx, ceil(j)));
        end
        function res = sigma_bond_with_idxs(ctx, parity, i, j)
            res = (-1)^(parity) * (Ops.n(ctx, i) - Ops.n(ctx, j));
        end
        function res = sum_sigma_bond(ctx)
            res = 0;
            for i = 1:(ctx.L - 1)
                res = res + Ops.sigma_bond(ctx, i + 0.5);
            end
        end
        function res = sum_sigma_bond_with_idxs(ctx, idxs)
            res = 0;
            for i = 1:(length(idxs) - 1)
                res = res + Ops.sigma_bond_with_idxs(ctx, i, idxs(i), idxs(i + 1));
            end
        end
        function res = stag_magnetization(ctx, idxs)
            N = length(idxs);
            res = 0;
            for i = 1:N
                res = res + (-1)^i * (Ops.n(ctx, idxs(i)) - 1/2) / N;
            end
        end
    end
end