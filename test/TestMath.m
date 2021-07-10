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

classdef TestMath < matlab.unittest.TestCase
    %% Test Method Block
    methods(Test)
        function fldcld(test)
            test.verifyEqual(fld(5.5, 2.2), 2);
            test.verifyEqual(cld(5.5, 2.2), 3);
            % test.verifyEqual(fld(6.0, 0.1), 59); broken
            test.verifyEqual(cld(6.0, 0.1), 60);
            test.verifyEqual(fld(7.3, 5.5), 1);
            test.verifyEqual(cld(7.3, 5.5), 2);
            test.verifyEqual(fld(9.0, 3.0), 3);
            test.verifyEqual(cld(9.0, 3.0), 3);
            test.verifyEqual(fld(-0.097076000000000023, 0.0000020000000000000003), -48539);
            test.verifyEqual(cld(-0.097076000000000023, 0.0000020000000000000003), -48538);
        end
        function ifelse(test)
            test.verifyEqual(ifelse(true, 1, 2), 1);
            test.verifyEqual(ifelse(false, 1, 2), 2);
        end
        function interpolate(test)
            test.verifyEqual(interpolate(-1, 0, 5, [0, 9, 2, 3, -10, 5]), 0);
            test.verifyEqual(interpolate(0, 0, 5, [0, 9, 2, 3, -10, 5]), 0);
            test.verifyEqual(interpolate(1, 0, 5, [0, 9, 2, 3, -10, 5]), 9);
            test.verifyEqual(interpolate(2, 0, 5, [0, 9, 2, 3, -10, 5]), 2);
            test.verifyEqual(interpolate(3, 0, 5, [0, 9, 2, 3, -10, 5]), 3);
            test.verifyEqual(interpolate(4, 0, 5, [0, 9, 2, 3, -10, 5]), -10);
            test.verifyEqual(interpolate(5, 0, 5, [0, 9, 2, 3, -10, 5]), 5);
            test.verifyEqual(interpolate(6, 0, 5, [0, 9, 2, 3, -10, 5]), 5);
            test.verifyEqual(interpolate(2.5, 0, 5, [0, 9, 2, 3, -10, 5]), 2.5);
        end
    end
end
