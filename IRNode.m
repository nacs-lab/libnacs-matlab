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
  properties(Constant, Access=protected)
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
    OPMax = 10;

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
  end
  methods(Static)
    function res=getArg(i)
      res = IRNode(IRNode.HArg, {i});
    end
  end
end
