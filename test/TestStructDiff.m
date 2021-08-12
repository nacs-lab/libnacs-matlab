%% Copyright (c) 2021-2021, Yichao Yu <yyc1992@gmail.com>
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

classdef TestStructDiff < matlab.unittest.TestCase
    methods
        function res = checked_disp(test, diff)
            str1 = evalc('disp(diff);');
            str2 = evalc('diff');
            str3 = evalc('display(diff)');
            test.verifyEqual(str1, str3);
            test.verifyEqual(str2, ['diff = ', str1]);
            res = str1;
        end
    end
    %% Test Method Block
    methods(Test)
        function test_empty(test)
            diff = StructDiff(struct('a', 'b', 'b', 1), struct('a', 'b', 'b', 1));
            test.verifyEqual(diff.v1, struct());
            test.verifyEqual(diff.v2, struct());
            str = test.checked_disp(diff);
            test.verifyEqual(str, ['StructDiff:', 10, ...
                                   '  <empty>', 10, ...
                                  ]);
        end
        function test_simple(test)
            diff = StructDiff(struct('a', 'b', 'b', 1), struct('a', 'c', 'b', 1));
            test.verifyEqual(diff.v1, struct('a', 'b'));
            test.verifyEqual(diff.v2, struct('a', 'c'));
            str = test.checked_disp(diff);
            test.verifyEqual(str, ['StructDiff: -1 +2', 10, ...
                                   '  a:', 10, ...
                                   '    - b', 10, ...
                                   '    + c', 10, ...
                                  ]);
        end
        function test_dynprops(test)
            diff = StructDiff(DynProps(struct('a', 1.3, 'b', 1)), ...
                              DynProps(struct('a', 'c', 'b', 1)));
            test.verifyEqual(diff.v1, struct('a', 1.3));
            test.verifyEqual(diff.v2, struct('a', 'c'));
            str = test.checked_disp(diff);
            test.verifyEqual(str, ['StructDiff: -1 +2', 10, ...
                                   '  a:', 10, ...
                                   '    - 1.3', 10, ...
                                   '    + c', 10, ...
                                  ]);
        end
        function test_subprops(test)
            dp = DynProps(struct('v1', struct('a', [1.3, 3], 'b', [1, 2, 3], 'k', [1, 2]), ...
                                 'v2', struct('a', [1.3, 5], 'b', 'y', 'k', [1, 2])));
            diff = StructDiff(dp.v1, dp.v2);
            test.verifyEqual(diff.v1, struct('a', [1.3, 3], 'b', [1, 2, 3]));
            test.verifyEqual(diff.v2, struct('a', [1.3, 5], 'b', 'y'));
            str = test.checked_disp(diff);
            test.verifyEqual(str, ['StructDiff: -1 +2', 10, ...
                                   '  a:', 10, ...
                                   '    - [1.3, 3]', 10, ...
                                   '    + [1.3, 5]', 10, ...
                                   '  b:', 10, ...
                                   '    - [1, 2, 3]', 10, ...
                                   '    + y', 10, ...
                                  ]);
        end
        function test_nest(test)
            diff = StructDiff(struct('a', struct('x', 2, 'y', struct('z', struct('c', 2))), ...
                                     'b', struct('y', 1), 'c', struct('k', 2.3)), ...
                              struct('a', struct('x', 2, 'y', struct('z', struct('c', 'x'))), ...
                                     'b', struct('y', 2), 'd', struct('g', 5.6)));
            test.verifyEqual(diff.v1, struct('a', struct('y', struct('z', struct('c', 2))), ...
                                             'b', struct('y', 1), 'c', struct('k', 2.3)));
            test.verifyEqual(diff.v2, struct('a', struct('y', struct('z', struct('c', 'x'))), ...
                                             'b', struct('y', 2), 'd', struct('g', 5.6)));
            str = test.checked_disp(diff);
            test.verifyEqual(str, ['StructDiff: -1 +2', 10, ...
                                   '  - c:', 10, ...
                                   '      k: 2.3', 10, ...
                                   '  + d:', 10, ...
                                   '      g: 5.6', 10, ...
                                   '  a.y.z.c:', 10, ...
                                   '    - 2', 10, ...
                                   '    + x', 10, ...
                                   '  b.y:', 10, ...
                                   '    - 1', 10, ...
                                   '    + 2', 10, ...
                                  ]);
        end
    end
end
