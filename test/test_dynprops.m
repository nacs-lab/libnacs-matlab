%% Copyright (c) 2018-2018, Yichao Yu <yyc1992@gmail.com>
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

function test_dynprops()
    s.A = 1;
    s.B = 2;
    s.C.B = 3;

    %% Default constructor and constructor with pre-populated values
    dp0 = DynProps();
    dp1 = DynProps(s);

    %% Pre-populated values
    assert(dp1.A == 1);
    assert(dp1.B == 2);
    assert(dp1.C.B == 3);

    %% Simple default values
    assert(dp0.A(1) == 1);
    assert(dp0.B(2) == 2);

    %% Struct assignments
    dp0.C = struct('A', 1, 'B', 2);
    assert(dp0.C.A == 1);
    assert(dp0.C.B == 2);
    assert(isequaln(dp0.C(), struct('A', 1, 'B', 2)));
    d0c = dp0.C(struct('C', 3));
    assert(d0c.C == 3);
    assert(isequaln(d0c, struct('A', 1, 'B', 2, 'C', 3)));
    assert(isequaln(dp0.C(), struct('A', 1, 'B', 2, 'C', 3)));
    d0c2 = dp0.C(struct('D', 4));
    assert(isfield(d0c, 'C'));
    assert(~isfield(d0c, 'D'));
    assert(isfield(d0c2, 'C'));
    assert(isfield(d0c2, 'D'));
    assert(d0c2.D == 4);
    assert(isequaln(d0c2, struct('A', 1, 'B', 2, 'C', 3, 'D', 4)));
    assert(isequaln(dp0.C(), struct('A', 1, 'B', 2, 'C', 3, 'D', 4)));

    %% Create new nested field
    dp1.D.E.F = 3;
    assert(dp1.D.E.F == 3);

    %% Create new nested field with default value
    assert(dp0.D.E.F.G(4) == 4);
    assert(dp0.D.E.F.G == 4);

    %% Assign to single array element
    dp0.A(3) = 2;
    assert(all(dp0.A == [1, 0, 2]));

    %% Reference to subfield.
    c0 = dp0.C;
    assert(c0.A == 1);
    assert(c0.B == 2);
    assert(c0.A(3) == 1);
    assert(c0.C(3) == 3);
    assert(c0.C == 3);
    c0.D = 4;
    assert(c0.D(3) == 4);
    assert(c0.D == 4);
    c0.A = 2;
    assert(c0.A == 2);

    %% Make sure mutation to the subfield reference is reflected on the original one.
    assert(dp0.C.A == 2);
    assert(dp0.C.B == 2);
    assert(dp0.C.C == 3);
    assert(dp0.C.D == 4);

    c0.A = NaN;
    assert(c0.A(1) == 1);
    assert(c0.A() == 1);
    assert(c0.A == 1);
end
