%% Copyright (c) 2018-2021, Yichao Yu <yyc1992@gmail.com>
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

classdef TestDynProps < matlab.unittest.TestCase
    properties
        print_style = false;
    end
    methods
        function res = checked_disp(test, V)
            str1 = evalc('disp(V);');
            str2 = evalc('V');
            str3 = evalc('display(V)');
            test.verifyEqual(str1, str3);
            test.verifyEqual(str2, ['V = ', str1]);
            res = str1;
        end
    end
    methods(TestMethodSetup)
        function setup(test)
            try
                useDesktop = usejava('desktop');
            catch
                useDesktop = false;
            end
            test.print_style = useDesktop && ~isdeployed;
        end
    end
    %% Test Method Block
    methods(Test)
        function dotest(test)
            s.A = 1;
            s.B = 2;
            s.C.B = 3;

            %% Default constructor and constructor with pre-populated values
            dp0 = DynProps();
            dp1 = DynProps(s);

            %% Pre-populated values
            test.verifyEqual(dp1.A, 1);
            test.verifyEqual(dp1.B, 2);
            test.verifyEqual(dp1.C.B, 3);

            %% Simple default values
            test.verifyEqual(dp0.A(1), 1);
            test.verifyEqual(dp0.B(2), 2);

            %% Struct assignments
            dp0.C = struct('A', 1, 'B', 2);
            test.verifyEqual(dp0.C.A, 1);
            test.verifyEqual(dp0.C.B, 2);
            test.verifyEqual(dp0.C(), struct('A', 1, 'B', 2));
            d0c = dp0.C(struct('C', 3));
            test.verifyEqual(d0c.C, 3);
            test.verifyEqual(d0c, struct('A', 1, 'B', 2, 'C', 3));
            test.verifyEqual(dp0.C(), struct('A', 1, 'B', 2, 'C', 3));
            d0c2 = dp0.C(struct('D', 4));
            test.verifyTrue(isfield(d0c, 'C'));
            test.verifyFalse(isfield(d0c, 'D'));
            test.verifyTrue(isfield(d0c2, 'C'));
            test.verifyTrue(isfield(d0c2, 'D'));
            test.verifyEqual(d0c2.D, 4);
            test.verifyEqual(d0c2, struct('A', 1, 'B', 2, 'C', 3, 'D', 4));
            test.verifyEqual(dp0.C(), struct('A', 1, 'B', 2, 'C', 3, 'D', 4));
            d0c3 = dp0.C('D', 5);
            test.verifyEqual(d0c3.D, 4);
            test.verifyEqual(d0c3, struct('A', 1, 'B', 2, 'C', 3, 'D', 4));
            test.verifyEqual(dp0.C(), struct('A', 1, 'B', 2, 'C', 3, 'D', 4));
            dp0.C.D = NaN;
            d0c4 = dp0.C('D', 5);
            test.verifyEqual(d0c4.D, 5);
            test.verifyEqual(d0c4, struct('A', 1, 'B', 2, 'C', 3, 'D', 5));
            test.verifyEqual(dp0.C(), struct('A', 1, 'B', 2, 'C', 3, 'D', 5));

            dp0.C = struct('A', 1, 'B', 2);
            d0c = dp0.C{'C', 3};
            test.verifyEqual(d0c.C, 3);
            test.verifyEqual(d0c(), struct('A', 1, 'B', 2, 'C', 3));
            d0c.C = 2;
            test.verifyEqual(dp0.C(), struct('A', 1, 'B', 2, 'C', 2));
            d0c.C = 3;
            d0c2 = dp0.C{'D', 4};
            test.verifyEqual(d0c2.D, 4);
            test.verifyEqual(d0c2(), struct('A', 1, 'B', 2, 'C', 3, 'D', 4));

            %% Create new nested field
            dp1.D.E.F = 3;
            test.verifyEqual(dp1.D.E.F, 3);

            %% Create new nested field with default value
            test.verifyEqual(dp0.D.E.F.G(4), 4);
            test.verifyEqual(dp0.D.E.F.G, 4);

            %% Assign to single array element
            dp0.A(3) = 2;
            test.verifyEqual(dp0.A, [1, 0, 2]);

            %% Reference to subfield.
            c0 = dp0.C;
            test.verifyEqual(c0.A, 1);
            test.verifyEqual(c0.B, 2);
            test.verifyEqual(c0.A(3), 1);
            test.verifyEqual(c0.C(3), 3);
            test.verifyEqual(c0.C, 3);
            c0.D = 4;
            test.verifyEqual(c0.D(3), 4);
            test.verifyEqual(c0.D, 4);
            c0.A = 2;
            test.verifyEqual(c0.A, 2);

            %% Make sure mutation to the subfield reference is reflected on the original one.
            test.verifyEqual(dp0.C.A, 2);
            test.verifyEqual(dp0.C.B, 2);
            test.verifyEqual(dp0.C.C, 3);
            test.verifyEqual(dp0.C.D, 4);

            c0.A = NaN;
            test.verifyEqual(c0.A(1), 1);
            test.verifyEqual(c0.A(), 1);
            test.verifyEqual(c0.A, 1);

            dp2 = DynProps();
            dp2.C.A = 2;
            c = dp2.C{struct('A', 4, 'B', 3), 'C', 1};
            test.verifyEqual(c(), struct('A', 2, 'B', 3, 'C', 1));
            test.verifyEqual(dp2.C(), struct('A', 2, 'B', 3, 'C', 1));

            dp2 = DynProps();
            dp2.C.A = 2;
            test.verifyEqual(dp2.C(struct('A', 4, 'B', 3), 'C', 1), ...
                             struct('A', 2, 'B', 3, 'C', 1));
        end

        function test_disp(test)
            dp = DynProps();
            test.verifyEqual(test.checked_disp(dp), ...
                             ['DynProps:', 10, ...
                              '  {}', 10, ...
                             ]);
            dp.X = NaN;
            test.verifyEqual(test.checked_disp(dp), ...
                             ['DynProps:', 10, ...
                              '  X: nan', 10, ...
                             ]);
            dp.YZ = [1, 2, 3];
            test.verifyEqual(test.checked_disp(dp), ...
                             ['DynProps:', 10, ...
                              '  X: nan', 10, ...
                              '  YZ: [1, 2, 3]', 10, ...
                             ]);

            dp = DynProps();
            dp.X.Y = 2;
            dp.X.A.Z.U = 9;
            dp.X.A.Z.T = NaN;
            test.verifyEqual(test.checked_disp(dp), ...
                             ['DynProps:', 10, ...
                              '  X:', 10, ...
                              '    Y: 2', 10, ...
                              '    A: Z:', 10, ...
                              '         U: 9', 10, ...
                              '         T: nan', 10, ...
                             ]);
            if test.print_style
                test.verifyEqual(test.checked_disp(dp.X), ...
                                 ['SubProps{DynProps}: <strong>[.X]</strong>', 10, ...
                                  '  Y: 2', 10, ...
                                  '  A: Z:', 10, ...
                                  '       U: 9', 10, ...
                                  '       T: nan', 10, ...
                                 ]);
            else
                test.verifyEqual(test.checked_disp(dp.X), ...
                                 ['SubProps{DynProps}: [.X]', 10, ...
                                  '  Y: 2', 10, ...
                                  '  A: Z:', 10, ...
                                  '       U: 9', 10, ...
                                  '       T: nan', 10, ...
                                 ]);
            end
        end
    end
end
