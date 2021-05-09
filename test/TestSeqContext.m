%% Copyright (c) 2021-2021, Yichao Yu <yyc1992@gmail.com>
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

classdef TestSeqContext < matlab.unittest.TestCase
    %% Test Method Block
    methods(Test)
        function dotest(test)
            ctx = SeqContext();

            % Creating argument nodes
            arg0 = ctx.getArg(0);
            arg1 = ctx.getArg(1);
            arg10 = ctx.getArg(10);
            test.verifyEqual(arg0.head, SeqVal.HArg);
            test.verifyEqual(arg0.args, {0});
            test.verifyEqual(arg1.head, SeqVal.HArg);
            test.verifyEqual(arg1.args, {1});
            test.verifyEqual(arg10.head, SeqVal.HArg);
            test.verifyEqual(arg10.args, {10});
            test.verifyEqual(arg0, ctx.getArg(0));
            test.verifyEqual(arg1, ctx.getArg(1));
            test.verifyEqual(arg10, ctx.getArg(10));
            test.verifyEqual(arg0, ctx.arg0);
            test.verifyEqual(arg1, ctx.arg1);
            test.verifyEqual(SeqVal.toString(arg0), 'arg(0)');
            test.verifyEqual(SeqVal.toString(arg1), 'arg(1)');

            % Creating measure nodes
            [m0, m0id] = ctx.newMeasure();
            test.verifyEqual(m0id, uint32(0));
            test.verifyEqual(m0.head, SeqVal.HMeasure);
            test.verifyEqual(length(m0.args), 1);
            test.verifyEqual(m0.args{1}, uint32(0));
            test.verifyEqual(SeqVal.toString(m0), 'm(0)');
            [m1, m1id] = ctx.newMeasure();
            test.verifyEqual(m1id, uint32(1));
            test.verifyEqual(m1.head, SeqVal.HMeasure);
            test.verifyEqual(length(m1.args), 1);
            test.verifyEqual(m1.args{1}, uint32(1));
            test.verifyEqual(SeqVal.toString(m1), 'm(1)');

            % Creating global nodes
            [g0, g0id] = ctx.newGlobal(SeqVal.TypeBool);
            test.verifyEqual(g0id, 0);
            test.verifyEqual(g0.head, SeqVal.HGlobal);
            test.verifyEqual(length(g0.args), 1);
            test.verifyEqual(g0.args{1}, 0);
            test.verifyEqual(SeqVal.toString(g0), 'g(0)');
            [g1, g1id] = ctx.newGlobal(SeqVal.TypeFloat64);
            test.verifyEqual(g1id, 1);
            test.verifyEqual(g1.head, SeqVal.HGlobal);
            test.verifyEqual(length(g1.args), 1);
            test.verifyEqual(g1.args{1}, 1);
            test.verifyEqual(SeqVal.toString(g1), 'g(1)');

            % Expressions
            e1 = arg0 + arg1;
            test.verifyEqual(e1.head, SeqVal.OPAdd);
            test.verifyEqual(length(e1.args), 2);
            test.verifyEqual(e1.args{1}, arg0);
            test.verifyEqual(e1.args{2}, arg1);
            test.verifyEqual(SeqVal.toString(e1), 'arg(0) + arg(1)');

            e2 = g0 .* m1;
            test.verifyEqual(e2.head, SeqVal.OPMul);
            test.verifyEqual(length(e2.args), 2);
            test.verifyEqual(e2.args{1}, g0);
            test.verifyEqual(e2.args{2}, m1);
            test.verifyEqual(SeqVal.toString(e2), 'g(0) * m(1)');

            e3 = arg0 / m0;
            test.verifyEqual(e3.head, SeqVal.OPDiv);
            test.verifyEqual(length(e3.args), 2);
            test.verifyEqual(e3.args{1}, arg0);
            test.verifyEqual(e3.args{2}, m0);
            test.verifyEqual(SeqVal.toString(e3), 'arg(0) / m(0)');

            e5 = interpolate(arg0, e2, e3, [1, 2, 7, 3, 4, 5]);
            test.verifyEqual(e5.head, SeqVal.OPInterp);
            test.verifyEqual(length(e5.args), 4);
            test.verifyEqual(e5.args{1}, arg0);
            test.verifyEqual(e5.args{2}, e2);
            e4 = e5.args{3};
            test.verifyEqual(e4.head, SeqVal.OPSub);
            test.verifyEqual(length(e4.args), 2);
            test.verifyEqual(e4.args{1}, e3);
            test.verifyEqual(e4.args{2}, e2);
            test.verifyClass(e5.args{4}, 'double');;
            test.verifyEqual(e5.args{4}, [1, 2, 7, 3, 4, 5]);
            test.verifyEqual(SeqVal.toString(e4), 'arg(0) / m(0) - g(0) * m(1)');
            test.verifyEqual(SeqVal.toString(e5), ...
                             'interp(arg(0), g(0) * m(1), arg(0) / m(0) - g(0) * m(1), [1,2,7,3,4,5])');

            e6 = hypot(4.5, e5);
            test.verifyEqual(e6.head, SeqVal.OPHypot);
            test.verifyEqual(length(e6.args), 2);
            test.verifyEqual(e6.args{1}, 4.5);
            test.verifyEqual(e6.args{2}, e5);
            test.verifyEqual(SeqVal.toString(e6), ...
                          'hypot(4.5, interp(arg(0), g(0) * m(1), arg(0) / m(0) - g(0) * m(1), [1,2,7,3,4,5]))');

            e8 = interpolate(arg0, arg1, g0, [1, 2, 7, 3, 4, 5]);
            test.verifyEqual(e8.head, SeqVal.OPInterp);
            test.verifyEqual(length(e8.args), 4);
            test.verifyEqual(e8.args{1}, arg0);
            test.verifyEqual(e8.args{2}, arg1);
            e7 = e8.args{3};
            test.verifyEqual(e7.head, SeqVal.OPSub);
            test.verifyEqual(length(e7.args), 2);
            test.verifyEqual(e7.args{1}, g0);
            test.verifyEqual(e7.args{2}, arg1);
            test.verifyClass(e8.args{4}, 'double');;
            test.verifyEqual(e8.args{4}, [1, 2, 7, 3, 4, 5]);
            test.verifyEqual(SeqVal.toString(e7), 'g(0) - arg(1)');
            test.verifyEqual(SeqVal.toString(e8), ...
                             'interp(arg(0), arg(1), g(0) - arg(1), [1,2,7,3,4,5])');

            e10 = interpolate(arg0, arg1, g0, [1, 2, 3, 4, 5]);
            test.verifyEqual(e10.head, SeqVal.OPInterp);
            test.verifyEqual(length(e10.args), 4);
            test.verifyEqual(e10.args{1}, arg0);
            test.verifyEqual(e10.args{2}, arg1);
            e9 = e10.args{3};
            test.verifyEqual(e9.head, SeqVal.OPSub);
            test.verifyEqual(length(e9.args), 2);
            test.verifyEqual(e9.args{1}, g0);
            test.verifyEqual(e9.args{2}, arg1);
            test.verifyClass(e10.args{4}, 'double');;
            test.verifyEqual(e10.args{4}, [1, 2, 3, 4, 5]);
            test.verifyEqual(SeqVal.toString(e9), 'g(0) - arg(1)');
            test.verifyEqual(SeqVal.toString(e10), ...
                             'interp(arg(0), arg(1), g(0) - arg(1), [1,2,3,4,5])');

            c0 = ctx.getValID(1.3);
            test.verifyEqual(c0, uint32(1));
            test.verifyEqual(ctx.getValID(1.3), uint32(1));
            c1 = ctx.getValID(true);
            test.verifyEqual(c1, uint32(2));
            test.verifyEqual(ctx.getValID(true), uint32(2));
            c2 = ctx.getValID(int8(23));
            test.verifyEqual(c2, uint32(3));
            test.verifyEqual(ctx.getValID(int16(23)), uint32(3));

            n0 = ctx.getValID(e6);
            test.verifyEqual(n0, uint32(8));
            test.verifyEqual(ctx.getValID(e2), uint32(4));
            test.verifyEqual(ctx.getValID(e3), uint32(5));
            test.verifyEqual(ctx.getValID(e4), uint32(6));
            test.verifyEqual(ctx.getValID(e5), uint32(7));
            n1 = ctx.getValID(e10);
            test.verifyEqual(n1, uint32(10));
            n2 = ctx.getValID(e8);
            test.verifyEqual(n2, uint32(12));

            na0 = ctx.getValID(arg0);
            test.verifyEqual(na0, uint32(13));
            test.verifyEqual(ctx.getValID(arg0), na0);

            nm1 = ctx.getValID(m1);
            test.verifyEqual(nm1, uint32(14));
            test.verifyEqual(ctx.getValID(m1), nm1);

            ng0 = ctx.getValID(g0);
            test.verifyEqual(ng0, uint32(15));
            test.verifyEqual(ctx.getValID(g0), ng0);

            test.verifyEqual(ctx.nodeSerialized(), ...
                             [typecast(int32(15), 'int8'), ...
                              int8(SeqVal.OPIdentity), ... % 1: 1.3
                              int8(SeqVal.ArgConstFloat64), typecast(1.3, 'int8'), ...
                              int8(SeqVal.OPIdentity), ... % 2: true
                              int8(SeqVal.ArgConstBool), int8(1), ...
                              int8(SeqVal.OPIdentity), ... % 3: int32(23)
                              int8(SeqVal.ArgConstInt32), typecast(int32(23), 'int8'), ...
                              int8(SeqVal.OPMul), ... % 4: e2 = g0 * m1
                              int8(SeqVal.ArgGlobal), typecast(int32(0), 'int8'), ...
                              int8(SeqVal.ArgMeasure), typecast(int32(1), 'int8'), ...
                              int8(SeqVal.OPDiv), ... % 5: e3 = arg0 / m0
                              int8(SeqVal.ArgArg), typecast(int32(0), 'int8'), ...
                              int8(SeqVal.ArgMeasure), typecast(int32(0), 'int8'), ...
                              int8(SeqVal.OPSub), ... % 6: e4 = e3 - e2
                              int8(SeqVal.ArgNode), typecast(int32(5), 'int8'), ...
                              int8(SeqVal.ArgNode), typecast(int32(4), 'int8'), ...
                              int8(SeqVal.OPInterp), ... % 7: e5 = interp(arg0, e2, e4, data0)
                              int8(SeqVal.ArgArg), typecast(int32(0), 'int8'), ...
                              int8(SeqVal.ArgNode), typecast(int32(4), 'int8'), ...
                              int8(SeqVal.ArgNode), typecast(int32(6), 'int8'), ...
                              typecast(int32(0), 'int8'), ...
                              int8(SeqVal.OPHypot), ... % 8: e6 = hypot(4.5, e5)
                              int8(SeqVal.ArgConstFloat64), typecast(4.5, 'int8'), ...
                              int8(SeqVal.ArgNode), typecast(int32(7), 'int8'), ...
                              int8(SeqVal.OPSub), ... % 9: e9 = g0 - arg1
                              int8(SeqVal.ArgGlobal), typecast(int32(0), 'int8'), ...
                              int8(SeqVal.ArgArg), typecast(int32(1), 'int8'), ...
                              int8(SeqVal.OPInterp), ... % 10: e10 = interp(arg0, arg1, e9, data1)
                              int8(SeqVal.ArgArg), typecast(int32(0), 'int8'), ...
                              int8(SeqVal.ArgArg), typecast(int32(1), 'int8'), ...
                              int8(SeqVal.ArgNode), typecast(int32(9), 'int8'), ...
                              typecast(int32(1), 'int8'), ...
                              int8(SeqVal.OPSub), ... % 11: e7 = g0 - arg1
                              int8(SeqVal.ArgGlobal), typecast(int32(0), 'int8'), ...
                              int8(SeqVal.ArgArg), typecast(int32(1), 'int8'), ...
                              int8(SeqVal.OPInterp), ... % 12: e8 = interp(arg0, arg1, e7, data1)
                              int8(SeqVal.ArgArg), typecast(int32(0), 'int8'), ...
                              int8(SeqVal.ArgArg), typecast(int32(1), 'int8'), ...
                              int8(SeqVal.ArgNode), typecast(int32(11), 'int8'), ...
                              typecast(int32(0), 'int8'), ...
                              int8(SeqVal.OPIdentity), ... % 13: arg0
                              int8(SeqVal.ArgArg), typecast(int32(0), 'int8'), ...
                              int8(SeqVal.OPIdentity), ... % 14: m1
                              int8(SeqVal.ArgMeasure), typecast(int32(1), 'int8'), ...
                              int8(SeqVal.OPIdentity), ... % 15: g0
                              int8(SeqVal.ArgGlobal), typecast(int32(0), 'int8'), ...
                             ]);
            test.verifyEqual(ctx.dataSerialized(), ...
                             [typecast(int32(2), 'int8'), ...
                              typecast(int32(6), 'int8'), ...
                              typecast([1, 2, 7, 3, 4, 5], 'int8'), ...
                              typecast(int32(5), 'int8'), ...
                              typecast([1, 2, 3, 4, 5], 'int8'), ...
                             ]);
            test.verifyEqual(ctx.globalSerialized(), ...
                             [typecast(int32(2), 'int8'), ...
                              int8(SeqVal.TypeBool), ...
                              int8(SeqVal.TypeFloat64), ...
                             ]);
        end

        function test_constarg(test)
            ctx = SeqContext();

            e1 = ctx.arg0 * int32(2);
            test.verifyEqual(e1.head, SeqVal.OPMul);
            test.verifyEqual(e1.args, {ctx.arg0, int32(2)});
            e2 = e1 + true;
            test.verifyEqual(e2.head, SeqVal.OPAdd);
            test.verifyEqual(e2.args, {e1, true});

            ie2 = ctx.getValID(e2);
            test.verifyEqual(ie2, uint32(2));
            ie1 = ctx.getValID(e1);
            test.verifyEqual(ie1, uint32(1));

            test.verifyEqual(ctx.nodeSerialized(), ...
                             [typecast(int32(2), 'int8'), ...
                              int8(SeqVal.OPMul), ... % 1: e1 = arg0 * int32(2)
                              int8(SeqVal.ArgArg), typecast(int32(0), 'int8'), ...
                              int8(SeqVal.ArgConstInt32), typecast(int32(2), 'int8'), ...
                              int8(SeqVal.OPAdd), ... % 2: e2 = e1 + true
                              int8(SeqVal.ArgNode), typecast(int32(1), 'int8'), ...
                              int8(SeqVal.ArgConstBool), int8(true), ...
                             ]);
            test.verifyEqual(ctx.dataSerialized(), ...
                             [typecast(int32(0), 'int8'), ...
                             ]);
            test.verifyEqual(ctx.globalSerialized(), ...
                             [typecast(int32(0), 'int8'), ...
                             ]);
        end

        function test_equal(test)
            ctx = SeqContext();

            [g0, g0id] = ctx.newGlobal(SeqVal.TypeBool);
            test.verifyEqual(g0id, 0);
            [g1, g1id] = ctx.newGlobal(SeqVal.TypeBool);
            test.verifyEqual(g1id, 1);
            % == returns `SeqVal`
            test.verifyInstanceOf(g0 == g1, 'SeqVal');
            % isequal returns boolean
            test.verifyInstanceOf(isequal(g0, g1), 'logical');
            test.verifyFalse(isequal(g0, g1));
        end

        function test_operations(test)
            % Test all supported operations on `SeqVal`
            ctx = SeqContext();

            [g0, g0id] = ctx.newGlobal(SeqVal.TypeBool);
            test.verifyEqual(g0id, 0);
            [g1, g1id] = ctx.newGlobal(SeqVal.TypeBool);
            test.verifyEqual(g1id, 1);

            % plus
            v = g0 + g1;
            test.verifyEqual(v.head, SeqVal.OPAdd);
            test.verifyEqual(v.args, {g0, g1});
            test.verifyEqual(SeqVal.toString(v), 'g(0) + g(1)');
            v = 1 + g1;
            test.verifyEqual(v.head, SeqVal.OPAdd);
            test.verifyEqual(v.args, {1, g1});
            test.verifyEqual(SeqVal.toString(v), '1 + g(1)');
            v = g0 + 1;
            test.verifyEqual(v.head, SeqVal.OPAdd);
            test.verifyEqual(v.args, {g0, 1});
            test.verifyEqual(SeqVal.toString(v), 'g(0) + 1');

            % minus
            v = g0 - g1;
            test.verifyEqual(v.head, SeqVal.OPSub);
            test.verifyEqual(v.args, {g0, g1});
            test.verifyEqual(SeqVal.toString(v), 'g(0) - g(1)');
            v = 3 - g1;
            test.verifyEqual(v.head, SeqVal.OPSub);
            test.verifyEqual(v.args, {3, g1});
            test.verifyEqual(SeqVal.toString(v), '3 - g(1)');
            v = g0 - 3;
            test.verifyEqual(v.head, SeqVal.OPSub);
            test.verifyEqual(v.args, {g0, 3});
            test.verifyEqual(SeqVal.toString(v), 'g(0) - 3');

            % times
            v = g0 * g1;
            test.verifyEqual(v.head, SeqVal.OPMul);
            test.verifyEqual(v.args, {g0, g1});
            test.verifyEqual(SeqVal.toString(v), 'g(0) * g(1)');
            v = 3 * g1;
            test.verifyEqual(v.head, SeqVal.OPMul);
            test.verifyEqual(v.args, {3, g1});
            test.verifyEqual(SeqVal.toString(v), '3 * g(1)');
            v = g0 * 3;
            test.verifyEqual(v.head, SeqVal.OPMul);
            test.verifyEqual(v.args, {g0, 3});
            test.verifyEqual(SeqVal.toString(v), 'g(0) * 3');
            v = g0 .* g1;
            test.verifyEqual(v.head, SeqVal.OPMul);
            test.verifyEqual(v.args, {g0, g1});
            test.verifyEqual(SeqVal.toString(v), 'g(0) * g(1)');
            v = 3 .* g1;
            test.verifyEqual(v.head, SeqVal.OPMul);
            test.verifyEqual(v.args, {3, g1});
            test.verifyEqual(SeqVal.toString(v), '3 * g(1)');
            v = g0 .* 3;
            test.verifyEqual(v.head, SeqVal.OPMul);
            test.verifyEqual(v.args, {g0, 3});
            test.verifyEqual(SeqVal.toString(v), 'g(0) * 3');

            % uplus
            test.verifyEqual(+g0, g0);

            % uminus
            v = -g0;
            test.verifyEqual(v.head, SeqVal.OPMul);
            test.verifyEqual(v.args, {int32(-1), g0});
            test.verifyEqual(SeqVal.toString(v), '-1 * g(0)');

            % divide
            v = g0 / g1;
            test.verifyEqual(v.head, SeqVal.OPDiv);
            test.verifyEqual(v.args, {g0, g1});
            test.verifyEqual(SeqVal.toString(v), 'g(0) / g(1)');
            v = 3 / g1;
            test.verifyEqual(v.head, SeqVal.OPDiv);
            test.verifyEqual(v.args, {3, g1});
            test.verifyEqual(SeqVal.toString(v), '3 / g(1)');
            v = g0 / 3;
            test.verifyEqual(v.head, SeqVal.OPDiv);
            test.verifyEqual(v.args, {g0, 3});
            test.verifyEqual(SeqVal.toString(v), 'g(0) / 3');
            v = g0 ./ g1;
            test.verifyEqual(v.head, SeqVal.OPDiv);
            test.verifyEqual(v.args, {g0, g1});
            test.verifyEqual(SeqVal.toString(v), 'g(0) / g(1)');
            v = 3 ./ g1;
            test.verifyEqual(v.head, SeqVal.OPDiv);
            test.verifyEqual(v.args, {3, g1});
            test.verifyEqual(SeqVal.toString(v), '3 / g(1)');
            v = g0 ./ 3;
            test.verifyEqual(v.head, SeqVal.OPDiv);
            test.verifyEqual(v.args, {g0, 3});
            test.verifyEqual(SeqVal.toString(v), 'g(0) / 3');

            v = g0 \ g1;
            test.verifyEqual(v.head, SeqVal.OPDiv);
            test.verifyEqual(v.args, {g1, g0});
            test.verifyEqual(SeqVal.toString(v), 'g(1) / g(0)');
            v = 3 \ g1;
            test.verifyEqual(v.head, SeqVal.OPDiv);
            test.verifyEqual(v.args, {g1, 3});
            test.verifyEqual(SeqVal.toString(v), 'g(1) / 3');
            v = g0 \ 3;
            test.verifyEqual(v.head, SeqVal.OPDiv);
            test.verifyEqual(v.args, {3, g0});
            test.verifyEqual(SeqVal.toString(v), '3 / g(0)');
            v = g0 .\ g1;
            test.verifyEqual(v.head, SeqVal.OPDiv);
            test.verifyEqual(v.args, {g1, g0});
            test.verifyEqual(SeqVal.toString(v), 'g(1) / g(0)');
            v = 3 .\ g1;
            test.verifyEqual(v.head, SeqVal.OPDiv);
            test.verifyEqual(v.args, {g1, 3});
            test.verifyEqual(SeqVal.toString(v), 'g(1) / 3');
            v = g0 .\ 3;
            test.verifyEqual(v.head, SeqVal.OPDiv);
            test.verifyEqual(v.args, {3, g0});
            test.verifyEqual(SeqVal.toString(v), '3 / g(0)');

            % lt
            v = g0 < g1;
            test.verifyEqual(v.head, SeqVal.OPCmpLT);
            test.verifyEqual(v.args, {g0, g1});
            test.verifyEqual(SeqVal.toString(v), 'g(0) < g(1)');
            v = 3 < g1;
            test.verifyEqual(v.head, SeqVal.OPCmpLT);
            test.verifyEqual(v.args, {3, g1});
            test.verifyEqual(SeqVal.toString(v), '3 < g(1)');
            v = g0 < 3;
            test.verifyEqual(v.head, SeqVal.OPCmpLT);
            test.verifyEqual(v.args, {g0, 3});
            test.verifyEqual(SeqVal.toString(v), 'g(0) < 3');

            % gt
            v = g0 > g1;
            test.verifyEqual(v.head, SeqVal.OPCmpGT);
            test.verifyEqual(v.args, {g0, g1});
            test.verifyEqual(SeqVal.toString(v), 'g(0) > g(1)');
            v = 3 > g1;
            test.verifyEqual(v.head, SeqVal.OPCmpGT);
            test.verifyEqual(v.args, {3, g1});
            test.verifyEqual(SeqVal.toString(v), '3 > g(1)');
            v = g0 > 3;
            test.verifyEqual(v.head, SeqVal.OPCmpGT);
            test.verifyEqual(v.args, {g0, 3});
            test.verifyEqual(SeqVal.toString(v), 'g(0) > 3');

            % le
            v = g0 <= g1;
            test.verifyEqual(v.head, SeqVal.OPCmpLE);
            test.verifyEqual(v.args, {g0, g1});
            test.verifyEqual(SeqVal.toString(v), 'g(0) <= g(1)');
            v = 3 <= g1;
            test.verifyEqual(v.head, SeqVal.OPCmpLE);
            test.verifyEqual(v.args, {3, g1});
            test.verifyEqual(SeqVal.toString(v), '3 <= g(1)');
            v = g0 <= 3;
            test.verifyEqual(v.head, SeqVal.OPCmpLE);
            test.verifyEqual(v.args, {g0, 3});
            test.verifyEqual(SeqVal.toString(v), 'g(0) <= 3');

            % ge
            v = g0 >= g1;
            test.verifyEqual(v.head, SeqVal.OPCmpGE);
            test.verifyEqual(v.args, {g0, g1});
            test.verifyEqual(SeqVal.toString(v), 'g(0) >= g(1)');
            v = 3 >= g1;
            test.verifyEqual(v.head, SeqVal.OPCmpGE);
            test.verifyEqual(v.args, {3, g1});
            test.verifyEqual(SeqVal.toString(v), '3 >= g(1)');
            v = g0 >= 3;
            test.verifyEqual(v.head, SeqVal.OPCmpGE);
            test.verifyEqual(v.args, {g0, 3});
            test.verifyEqual(SeqVal.toString(v), 'g(0) >= 3');

            % ne
            v = g0 ~= g1;
            test.verifyEqual(v.head, SeqVal.OPCmpNE);
            test.verifyEqual(v.args, {g0, g1});
            test.verifyEqual(SeqVal.toString(v), 'g(0) ~= g(1)');
            v = 3 ~= g1;
            test.verifyEqual(v.head, SeqVal.OPCmpNE);
            test.verifyEqual(v.args, {3, g1});
            test.verifyEqual(SeqVal.toString(v), '3 ~= g(1)');
            v = g0 ~= 3;
            test.verifyEqual(v.head, SeqVal.OPCmpNE);
            test.verifyEqual(v.args, {g0, 3});
            test.verifyEqual(SeqVal.toString(v), 'g(0) ~= 3');

            % eq
            v = g0 == g1;
            test.verifyEqual(v.head, SeqVal.OPCmpEQ);
            test.verifyEqual(v.args, {g0, g1});
            test.verifyEqual(SeqVal.toString(v), 'g(0) == g(1)');
            v = 3 == g1;
            test.verifyEqual(v.head, SeqVal.OPCmpEQ);
            test.verifyEqual(v.args, {3, g1});
            test.verifyEqual(SeqVal.toString(v), '3 == g(1)');
            v = g0 == 3;
            test.verifyEqual(v.head, SeqVal.OPCmpEQ);
            test.verifyEqual(v.args, {g0, 3});
            test.verifyEqual(SeqVal.toString(v), 'g(0) == 3');

            % and
            v = g0 & g1;
            test.verifyEqual(v.head, SeqVal.OPAnd);
            test.verifyEqual(v.args, {g0, g1});
            test.verifyEqual(SeqVal.toString(v), 'g(0) & g(1)');

            % or
            v = g0 | g1;
            test.verifyEqual(v.head, SeqVal.OPOr);
            test.verifyEqual(v.args, {g0, g1});
            test.verifyEqual(SeqVal.toString(v), 'g(0) | g(1)');

            % xor
            v = xor(g0, g1);
            test.verifyEqual(v.head, SeqVal.OPXor);
            test.verifyEqual(v.args, {g0, g1});
            test.verifyEqual(SeqVal.toString(v), 'xor(g(0), g(1))');

            % not
            v = ~g0;
            test.verifyEqual(v.head, SeqVal.OPNot);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), '~g(0)');

            % abs
            v = abs(g0);
            test.verifyEqual(v.head, SeqVal.OPAbs);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'abs(g(0))');

            % ceil
            v = ceil(g0);
            test.verifyEqual(v.head, SeqVal.OPCeil);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'ceil(g(0))');

            % exp
            v = exp(g0);
            test.verifyEqual(v.head, SeqVal.OPExp);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'exp(g(0))');

            % expm1
            v = expm1(g0);
            test.verifyEqual(v.head, SeqVal.OPExpm1);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'expm1(g(0))');

            % floor
            v = floor(g0);
            test.verifyEqual(v.head, SeqVal.OPFloor);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'floor(g(0))');

            % log
            v = log(g0);
            test.verifyEqual(v.head, SeqVal.OPLog);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'log(g(0))');

            % log1p
            v = log1p(g0);
            test.verifyEqual(v.head, SeqVal.OPLog1p);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'log1p(g(0))');

            % log2
            v = log2(g0);
            test.verifyEqual(v.head, SeqVal.OPLog2);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'log2(g(0))');

            % log10
            v = log10(g0);
            test.verifyEqual(v.head, SeqVal.OPLog10);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'log10(g(0))');

            % pow
            v = g0^g1;
            test.verifyEqual(v.head, SeqVal.OPPow);
            test.verifyEqual(v.args, {g0, g1});
            test.verifyEqual(SeqVal.toString(v), 'g(0) ^ g(1)');
            v = g0^4;
            test.verifyEqual(v.head, SeqVal.OPPow);
            test.verifyEqual(v.args, {g0, 4});
            test.verifyEqual(SeqVal.toString(v), 'g(0) ^ 4');
            v = 2^g1;
            test.verifyEqual(v.head, SeqVal.OPPow);
            test.verifyEqual(v.args, {2, g1});
            test.verifyEqual(SeqVal.toString(v), '2 ^ g(1)');
            v = g0.^g1;
            test.verifyEqual(v.head, SeqVal.OPPow);
            test.verifyEqual(v.args, {g0, g1});
            test.verifyEqual(SeqVal.toString(v), 'g(0) ^ g(1)');
            v = g0.^4;
            test.verifyEqual(v.head, SeqVal.OPPow);
            test.verifyEqual(v.args, {g0, 4});
            test.verifyEqual(SeqVal.toString(v), 'g(0) ^ 4');
            v = 2.^g1;
            test.verifyEqual(v.head, SeqVal.OPPow);
            test.verifyEqual(v.args, {2, g1});
            test.verifyEqual(SeqVal.toString(v), '2 ^ g(1)');

            % sqrt
            v = sqrt(g0);
            test.verifyEqual(v.head, SeqVal.OPSqrt);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'sqrt(g(0))');

            % asin
            v = asin(g0);
            test.verifyEqual(v.head, SeqVal.OPAsin);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'asin(g(0))');

            % acos
            v = acos(g0);
            test.verifyEqual(v.head, SeqVal.OPAcos);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'acos(g(0))');

            % atan
            v = atan(g0);
            test.verifyEqual(v.head, SeqVal.OPAtan);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'atan(g(0))');

            % atan2
            v = atan2(g0, g1);
            test.verifyEqual(v.head, SeqVal.OPAtan2);
            test.verifyEqual(v.args, {g0, g1});
            test.verifyEqual(SeqVal.toString(v), 'atan2(g(0), g(1))');
            v = atan2(g0, 4);
            test.verifyEqual(v.head, SeqVal.OPAtan2);
            test.verifyEqual(v.args, {g0, 4});
            test.verifyEqual(SeqVal.toString(v), 'atan2(g(0), 4)');
            v = atan2(2, g1);
            test.verifyEqual(v.head, SeqVal.OPAtan2);
            test.verifyEqual(v.args, {2, g1});
            test.verifyEqual(SeqVal.toString(v), 'atan2(2, g(1))');

            % acot
            v = acot(g0);
            v2 = v.args{1};
            test.verifyEqual(v.head, SeqVal.OPAtan);
            test.verifyEqual(v.args, {v2});
            test.verifyEqual(v2.head, SeqVal.OPDiv);
            test.verifyEqual(v2.args, {1, g0});
            test.verifyEqual(SeqVal.toString(v), 'atan(1 / g(0))');

            % asec
            v = asec(g0);
            v2 = v.args{1};
            test.verifyEqual(v.head, SeqVal.OPAcos);
            test.verifyEqual(v.args, {v2});
            test.verifyEqual(v2.head, SeqVal.OPDiv);
            test.verifyEqual(v2.args, {1, g0});
            test.verifyEqual(SeqVal.toString(v), 'acos(1 / g(0))');

            % acsc
            v = acsc(g0);
            v2 = v.args{1};
            test.verifyEqual(v.head, SeqVal.OPAsin);
            test.verifyEqual(v.args, {v2});
            test.verifyEqual(v2.head, SeqVal.OPDiv);
            test.verifyEqual(v2.args, {1, g0});
            test.verifyEqual(SeqVal.toString(v), 'asin(1 / g(0))');

            % asinh
            v = asinh(g0);
            test.verifyEqual(v.head, SeqVal.OPAsinh);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'asinh(g(0))');

            % acosh
            v = acosh(g0);
            test.verifyEqual(v.head, SeqVal.OPAcosh);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'acosh(g(0))');

            % atanh
            v = atanh(g0);
            test.verifyEqual(v.head, SeqVal.OPAtanh);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'atanh(g(0))');

            % acoth
            v = acoth(g0);
            v2 = v.args{1};
            test.verifyEqual(v.head, SeqVal.OPAtanh);
            test.verifyEqual(v.args, {v2});
            test.verifyEqual(v2.head, SeqVal.OPDiv);
            test.verifyEqual(v2.args, {1, g0});
            test.verifyEqual(SeqVal.toString(v), 'atanh(1 / g(0))');

            % asech
            v = asech(g0);
            v2 = v.args{1};
            test.verifyEqual(v.head, SeqVal.OPAcosh);
            test.verifyEqual(v.args, {v2});
            test.verifyEqual(v2.head, SeqVal.OPDiv);
            test.verifyEqual(v2.args, {1, g0});
            test.verifyEqual(SeqVal.toString(v), 'acosh(1 / g(0))');

            % acsch
            v = acsch(g0);
            v2 = v.args{1};
            test.verifyEqual(v.head, SeqVal.OPAsinh);
            test.verifyEqual(v.args, {v2});
            test.verifyEqual(v2.head, SeqVal.OPDiv);
            test.verifyEqual(v2.args, {1, g0});
            test.verifyEqual(SeqVal.toString(v), 'asinh(1 / g(0))');

            % sin
            v = sin(g0);
            test.verifyEqual(v.head, SeqVal.OPSin);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'sin(g(0))');

            % cos
            v = cos(g0);
            test.verifyEqual(v.head, SeqVal.OPCos);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'cos(g(0))');

            % tan
            v = tan(g0);
            test.verifyEqual(v.head, SeqVal.OPTan);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'tan(g(0))');

            % cot
            v = cot(g0);
            v2 = v.args{2};
            test.verifyEqual(v.head, SeqVal.OPDiv);
            test.verifyEqual(v.args, {1, v2});
            test.verifyEqual(v2.head, SeqVal.OPTan);
            test.verifyEqual(v2.args, {g0});
            test.verifyEqual(SeqVal.toString(v), '1 / tan(g(0))');

            % sec
            v = sec(g0);
            v2 = v.args{2};
            test.verifyEqual(v.head, SeqVal.OPDiv);
            test.verifyEqual(v.args, {1, v2});
            test.verifyEqual(v2.head, SeqVal.OPCos);
            test.verifyEqual(v2.args, {g0});
            test.verifyEqual(SeqVal.toString(v), '1 / cos(g(0))');

            % csc
            v = csc(g0);
            v2 = v.args{2};
            test.verifyEqual(v.head, SeqVal.OPDiv);
            test.verifyEqual(v.args, {1, v2});
            test.verifyEqual(v2.head, SeqVal.OPSin);
            test.verifyEqual(v2.args, {g0});
            test.verifyEqual(SeqVal.toString(v), '1 / sin(g(0))');

            % sinh
            v = sinh(g0);
            test.verifyEqual(v.head, SeqVal.OPSinh);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'sinh(g(0))');

            % cosh
            v = cosh(g0);
            test.verifyEqual(v.head, SeqVal.OPCosh);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'cosh(g(0))');

            % tanh
            v = tanh(g0);
            test.verifyEqual(v.head, SeqVal.OPTanh);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'tanh(g(0))');

            % coth
            v = coth(g0);
            v2 = v.args{2};
            test.verifyEqual(v.head, SeqVal.OPDiv);
            test.verifyEqual(v.args, {1, v2});
            test.verifyEqual(v2.head, SeqVal.OPTanh);
            test.verifyEqual(v2.args, {g0});
            test.verifyEqual(SeqVal.toString(v), '1 / tanh(g(0))');

            % sech
            v = sech(g0);
            v2 = v.args{2};
            test.verifyEqual(v.head, SeqVal.OPDiv);
            test.verifyEqual(v.args, {1, v2});
            test.verifyEqual(v2.head, SeqVal.OPCosh);
            test.verifyEqual(v2.args, {g0});
            test.verifyEqual(SeqVal.toString(v), '1 / cosh(g(0))');

            % csch
            v = csch(g0);
            v2 = v.args{2};
            test.verifyEqual(v.head, SeqVal.OPDiv);
            test.verifyEqual(v.args, {1, v2});
            test.verifyEqual(v2.head, SeqVal.OPSinh);
            test.verifyEqual(v2.args, {g0});
            test.verifyEqual(SeqVal.toString(v), '1 / sinh(g(0))');

            % hypot
            v = hypot(g0, g1);
            test.verifyEqual(v.head, SeqVal.OPHypot);
            test.verifyEqual(v.args, {g0, g1});
            test.verifyEqual(SeqVal.toString(v), 'hypot(g(0), g(1))');
            v = hypot(g0, 4);
            test.verifyEqual(v.head, SeqVal.OPHypot);
            test.verifyEqual(v.args, {g0, 4});
            test.verifyEqual(SeqVal.toString(v), 'hypot(g(0), 4)');
            v = hypot(2, g1);
            test.verifyEqual(v.head, SeqVal.OPHypot);
            test.verifyEqual(v.args, {2, g1});
            test.verifyEqual(SeqVal.toString(v), 'hypot(2, g(1))');

            % erf
            v = erf(g0);
            test.verifyEqual(v.head, SeqVal.OPErf);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'erf(g(0))');

            % erfc
            v = erfc(g0);
            test.verifyEqual(v.head, SeqVal.OPErfc);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'erfc(g(0))');

            % gamma
            v = gamma(g0);
            test.verifyEqual(v.head, SeqVal.OPGamma);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'gamma(g(0))');

            % gammaln
            v = gammaln(g0);
            test.verifyEqual(v.head, SeqVal.OPLgamma);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'gammaln(g(0))');

            % round
            v = round(g0);
            test.verifyEqual(v.head, SeqVal.OPRint);
            test.verifyEqual(v.args, {g0});
            test.verifyEqual(SeqVal.toString(v), 'round(g(0))');

            % max
            v = max(g0, g1);
            test.verifyEqual(v.head, SeqVal.OPMax);
            test.verifyEqual(v.args, {g0, g1});
            test.verifyEqual(SeqVal.toString(v), 'max(g(0), g(1))');
            v = max(g0, 4);
            test.verifyEqual(v.head, SeqVal.OPMax);
            test.verifyEqual(v.args, {g0, 4});
            test.verifyEqual(SeqVal.toString(v), 'max(g(0), 4)');
            v = max(2, g1);
            test.verifyEqual(v.head, SeqVal.OPMax);
            test.verifyEqual(v.args, {2, g1});
            test.verifyEqual(SeqVal.toString(v), 'max(2, g(1))');

            % min
            v = min(g0, g1);
            test.verifyEqual(v.head, SeqVal.OPMin);
            test.verifyEqual(v.args, {g0, g1});
            test.verifyEqual(SeqVal.toString(v), 'min(g(0), g(1))');
            v = min(g0, 4);
            test.verifyEqual(v.head, SeqVal.OPMin);
            test.verifyEqual(v.args, {g0, 4});
            test.verifyEqual(SeqVal.toString(v), 'min(g(0), 4)');
            v = min(2, g1);
            test.verifyEqual(v.head, SeqVal.OPMin);
            test.verifyEqual(v.args, {2, g1});
            test.verifyEqual(SeqVal.toString(v), 'min(2, g(1))');

            % rem
            v = rem(g0, g1);
            test.verifyEqual(v.head, SeqVal.OPMod);
            test.verifyEqual(v.args, {g0, g1});
            test.verifyEqual(SeqVal.toString(v), 'rem(g(0), g(1))');
            v = rem(g0, 4);
            test.verifyEqual(v.head, SeqVal.OPMod);
            test.verifyEqual(v.args, {g0, 4});
            test.verifyEqual(SeqVal.toString(v), 'rem(g(0), 4)');
            v = rem(2, g1);
            test.verifyEqual(v.head, SeqVal.OPMod);
            test.verifyEqual(v.args, {2, g1});
            test.verifyEqual(SeqVal.toString(v), 'rem(2, g(1))');

            % ifelse
            v = ifelse(g0, g1, 3);
            test.verifyEqual(v.head, SeqVal.OPSelect);
            test.verifyEqual(v.args, {g0, g1, 3});
            test.verifyEqual(SeqVal.toString(v), 'ifelse(g(0), g(1), 3)');
        end

        function test_optimizations(test)
            % Constant folding at construction time.
            ctx = SeqContext();

            [g0, g0id] = ctx.newGlobal(SeqVal.TypeBool);
            test.verifyEqual(g0id, 0);
            [g1, g1id] = ctx.newGlobal(SeqVal.TypeBool);
            test.verifyEqual(g1id, 1);

            test.verifyEqual(g0 + 0, g0);
            test.verifyEqual(0 + g1, g1);

            test.verifyEqual(g0 - g0, 0);
            test.verifyEqual(g1 - 0, g1);

            test.verifyEqual(g0 * 0, false);
            test.verifyEqual(g1 * 1, g1);
            test.verifyEqual(0 * g1, false);
            test.verifyEqual(1 * g0, g0);

            test.verifyEqual(+g0, g0);

            test.verifyEqual(0 / g1, false);
            test.verifyEqual(g0 \ 0, false);
            test.verifyEqual(g0 / 1, g0);
            test.verifyEqual(1 \ g1, g1);

            test.verifyEqual(g0 < g0, false);
            test.verifyEqual(g1 > g1, false);
            test.verifyEqual(g1 >= g1, true);
            test.verifyEqual(g0 <= g0, true);
            test.verifyEqual(g1 == g1, true);
            test.verifyEqual(g0 ~= g0, false);

            test.verifyEqual(g0 & 1, g0);
            test.verifyEqual(g1 & 0, false);
            test.verifyEqual(1 & g1, g1);
            test.verifyEqual(0 & g0, false);
            test.verifyEqual(g0 & g0, g0);

            test.verifyEqual(g0 | 1, true);
            test.verifyEqual(g1 | 0, g1);
            test.verifyEqual(1 | g1, true);
            test.verifyEqual(0 | g0, g0);
            test.verifyEqual(g1 | g1, g1);

            test.verifyEqual(xor(g0, g0), false);
            test.verifyEqual(xor(g0, false), g0);
            test.verifyEqual(xor(false, g1), g1);
            ng0 = xor(g0, 1);
            test.verifyEqual(ng0.head, SeqVal.OPNot);
            test.verifyEqual(ng0.args, {g0});
            ng1 = xor(1, g1);
            test.verifyEqual(ng1.head, SeqVal.OPNot);
            test.verifyEqual(ng1.args, {g1});

            test.verifyEqual(1^g1, 1);
            test.verifyEqual(g0^0, int32(1));
            test.verifyEqual(g1^1, g1);
            g0_2 = g0^2;
            test.verifyEqual(g0_2.head, SeqVal.OPMul);
            test.verifyEqual(g0_2.args, {g0, g0});

            rg0 = round(g0);
            test.verifyEqual(round(rg0), rg0);

            test.verifyEqual(max(g1, g1), g1);
            test.verifyEqual(min(g0, g0), g0);

            test.verifyEqual(ifelse(true, g0, g1), g0);
            test.verifyEqual(ifelse(false, g0, g1), g1);
            test.verifyEqual(ifelse(g0, 1, 1), 1);
            test.verifyEqual(ifelse(g1, g0, g0), g0);
        end
    end
end
