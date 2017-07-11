%% Copyright (c) 2016-2016, Yichao Yu <yyc1992@gmail.com>
%%
%% This library is free software; you can redistribute it and/or
%% modify it under the terms of the GNU Lesser General Public
%% License as published by the Free Software Foundation; either
%% version 3.0 of the License, or (at your option) any later version.
%% This library is distributed in the hope that it will be useful,
%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
%% Lesser General Public License for more details.
%% You should have received a copy of the GNU Lesser General Public
%% License along with this library.

classdef IRNode < handle
  properties(Constant, Hidden)
    OPMin = 0;
    OPRet = 1;
    OPBr = 2;
    OPAdd = 3;
    OPSub = 4;
    OPMul = 5;
    OPFDiv = 6;
    OPCmp = 7;
    OPPhi = 8;
    OPCall = 9;
    OPInterp = 9;
    OPMax = 11;

    TyMin = 0;
    TyBool = 1;
    TyInt32 = 2;
    TyFloat64 = 3;
    TyMax = 4;
  end

  properties(Constant, Hidden)
    %% f(f)
    FNacos = 0;
    FNacosh = 1;
    FNasin = 2;
    FNasinh = 3;
    FNatan = 4;
    FNatanh = 5;
    FNcbrt = 6;
    FNceil = 7;
    FNcos = 8;
    FNcosh = 9;
    FNerf = 10;
    FNerfc = 11;
    FNexp = 12;
    FNexp10 = 13;
    FNexp2 = 14;
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
    FNpow10 = 26;
    FNrint = 27;
    FNround = 28;
    FNsin = 29;
    FNsinh = 30;
    FNsqrt = 31;
    FNtan = 32;
    FNtanh = 33;
    FNy0 = 34;
    FNy1 = 35;

    %% f(f, f)
    FNatan2 = 36;
    FNcopysign = 37;
    FNfdim = 38;
    FNmax = 39;
    FNmin = 40;
    FNmod = 41;
    FNhypot = 42;
    FNpow = 43;
    FNremainder = 44;

    %% f(f, f, f)
    FNfma = 45;

    %% f(f, i)
    FNldexp = 46;

    %% f(i, f)
    FNjn = 47;
    FNyn = 48;
  end

  properties(Constant)
    HAdd = 0;
    HSub = 1;
    HMul = 2;
    HFDiv = 3;
    HCall = 4;
    HArg = 5;
    HInterp = 5;
  end

  properties
    head;
    args;
  end

  methods
    function self=IRNode(head, args)
      self.head = head;
      self.args = args;
    end
    function res=plus(a, b)
        res = IRNode(IRNode.HAdd, {a, b});
    end
    function res=minus(a, b)
        res = IRNode(IRNode.HSub, {a, b});
    end
    function res=times(a, b)
        res = IRNode(IRNode.HMul, {a, b});
    end
    function res=uplus(a)
        res = a;
    end
    function res=uminus(a)
        res = -1 * a;
    end
    function res=rdivide(a, b)
        res = IRNode(IRNode.HFDiv, {a, b});
    end
    function res=ldivide(b, a)
        res = IRNode(IRNode.HFDiv, {a, b});
    end
    function res=abs(a)
        res = IRNode(IRNode.HCall, {IRNode.FNabs, a});
    end
    function res=exp(a)
        res = IRNode(IRNode.HCall, {IRNode.FNexp, a});
    end
    function res=expm1(a)
        res = IRNode(IRNode.HCall, {IRNode.FNexpm1, a});
    end
    function res=log(a)
        res = IRNode(IRNode.HCall, {IRNode.FNlog, a});
    end
    function res=log1p(a)
        res = IRNode(IRNode.HCall, {IRNode.FNlog1p, a});
    end
    function res=log2(a)
        res = IRNode(IRNode.HCall, {IRNode.FNlog2, a});
    end
    function res=log10(a)
        res = IRNode(IRNode.HCall, {IRNode.FNlog10, a});
    end
    function res=power(a, b)
        res = IRNode(IRNode.HCall, {IRNode.FNpow, a, b});
    end
    function res=sqrt(a)
        res = IRNode(IRNode.HCall, {IRNode.FNsqrt, a});
    end
    function res=asin(a)
        res = IRNode(IRNode.HCall, {IRNode.FNasin, a});
    end
    function res=acos(a)
        res = IRNode(IRNode.HCall, {IRNode.FNacos, a});
    end
    function res=atan(a)
        res = IRNode(IRNode.HCall, {IRNode.FNatan, a});
    end
    function res=atan2(a, b)
        res = IRNode(IRNode.HCall, {IRNode.FNatan2, a, b});
    end
    function res=asinh(a)
        res = IRNode(IRNode.HCall, {IRNode.FNasinh, a});
    end
    function res=acosh(a)
        res = IRNode(IRNode.HCall, {IRNode.FNacosh, a});
    end
    function res=atanh(a)
        res = IRNode(IRNode.HCall, {IRNode.FNatanh, a});
    end
    function res=sin(a)
        res = IRNode(IRNode.HCall, {IRNode.FNsin, a});
    end
    function res=cos(a)
        res = IRNode(IRNode.HCall, {IRNode.FNcos, a});
    end
    function res=tan(a)
        res = IRNode(IRNode.HCall, {IRNode.FNtan, a});
    end
    function res=sinh(a)
        res = IRNode(IRNode.HCall, {IRNode.FNsinh, a});
    end
    function res=cosh(a)
        res = IRNode(IRNode.HCall, {IRNode.FNcosh, a});
    end
    function res=tanh(a)
        res = IRNode(IRNode.HCall, {IRNode.FNtanh, a});
    end
    function res=hypot(a)
        res = IRNode(IRNode.HCall, {IRNode.FNhypot, a});
    end
    function res=erf(a)
        res = IRNode(IRNode.HCall, {IRNode.FNerf, a});
    end
    function res=erfc(a)
        res = IRNode(IRNode.HCall, {IRNode.FNerfc, a});
    end
    function res=gamma(a)
        res = IRNode(IRNode.HCall, {IRNode.FNgamma, a});
    end
    function res=gammaln(a)
        res = IRNode(IRNode.HCall, {IRNode.FNlgamma, a});
    end
    function res=besselj0(a)
        res = IRNode(IRNode.HCall, {IRNode.FNj0, a});
    end
    function res=besselj1(a)
        res = IRNode(IRNode.HCall, {IRNode.FNj1, a});
    end
    function res=bessely0(a)
        res = IRNode(IRNode.HCall, {IRNode.FNy0, a});
    end
    function res=bessely1(a)
        res = IRNode(IRNode.HCall, {IRNode.FNy1, a});
    end
    function res=interpolate(x, x0, x1, vals)
        res = IRNode(IRNode.HInterp, {x, x0, x1, vals});
    end
  end
  methods(Static)
    function res=getArg(i)
      res = IRNode(IRNode.HArg, {i});
    end
  end
end
