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

classdef TestMutableRef < matlab.unittest.TestCase
    %% Test Method Block
    methods(Test)
        function test(test)
            ref = MutableRef();
            test.verifyEqual(ref.get(), []);
            ref.set(2);
            test.verifyEqual(ref.get(), 2);
            ref.set({});
            test.verifyEqual(ref.get(), {});

            ref = MutableRef('xyz');
            test.verifyEqual(ref.get(), 'xyz');
            ref.set({1, 2, 3});
            test.verifyEqual(ref.get(), {1, 2, 3});
        end
    end
end
