%% Copyright (c) 2016-2016, Yichao Yu <yyc1992@gmail.com>
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

classdef IRNode < handle
    properties(Constant, Hidden)
        OP_Min = 0;
        OPRet = 1;
        OPBr = 2;
        OPAdd = 3;
        OPSub = 4;
        OPMul = 5;
        OPFDiv = 6;
        OPCmp = 7;
        OPPhi = 8;
        OPCall = 9;
        OPInterp = 10;
        OPConvert = 11;
        OPSelect = 12;
        OPAnd = 13;
        OPOr = 14;
        OPXor = 15;
        OPNot = 16;
        OP_Max = 17;

        TyMin = 0;
        TyBool = 1;
        TyInt32 = 2;
        TyFloat64 = 3;
        TyMax = 4;

        ConstFalse = -1;
        ConstTrue = -2;
    end

    properties(Constant, Hidden)
        %% f(f)
        FNacos = 0;
        FNacosh = 1;
        FNasin = 2;
        FNasinh = 3;
        FNatan = 4;
        FNatanh = 5;
        FNcbrt = 6; % unused
        FNceil = 7;
        FNcos = 8;
        FNcosh = 9;
        FNerf = 10;
        FNerfc = 11;
        FNexp = 12;
        FNexp10 = 13; % unused
        FNexp2 = 14; % unused
        FNexpm1 = 15;
        FNabs = 16;
        FNfloor = 17;
        FNgamma = 18;
        FNj0 = 19;
        FNj1 = 20;
        FNlgamma = 21;
        FNlog = 22;
        FNlog10 = 23;
        FNlog1p = 24;
        FNlog2 = 25;
        % FNpow10 = 26; % deprecated, same as exp10
        FNrint = 27; % unused
        FNround = 28; % TODO?
        FNsin = 29;
        FNsinh = 30;
        FNsqrt = 31;
        FNtan = 32;
        FNtanh = 33;
        FNy0 = 34;
        FNy1 = 35;

        %% f(f, f)
        FNatan2 = 36;
        FNcopysign = 37; % unused
        FNfdim = 38; % unused
        FNmax = 39;
        FNmin = 40;
        FNmod = 41;
        FNhypot = 42;
        FNpow = 43;
        FNremainder = 44; % unused

        % f(f, f, f)
        FNfma = 45; % unused

        % f(f, i)
        FNldexp = 46; % unused

        % f(i, f)
        FNjn = 47;
        FNyn = 48;
    end

    properties(Constant, Hidden)
        % Use a value that does not conflict with the opcode
        HArg = -1;
    end

    properties(Constant, Hidden)
        Cmp_eq = 0;
        Cmp_gt = 1;
        Cmp_ge = 2;
        Cmp_lt = 3;
        Cmp_le = 4;
        Cmp_ne = 5;
    end

    properties
        head;
        args;
        ctx;
        id;
    end

    methods
        %%
        function self = IRNode(head, args, ctx)
            self.head = head;
            self.args = args;
            if exist('ctx', 'var')
                self.ctx = ctx;
            else
                ctx_set = false;
                for arg = args
                    arg = arg{:};
                    if isa(arg, 'IRNode')
                        self.ctx = arg.ctx;
                        ctx_set = true;
                        break;
                    end
                end
                if ~ctx_set
                    error('Cannot determine IRContext from arguments');
                end
            end
            self.id = next_id(self.ctx);
        end
        function res = plus(a, b)
            if ~isa(a, 'IRNode') && a == 0
                res = b;
                return;
            elseif ~isa(b, 'IRNode') && b == 0
                res = a;
                return;
            end
            res = IRNode(IRNode.OPAdd, {a, b});
        end
        function res = minus(a, b)
            if ~isa(b, 'IRNode') && b == 0
                res = a;
                return;
            end
            res = IRNode(IRNode.OPSub, {a, b});
        end
        function res = times(a, b)
            if (~isa(a, 'IRNode') && a == 0) || (~isa(b, 'IRNode') && b == 0)
                res = false;
                return;
            elseif ~isa(a, 'IRNode') && a == 1
                res = b;
                return;
            elseif ~isa(b, 'IRNode') && b == 1
                res = a;
                return;
            end
            res = IRNode(IRNode.OPMul, {a, b});
        end
        function res = uplus(a)
            res = a;
        end
        function res = uminus(a)
            res = int32(-1) .* a;
        end
        function res = rdivide(a, b)
            if ~isa(a, 'IRNode') && a == 0
                res = false;
                return;
            elseif ~isa(b, 'IRNode') && b == 1
                res = a;
                return;
            end
            res = IRNode(IRNode.OPFDiv, {a, b});
        end
        function res = ldivide(b, a)
            res = a / b;
        end
        function res = lt(a, b)
            res = IRNode(IRNode.OPCmp, {IRNode.Cmp_lt, a, b});
        end
        function res = gt(a, b)
            res = IRNode(IRNode.OPCmp, {IRNode.Cmp_gt, a, b});
        end
        function res = le(a, b)
            res = IRNode(IRNode.OPCmp, {IRNode.Cmp_le, a, b});
        end
        function res = ge(a, b)
            res = IRNode(IRNode.OPCmp, {IRNode.Cmp_ge, a, b});
        end
        function res = ne(a, b)
            res = IRNode(IRNode.OPCmp, {IRNode.Cmp_ne, a, b});
        end
        function res = eq(a, b)
            res = IRNode(IRNode.OPCmp, {IRNode.Cmp_eq, a, b});
        end
        function res = and(a, b)
            if ~isa(a, 'IRNode')
                if a
                    res = b;
                else
                    res = false;
                end
                return;
            end
            if ~isa(b, 'IRNode')
                if b
                    res = a;
                else
                    res = false;
                end
                return;
            end
            res = IRNode(IRNode.OPAnd, {a, b});
        end
        function res = or(a, b)
            if ~isa(a, 'IRNode')
                if a
                    res = true;
                else
                    res = b;
                end
                return;
            end
            if ~isa(b, 'IRNode')
                if b
                    res = true;
                else
                    res = a;
                end
                return;
            end
            res = IRNode(IRNode.OPOr, {a, b});
        end
        function res = xor(a, b)
            if ~isa(a, 'IRNode')
                if a
                    res = b;
                else
                    res = not(b);
                end
                return;
            end
            if ~isa(b, 'IRNode')
                if b
                    res = a;
                else
                    res = not(a);
                end
                return;
            end
            res = IRNode(IRNode.OPXor, {a, b});
        end
        function res = not(a)
            res = IRNode(IRNode.OPNot, {a});
        end
        function res = abs(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNabs, a});
        end
        function res = ceil(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNceil, a});
        end
        function res = exp(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNexp, a});
        end
        function res = expm1(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNexpm1, a});
        end
        function res = floor(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNfloor, a});
        end
        function res = log(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNlog, a});
        end
        function res = log1p(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNlog1p, a});
        end
        function res = log2(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNlog2, a});
        end
        function res = log10(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNlog10, a});
        end
        function res = power(a, b)
            res = IRNode(IRNode.OPCall, {IRNode.FNpow, a, b});
        end
        function res = sqrt(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNsqrt, a});
        end
        function res = asin(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNasin, a});
        end
        function res = acos(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNacos, a});
        end
        function res = atan(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNatan, a});
        end
        function res = atan2(a, b)
            res = IRNode(IRNode.OPCall, {IRNode.FNatan2, a, b});
        end
        function res = asinh(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNasinh, a});
        end
        function res = acosh(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNacosh, a});
        end
        function res = atanh(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNatanh, a});
        end
        function res = sin(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNsin, a});
        end
        function res = cos(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNcos, a});
        end
        function res = tan(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNtan, a});
        end
        function res = sinh(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNsinh, a});
        end
        function res = cosh(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNcosh, a});
        end
        function res = tanh(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNtanh, a});
        end
        function res = hypot(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNhypot, a});
        end
        function res = erf(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNerf, a});
        end
        function res = erfc(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNerfc, a});
        end
        function res = gamma(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNgamma, a});
        end
        function res = gammaln(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNlgamma, a});
        end
        function res = besselj0(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNj0, a});
        end
        function res = besselj1(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNj1, a});
        end
        function res = besselj(a, b)
            res = IRNode(IRNode.OPCall, {IRNode.FNjn, a, b});
        end
        function res = bessely0(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNy0, a});
        end
        function res = bessely1(a)
            res = IRNode(IRNode.OPCall, {IRNode.FNy1, a});
        end
        function res = bessely(a, b)
            res = IRNode(IRNode.OPCall, {IRNode.FNyn, a, b});
        end
        function res = max(a, b)
            % Note: this version returns a double for integer/logical input
            %       which is different from the MATLAB behavior
            res = IRNode(IRNode.OPCall, {IRNode.FNmax, a, b});
        end
        function res = min(a, b)
            % Note: this version returns a double for integer/logical input
            %       which is different from the MATLAB behavior
            res = IRNode(IRNode.OPCall, {IRNode.FNmin, a, b});
        end
        function res = rem(a, b)
            res = IRNode(IRNode.OPCall, {IRNode.FNmod, a, b});
        end
        function res = interpolate(x, x0, x1, vals)
            res = IRNode(IRNode.OPInterp, {x, x0, x1 - x0, vals});
        end
        function res = ifelse(cond, v1, v2)
            if ~isa(cond, 'IRNode')
                if cond
                    res = v1;
                else
                    res = v2;
                end
                return;
            end
            res = IRNode(IRNode.OPSelect, {cond, v1, v2});
        end
    end

    methods(Static)
        function res = getArg(i, ctx)
            res = IRNode(IRNode.HArg, {i}, ctx);
        end
    end
end
