classdef FnOps < handle
    methods(Static)
        function res = n(i)
            % evaluates logical(i) on site i
            function result = fn(logs)
                result = ~logs(i);
            end
            res = @fn;
        end
        function res = avg_n(site_nums)
            % evaluates avg_n
            function result = fn(logs)
                result = sum(~logs(site_nums)) / length(site_nums);
            end
            res = @fn;
        end
        function res = nn(i, j)
            % evaluates logical(i) * logical(j) on sites i,j
            function result = fn(logs)
                result = ~logs(i) * ~logs(j);
            end
            res = @fn;
        end
        function res = sigma_bond(j)
            % j = j_0 + 0.5, should be on a bond not on a site
            % evalutes (-1)^(j_0) * (n_{j_0} - n_{j_0 + 1})
            function result = fn(logs)
                result = (-1)^(floor(j)) * (~logs(floor(j)) - ~logs(ceil(j)));
            end
            res = @fn;
%             res = (-1)^(floor(j)) * (Ops.n(ctx, floor(j)) - Ops.n(ctx, ceil(j)));
        end
        function res = sigma_bond_with_idxs(parity, i, j)
            % (-1)^{parity} (n_i - n_j)
            function result = fn(logs)
                result = (-1)^(parity) * (~logs(i) - ~logs(j));
            end
            res = @fn;
%             res = (-1)^(parity) * (Ops.n(ctx, i) - Ops.n(ctx, j));
        end
        function res = sum_sigma_bond()
            % sum of sigma_bond for all j.
            function result = fn(logs)
                result = 0;
                for i = 1:(length(logs) - 1)
                    this_fn = FnOps.sigma_bond(i + 0.5);
                    result = result + this_fn(logs);
                end
            end
            res = @fn;
%             res = 0;
%             for i = 1:(ctx.L - 1)
%                 res = res + Ops.sigma_bond(ctx, i + 0.5);
%             end
        end
        function res = sum_sigma_bond_with_idxs(idxs)
            % sum of sigma bond for certain idxs with alternating parity.
            function result = fn(logs)
                result = 0;
                for i = 1:(length(idxs) - 1)
                    this_fn = FnOps.sigma_bond_with_idxs(i, idxs(i), idxs(i+1));
                    result = result + this_fn(logs);
                end
            end
            res = @fn;
%             res = 0;
%             for i = 1:(length(idxs) - 1)
%                 res = res + Ops.sigma_bond_with_idxs(ctx, i, idxs(i), idxs(i + 1));
%             end
        end
        function res = stag_magnetization(idxs)
            % sum_i (-1)^i (n_i - 1/2)
            % note 0 for cat state, and 1 for AFM
            function result = fn(logs)
                N = length(idxs);
                result = 0;
                for i = 1:N
                    result = result + (-1)^i * (~logs(i) - 1/2) / N;
                end
            end
            res = @fn;
%             N = length(idxs);
%             res = 0;
%             for i = 1:N
%                 res = res + (-1)^i * (Ops.n(ctx, idxs(i)) - 1/2) / N;
%             end
        end
        function res = sigma_field_open(idx)
            function result = fn(logs)
                result = (-1)^(idx) * (~logs(idx) - ~logs(idx + 1));
            end
            res = @fn;
%             res = (-1)^(idx) * (Ops.n(ctx, idx) - Ops.n(ctx, idx + 1));
        end
        function res = sigma_field_open_ij(i, j)
            function result = fn(logs)
                fn1 = FnOps.sigma_field_open(i);
                fn2 = FnOps.sigma_field_open(j);
                result = fn1(logs) * fn2(logs);
            end
            res = @fn;
%             res = Ops.sigma_field_open(ctx, i) * Ops.sigma_field_open(ctx, j);
        end
        function res = sigma_field_close(idx, C)
            function result = fn(logs)
                result = (-1)^(idx) * (~logs(idx) - C);
            end
            res = @fn;
%             res = (-1)^(idx) * (Ops.n(ctx, idx) - C);
        end
        function res = sigma_field_close_ij(i, j, C)
            function result = fn(logs)
%                 fn1 = FnOps.sigma_field_close(i, C);
%                 fn2 = FnOps.sigma_field_close(j, C);
%                 result = fn1(logs) * fn2(logs);
                result = (-1)^(i + j) * (~logs(i) - C) * (~logs(j) - C);
            end
            res = @fn;
        end
        function res = HRyd1D(det, V, periodic, site_idxs)
            % nearest neighbor only and in the Z basis
            if ~exist('periodic', 'var')
                periodic = 0;
            end
            function result = fn(logs)
                if ~exist('site_idxs', 'var')
                    site_idxs = 1:length(logs);
                end
                ryd_logs = ~logs(site_idxs);
                if periodic
                    shifted_logs = [ryd_logs(end), ryd_logs(1:(end - 1))];
                else
                    shifted_logs = [0, ryd_logs(1:(end - 1))];
                end
                result =  -det * sum(ryd_logs) + dot(double(ryd_logs), shifted_logs) * V;
            end
            res = @fn;
%             res = 0;
%             for i = 1:(ctx.L)
%                 res = res - det * Ops.n(ctx, i);
%                 if i ~= ctx.L
%                     res = res + V * Ops.n(ctx, i) * Ops.n(ctx, i + 1);
%                 else
%                     if periodic
%                         res = res + V * Ops.n(ctx, ctx.L) * Ops.n(ctx, 1);
%                     end
%                 end
%             end
        end
    end
end