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

classdef TestEnableScan < matlab.unittest.TestCase
    %% Test Method Block
    methods(Test)
        function dotest(test)
            cleanup = onCleanup(@() EnableScan.set(true));

            test.verifyTrue(EnableScan.check());
            EnableScan.set(false);
            test.verifyFalse(EnableScan.check());
            EnableScan.set(true);
            test.verifyTrue(EnableScan.check());

            a0 = EnableScan(false);
            test.verifyFalse(EnableScan.check());
            delete(a0);
            test.verifyTrue(EnableScan.check());

            disabled = false;
            function disable()
                a = EnableScan(false);
                disabled = ~EnableScan.check();
                error();
            end

            try
                disable();
            catch
            end
            test.verifyTrue(disabled);
            test.verifyTrue(EnableScan.check());
        end
    end
end
