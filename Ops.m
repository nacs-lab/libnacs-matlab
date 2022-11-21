classdef Ops < handle
    methods(Static)
        function res = n(ctx, i)
            % evaluates logical(i) on site i
            res = ctx.Z(i);
        end
        function res = nn(ctx, i, j)
            % evaluates logical(i) * logical(j) on sites i,j
            res = Ops.n(ctx, i) * Ops.n(ctx, j); 
        end
        function res = sigma_bond(ctx, j)
            % j = j_0 + 0.5, should be on a bond not on a site
            % evalutes (-1)^(j_0) * (n_{j_0} - n_{j_0 + 1})
            res = (-1)^(floor(j)) * (Ops.n(ctx, floor(j)) - Ops.n(ctx, ceil(j)));
        end
        function res = sigma_bond_with_idxs(ctx, parity, i, j)
            % (-1)^{parity} (n_i - n_j)
            res = (-1)^(parity) * (Ops.n(ctx, i) - Ops.n(ctx, j));
        end
        function res = sum_sigma_bond(ctx)
            % sum of sigma_bond for all j. 
            res = 0;
            for i = 1:(ctx.L - 1)
                res = res + Ops.sigma_bond(ctx, i + 0.5);
            end
        end
        function res = sum_sigma_bond_with_idxs(ctx, idxs)
            % sum of sigma bond for certain idxs with alternating parity.
            res = 0;
            for i = 1:(length(idxs) - 1)
                res = res + Ops.sigma_bond_with_idxs(ctx, i, idxs(i), idxs(i + 1));
            end
        end
        function res = stag_magnetization(ctx, idxs)
            % sum_i (-1)^i (n_i - 1/2)
            % note 0 for cat state, and 1 for AFM
            N = length(idxs);
            res = 0;
            for i = 1:N
                res = res + (-1)^i * (Ops.n(ctx, idxs(i)) - 1/2) / N;
            end
        end
        function res = sigma_field_open(ctx, idx)
            res = (-1)^(idx) * (Ops.n(ctx, idx) - Ops.n(ctx, idx + 1));
        end
        function res = sigma_field_open_ij(ctx, i, j)
            res = Ops.sigma_field_open(ctx, i) * Ops.sigma_field_open(ctx, j);
        end
    end
end