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

classdef TestNumToStr < matlab.unittest.TestCase
    %% Test Method Block
    methods(Test)
        function special(test)
            test.verifyEqual(num_to_str(uint32(10)), '10');
            test.verifyEqual(num_to_str(int32(-10)), '-10');
            test.verifyEqual(num_to_str(true), '1');
            test.verifyEqual(num_to_str(inf), 'inf');
            test.verifyEqual(num_to_str(-inf), '-inf');
            test.verifyEqual(num_to_str(nan), 'nan');
        end
        function integer(test)
            test.verifyEqual(num_to_str(11), '11');
            test.verifyEqual(num_to_str(-11), '-11');
            test.verifyEqual(num_to_str(0), '0');
            test.verifyEqual(num_to_str(-0), '0');
        end
        function unity(test)
            test.verifyEqual(num_to_str(1.1), '1.1');
            test.verifyEqual(num_to_str(-1.1), '-1.1');
            test.verifyEqual(num_to_str(0.3), '0.3');
            test.verifyEqual(num_to_str(-0.3), '-0.3');
            test.verifyEqual(num_to_str(0.1 + 0.2), '0.30000000000000004');
            test.verifyEqual(num_to_str(-0.1 - 0.2), '-0.30000000000000004');
        end
        function small(test)
            test.verifyEqual(num_to_str(1.1e-7), '1.1e-7');
            test.verifyEqual(num_to_str(-1.1e-7), '-1.1e-7');
            test.verifyEqual(num_to_str(3e-8), '3e-8');
            test.verifyEqual(num_to_str(-3e-8), '-3e-8');
            test.verifyEqual(num_to_str(1e-8 + 2e-8), '3.0000000000000004e-8');
            test.verifyEqual(num_to_str(-1e-8 - 2e-8), '-3.0000000000000004e-8');
        end
        function large(test)
            test.verifyEqual(num_to_str(1.1e7), '1.1e7');
            test.verifyEqual(num_to_str(-1.1e7), '-1.1e7');

            test.verifyEqual(num_to_str(1.234e7 + 2.345e7), '3.579e7');
            test.verifyEqual(num_to_str(-1.234e7 - 2.345e7), '-3.579e7');
        end
    end
end
