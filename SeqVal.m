%% Copyright (c) 2016-2021, Yichao Yu <yyc1992@gmail.com>
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

classdef SeqVal < handle
    properties(Constant, Hidden)
        OPAdd = int8(1);
        OPSub = int8(2);
        OPMul = int8(3);
        OPDiv = int8(4);
        OPCmpLT = int8(5);
        OPCmpGT = int8(6);
        OPCmpLE = int8(7);
        OPCmpGE = int8(8);
        OPCmpNE = int8(9);
        OPCmpEQ = int8(10);
        OPAnd = int8(11);
        OPOr = int8(12);
        OPXor = int8(13);
        OPNot = int8(14);
        OPAbs = int8(15);
        OPCeil = int8(16);
        OPExp = int8(17);
        OPExpm1 = int8(18);
        OPFloor = int8(19);
        OPLog = int8(20);
        OPLog1p = int8(21);
        OPLog2 = int8(22);
        OPLog10 = int8(23);
        OPPow = int8(24);
        OPSqrt = int8(25);
        OPAsin = int8(26);
        OPAcos = int8(27);
        OPAtan = int8(28);
        OPAtan2 = int8(29);
        OPAsinh = int8(30);
        OPAcosh = int8(31);
        OPAtanh = int8(32);
        OPSin = int8(33);
        OPCos = int8(34);
        OPTan = int8(35);
        OPSinh = int8(36);
        OPCosh = int8(37);
        OPTanh = int8(38);
        OPHypot = int8(39);
        OPErf = int8(40);
        OPErfc = int8(41);
        OPGamma = int8(42);
        OPLgamma = int8(43);
        OPRint = int8(44);
        OPMax = int8(45);
        OPMin = int8(46);
        OPMod = int8(47);
        OPInterp = int8(48);
        OPSelect = int8(49);
        OPIdentity = int8(50);

        ArgConstBool = int8(0);
        ArgConstInt32 = int8(1);
        ArgConstFloat64 = int8(2);
        ArgNode = int8(3);
        ArgMeasure = int8(4);
        ArgGlobal = int8(5);
        ArgArg = int8(6);

        TypeBool = int8(1);
        TypeInt32 = int8(2);
        TypeFloat64 = int8(3);

        % Use values that does not conflict with the opcode
        HMeasure = int8(-1);
        HGlobal = int8(-2);
        HArg = int8(-3);
    end

    properties
        head;
        args;
        ctx;
        node_id = uint32(0); % Serialization ID
    end

    methods
        %%
        function self = SeqVal(head, args, ctx)
            self.head = head;
            self.args = args;
            self.ctx = ctx;
        end
    end
    methods
        % Operations/math functions
        function res = plus(a, b)
            if ~isa(a, 'SeqVal')
                if a == 0
                    res = b;
                else
                    res = SeqVal(SeqVal.OPAdd, {a, b}, b.ctx);
                end
                return;
            elseif ~isa(b, 'SeqVal') && b == 0
                res = a;
                return;
            end
            res = SeqVal(SeqVal.OPAdd, {a, b}, a.ctx);
        end
        function res = minus(a, b)
            if isequal(a, b)
                res = 0;
                return;
            end
            if ~isa(b, 'SeqVal')
                if b == 0
                    res = a;
                else
                    res = SeqVal(SeqVal.OPSub, {a, b}, a.ctx);
                end
                return;
            end
            res = SeqVal(SeqVal.OPSub, {a, b}, b.ctx);
        end
        function res = times(a, b)
            if ~isa(a, 'SeqVal')
                if a == 0
                    res = false;
                elseif a == 1
                    res = b;
                else
                    % b must be a `SeqVal` or we won't be calling this function
                    res = SeqVal(SeqVal.OPMul, {a, b}, b.ctx);
                end
                return;
            elseif ~isa(b, 'SeqVal')
                if b == 0
                    res = false;
                    return;
                elseif b == 1
                    res = a;
                    return;
                end
            end
            % a must be a `SeqVal` or we won't be calling this function
            res = SeqVal(SeqVal.OPMul, {a, b}, a.ctx);
        end
        function res = mtimes(a, b)
            res = a .* b;
        end
        function res = uplus(a)
            res = a;
        end
        function res = uminus(a)
            res = SeqVal(SeqVal.OPMul, {int32(-1), a}, a.ctx);
        end
        function res = rdivide(a, b)
            if ~isa(a, 'SeqVal')
                if a == 0
                    res = false;
                else
                    res = SeqVal(SeqVal.OPDiv, {a, b}, b.ctx);
                end
                return;
            elseif ~isa(b, 'SeqVal') && b == 1
                res = a;
                return;
            end
            res = SeqVal(SeqVal.OPDiv, {a, b}, a.ctx);
        end
        function res = ldivide(b, a)
            res = a ./ b;
        end
        function res = mrdivide(a, b)
            res = a ./ b;
        end
        function res = mldivide(b, a)
            res = a ./ b;
        end
        function res = lt(a, b)
            if isequal(a, b)
                res = false;
                return;
            end
            if isa(a, 'SeqVal')
                ctx = a.ctx;
            else
                ctx = b.ctx;
            end
            res = SeqVal(SeqVal.OPCmpLT, {a, b}, ctx);
        end
        function res = gt(a, b)
            if isequal(a, b)
                res = false;
                return;
            end
            if isa(a, 'SeqVal')
                ctx = a.ctx;
            else
                ctx = b.ctx;
            end
            res = SeqVal(SeqVal.OPCmpGT, {a, b}, ctx);
        end
        function res = le(a, b)
            if isequal(a, b)
                res = true;
                return;
            end
            if isa(a, 'SeqVal')
                ctx = a.ctx;
            else
                ctx = b.ctx;
            end
            res = SeqVal(SeqVal.OPCmpLE, {a, b}, ctx);
        end
        function res = ge(a, b)
            if isequal(a, b)
                res = true;
                return;
            end
            if isa(a, 'SeqVal')
                ctx = a.ctx;
            else
                ctx = b.ctx;
            end
            res = SeqVal(SeqVal.OPCmpGE, {a, b}, ctx);
        end
        function res = ne(a, b)
            if isequal(a, b)
                res = false;
                return;
            end
            if isa(a, 'SeqVal')
                ctx = a.ctx;
            else
                ctx = b.ctx;
            end
            res = SeqVal(SeqVal.OPCmpNE, {a, b}, ctx);
        end
        function res = eq(a, b)
            if isequal(a, b)
                res = true;
                return;
            end
            if isa(a, 'SeqVal')
                ctx = a.ctx;
            else
                ctx = b.ctx;
            end
            res = SeqVal(SeqVal.OPCmpEQ, {a, b}, ctx);
        end
        function res = and(a, b)
            if ~isa(a, 'SeqVal')
                if a
                    res = b;
                else
                    res = false;
                end
                return;
            end
            if ~isa(b, 'SeqVal')
                if b
                    res = a;
                else
                    res = false;
                end
                return;
            end
            if isequal(a, b)
                res = a;
                return;
            end
            res = SeqVal(SeqVal.OPAnd, {a, b}, a.ctx);
        end
        function res = or(a, b)
            if ~isa(a, 'SeqVal')
                if a
                    res = true;
                else
                    res = b;
                end
                return;
            end
            if ~isa(b, 'SeqVal')
                if b
                    res = true;
                else
                    res = a;
                end
                return;
            end
            if isequal(a, b)
                res = a;
                return;
            end
            res = SeqVal(SeqVal.OPOr, {a, b}, a.ctx);
        end
        function res = xor(a, b)
            if ~isa(a, 'SeqVal')
                if a
                    res = not(b);
                else
                    res = b;
                end
                return;
            end
            if ~isa(b, 'SeqVal')
                if b
                    res = not(a);
                else
                    res = a;
                end
                return;
            end
            if isequal(a, b)
                res = false;
                return;
            end
            res = SeqVal(SeqVal.OPXor, {a, b}, a.ctx);
        end
        function res = not(a)
            res = SeqVal(SeqVal.OPNot, {a}, a.ctx);
        end
        function res = abs(a)
            res = SeqVal(SeqVal.OPAbs, {a}, a.ctx);
        end
        function res = ceil(a)
            res = SeqVal(SeqVal.OPCeil, {a}, a.ctx);
        end
        function res = exp(a)
            res = SeqVal(SeqVal.OPExp, {a}, a.ctx);
        end
        function res = expm1(a)
            res = SeqVal(SeqVal.OPExpm1, {a}, a.ctx);
        end
        function res = floor(a)
            res = SeqVal(SeqVal.OPFloor, {a}, a.ctx);
        end
        function res = log(a)
            res = SeqVal(SeqVal.OPLog, {a}, a.ctx);
        end
        function res = log1p(a)
            res = SeqVal(SeqVal.OPLog1p, {a}, a.ctx);
        end
        function res = log2(a)
            res = SeqVal(SeqVal.OPLog2, {a}, a.ctx);
        end
        function res = log10(a)
            res = SeqVal(SeqVal.OPLog10, {a}, a.ctx);
        end
        function res = power(a, b)
            if isa(a, 'SeqVal')
                ctx = a.ctx;
            else
                ctx = b.ctx;
            end
            if ~isa(a, 'SeqVal')
                if a == 1
                    res = a;
                    return;
                end
            elseif ~isa(b, 'SeqVal')
                if b == 0
                    res = int32(1);
                    return;
                elseif b == 1
                    res = a;
                    return;
                elseif b == 2
                    res = SeqVal(SeqVal.OPMul, {a, a}, ctx);
                    return;
                end
            end
            res = SeqVal(SeqVal.OPPow, {a, b}, ctx);
        end
        function res = mpower(a, b)
            res = power(a, b);
        end
        function res = sqrt(a)
            res = SeqVal(SeqVal.OPSqrt, {a}, a.ctx);
        end
        function res = asin(a)
            res = SeqVal(SeqVal.OPAsin, {a}, a.ctx);
        end
        function res = acos(a)
            res = SeqVal(SeqVal.OPAcos, {a}, a.ctx);
        end
        function res = atan(a)
            res = SeqVal(SeqVal.OPAtan, {a}, a.ctx);
        end
        function res = atan2(a, b)
            if isa(a, 'SeqVal')
                ctx = a.ctx;
            else
                ctx = b.ctx;
            end
            res = SeqVal(SeqVal.OPAtan2, {a, b}, ctx);
        end
        function res = acot(a)
            res = atan(1 / a);
        end
        function res = asec(a)
            res = acos(1 / a);
        end
        function res = acsc(a)
            res = asin(1 / a);
        end
        function res = asinh(a)
            res = SeqVal(SeqVal.OPAsinh, {a}, a.ctx);
        end
        function res = acosh(a)
            res = SeqVal(SeqVal.OPAcosh, {a}, a.ctx);
        end
        function res = atanh(a)
            res = SeqVal(SeqVal.OPAtanh, {a}, a.ctx);
        end
        function res = acoth(a)
            res = atanh(1 / a);
        end
        function res = asech(a)
            res = acosh(1 / a);
        end
        function res = acsch(a)
            res = asinh(1 / a);
        end
        function res = sin(a)
            res = SeqVal(SeqVal.OPSin, {a}, a.ctx);
        end
        function res = cos(a)
            res = SeqVal(SeqVal.OPCos, {a}, a.ctx);
        end
        function res = tan(a)
            res = SeqVal(SeqVal.OPTan, {a}, a.ctx);
        end
        function res = cot(a)
            res = 1 / tan(a);
        end
        function res = sec(a)
            res = 1 / cos(a);
        end
        function res = csc(a)
            res = 1 / sin(a);
        end
        function res = sinh(a)
            res = SeqVal(SeqVal.OPSinh, {a}, a.ctx);
        end
        function res = cosh(a)
            res = SeqVal(SeqVal.OPCosh, {a}, a.ctx);
        end
        function res = tanh(a)
            res = SeqVal(SeqVal.OPTanh, {a}, a.ctx);
        end
        function res = coth(a)
            res = 1 / tanh(a);
        end
        function res = sech(a)
            res = 1 / cosh(a);
        end
        function res = csch(a)
            res = 1 / sinh(a);
        end
        function res = hypot(a, b)
            if isa(a, 'SeqVal')
                ctx = a.ctx;
            else
                ctx = b.ctx;
            end
            res = SeqVal(SeqVal.OPHypot, {a, b}, ctx);
        end
        function res = erf(a)
            res = SeqVal(SeqVal.OPErf, {a}, a.ctx);
        end
        function res = erfc(a)
            res = SeqVal(SeqVal.OPErfc, {a}, a.ctx);
        end
        function res = gamma(a)
            res = SeqVal(SeqVal.OPGamma, {a}, a.ctx);
        end
        function res = gammaln(a)
            res = SeqVal(SeqVal.OPLgamma, {a}, a.ctx);
        end
        function res = round(a)
            % Note: this rounding mode is actually slightly different from MATLAB
            if a.head == SeqVal.OPRint
                res = a;
                return;
            end
            res = SeqVal(SeqVal.OPRint, {a}, a.ctx);
        end
        function res = max(a, b)
            if isequal(a, b)
                res = a;
                return;
            end
            if isa(a, 'SeqVal')
                ctx = a.ctx;
            else
                ctx = b.ctx;
            end
            res = SeqVal(SeqVal.OPMax, {a, b}, ctx);
        end
        function res = min(a, b)
            if isequal(a, b)
                res = a;
                return;
            end
            if isa(a, 'SeqVal')
                ctx = a.ctx;
            else
                ctx = b.ctx;
            end
            res = SeqVal(SeqVal.OPMin, {a, b}, ctx);
        end
        function res = rem(a, b)
            if isa(a, 'SeqVal')
                ctx = a.ctx;
            else
                ctx = b.ctx;
            end
            res = SeqVal(SeqVal.OPMod, {a, b}, ctx);
        end
        function res = ifelse(cond, v1, v2)
            if ~isa(cond, 'SeqVal')
                if cond
                    res = v1;
                else
                    res = v2;
                end
                return;
            end
            if isequal(v1, v2)
                res = v1;
                return;
            end
            res = SeqVal(SeqVal.OPSelect, {cond, v1, v2}, cond.ctx);
        end
    end

    methods(Static)
        function res = operator_precedence(head)
            switch head
                case SeqVal.OPAdd
                    res = 3;
                case SeqVal.OPSub
                    res = 3;
                case SeqVal.OPMul
                    res = 2;
                case SeqVal.OPDiv
                    res = 2;
                case SeqVal.OPCmpLT
                    res = 4;
                case SeqVal.OPCmpGT
                    res = 4;
                case SeqVal.OPCmpLE
                    res = 4;
                case SeqVal.OPCmpGE
                    res = 4;
                case SeqVal.OPCmpNE
                    res = 5;
                case SeqVal.OPCmpEQ
                    res = 5;
                case SeqVal.OPAnd
                    res = 6;
                case SeqVal.OPOr
                    res = 8;
                case SeqVal.OPPow
                    res = 7;
                case SeqVal.OPNot
                    res = 1;
                case SeqVal.OPIdentity
                    % Quote identity since I don't really want to scan recursively
                    % Also I don't think it shows up anyway...
                    res = 99;
                otherwise
                    res = 0;
            end
        end

        function res = toStringArg(self, parent_head)
            res = SeqVal.toString(self);
            if ~isa(self, 'SeqVal')
                return;
            end
            op_self = SeqVal.operator_precedence(self.head);
            op_parent = SeqVal.operator_precedence(parent_head);
            if op_self == 0 || op_parent == 0 || op_self < op_parent
                return;
            end
            if op_self > op_parent
                res = ['(' res ')'];
                return;
            end
            if parent_head == SeqVal.OPAdd || parent_head == SeqVal.OPMul
                return;
            end
            res = ['(' res ')'];
        end

        function res = toString(self)
            if ~isa(self, 'SeqVal')
                if islogical(self)
                    if self
                        res = 'true';
                    else
                        res = 'false';
                    end
                elseif isnumeric(self)
                    res = num_to_str(self);
                else
                    error('Unknown value type.');
                end
                return;
            end
            args = self.args;
            if self.head == SeqVal.OPInterp
                args = args(1:3);
            end
            if self.head >= 0
                strargs = cellfun(@(x) {SeqVal.toStringArg(x, self.head)}, args);
            end
            switch self.head
                case SeqVal.OPAdd
                    assert(length(args) == 2);
                    res = [strargs{1} ' + ' strargs{2}];
                case SeqVal.OPSub
                    assert(length(args) == 2);
                    res = [strargs{1} ' - ' strargs{2}];
                case SeqVal.OPMul
                    assert(length(args) == 2);
                    res = [strargs{1} ' * ' strargs{2}];
                case SeqVal.OPDiv
                    assert(length(args) == 2);
                    res = [strargs{1} ' / ' strargs{2}];
                case SeqVal.OPCmpLT
                    assert(length(args) == 2);
                    res = [strargs{1} ' < ' strargs{2}];
                case SeqVal.OPCmpGT
                    assert(length(args) == 2);
                    res = [strargs{1} ' > ' strargs{2}];
                case SeqVal.OPCmpLE
                    assert(length(args) == 2);
                    res = [strargs{1} ' <= ' strargs{2}];
                case SeqVal.OPCmpGE
                    assert(length(args) == 2);
                    res = [strargs{1} ' >= ' strargs{2}];
                case SeqVal.OPCmpNE
                    assert(length(args) == 2);
                    res = [strargs{1} ' ~= ' strargs{2}];
                case SeqVal.OPCmpEQ
                    assert(length(args) == 2);
                    res = [strargs{1} ' == ' strargs{2}];
                case SeqVal.OPAnd
                    assert(length(args) == 2);
                    res = [strargs{1} ' & ' strargs{2}];
                case SeqVal.OPOr
                    assert(length(args) == 2);
                    res = [strargs{1} ' | ' strargs{2}];
                case SeqVal.OPXor
                    assert(length(args) == 2);
                    res = ['xor(' strargs{1} ', ' strargs{2} ')'];
                case SeqVal.OPNot
                    assert(length(args) == 1);
                    res = ['~' strargs{1}];
                case SeqVal.OPAbs
                    assert(length(args) == 1);
                    res = ['abs(' strargs{1} ')'];
                case SeqVal.OPCeil
                    assert(length(args) == 1);
                    res = ['ceil(' strargs{1} ')'];
                case SeqVal.OPExp
                    assert(length(args) == 1);
                    res = ['exp(' strargs{1} ')'];
                case SeqVal.OPExpm1
                    assert(length(args) == 1);
                    res = ['expm1(' strargs{1} ')'];
                case SeqVal.OPFloor
                    assert(length(args) == 1);
                    res = ['floor(' strargs{1} ')'];
                case SeqVal.OPLog
                    assert(length(args) == 1);
                    res = ['log(' strargs{1} ')'];
                case SeqVal.OPLog1p
                    assert(length(args) == 1);
                    res = ['log1p(' strargs{1} ')'];
                case SeqVal.OPLog2
                    assert(length(args) == 1);
                    res = ['log2(' strargs{1} ')'];
                case SeqVal.OPLog10
                    assert(length(args) == 1);
                    res = ['log10(' strargs{1} ')'];
                case SeqVal.OPPow
                    assert(length(args) == 2);
                    res = [strargs{1} ' ^ ' strargs{2}];
                case SeqVal.OPSqrt
                    assert(length(args) == 1);
                    res = ['sqrt(' strargs{1} ')'];
                case SeqVal.OPAsin
                    assert(length(args) == 1);
                    res = ['asin(' strargs{1} ')'];
                case SeqVal.OPAcos
                    assert(length(args) == 1);
                    res = ['acos(' strargs{1} ')'];
                case SeqVal.OPAtan
                    assert(length(args) == 1);
                    res = ['atan(' strargs{1} ')'];
                case SeqVal.OPAtan2
                    assert(length(args) == 2);
                    res = ['atan2(' strargs{1} ', ' strargs{2} ')'];
                case SeqVal.OPAsinh
                    assert(length(args) == 1);
                    res = ['asinh(' strargs{1} ')'];
                case SeqVal.OPAcosh
                    assert(length(args) == 1);
                    res = ['acosh(' strargs{1} ')'];
                case SeqVal.OPAtanh
                    assert(length(args) == 1);
                    res = ['atanh(' strargs{1} ')'];
                case SeqVal.OPSin
                    assert(length(args) == 1);
                    res = ['sin(' strargs{1} ')'];
                case SeqVal.OPCos
                    assert(length(args) == 1);
                    res = ['cos(' strargs{1} ')'];
                case SeqVal.OPTan
                    assert(length(args) == 1);
                    res = ['tan(' strargs{1} ')'];
                case SeqVal.OPSinh
                    assert(length(args) == 1);
                    res = ['sinh(' strargs{1} ')'];
                case SeqVal.OPCosh
                    assert(length(args) == 1);
                    res = ['cosh(' strargs{1} ')'];
                case SeqVal.OPTanh
                    assert(length(args) == 1);
                    res = ['tanh(' strargs{1} ')'];
                case SeqVal.OPHypot
                    assert(length(args) == 2);
                    res = ['hypot(' strargs{1} ', ' strargs{2} ')'];
                case SeqVal.OPErf
                    assert(length(args) == 1);
                    res = ['erf(' strargs{1} ')'];
                case SeqVal.OPErfc
                    assert(length(args) == 1);
                    res = ['erfc(' strargs{1} ')'];
                case SeqVal.OPGamma
                    assert(length(args) == 1);
                    res = ['gamma(' strargs{1} ')'];
                case SeqVal.OPLgamma
                    assert(length(args) == 1);
                    res = ['gammaln(' strargs{1} ')'];
                case SeqVal.OPRint
                    assert(length(args) == 1);
                    res = ['round(' strargs{1} ')'];
                case SeqVal.OPMax
                    assert(length(args) == 2);
                    res = ['max(' strargs{1} ', ' strargs{2} ')'];
                case SeqVal.OPMin
                    assert(length(args) == 2);
                    res = ['min(' strargs{1} ', ' strargs{2} ')'];
                case SeqVal.OPMod
                    assert(length(args) == 2);
                    res = ['rem(' strargs{1} ', ' strargs{2} ')'];
                case SeqVal.OPInterp
                    assert(length(self.args) == 4);
                    res = ['interp(' strargs{1} ', ' strargs{2} ', ' strargs{3} ...
                                     ', ' jsonencode(self.args{4}) ')'];
                case SeqVal.OPSelect
                    assert(length(args) == 3);
                    res = ['ifelse(' strargs{1} ', ' strargs{2}  ', ' strargs{3} ')'];
                case SeqVal.OPIdentity
                    assert(length(args) == 1);
                    res = strargs{1};

                case SeqVal.HMeasure
                    assert(length(args) == 1);
                    res = sprintf('m(%d)', args{1});
                case SeqVal.HGlobal
                    assert(length(args) == 1);
                    res = sprintf('g(%d)', args{1});
                case SeqVal.HArg
                    assert(length(args) == 1);
                    res = sprintf('arg(%d)', args{1});

                otherwise
                    error('Unknown value type');
            end
        end
    end
end
