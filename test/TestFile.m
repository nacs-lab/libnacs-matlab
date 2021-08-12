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

classdef TestFile < matlab.unittest.TestCase
    properties
        tmppath;
    end
    methods(TestMethodSetup)
        function createTempPath(test)
            test.tmppath = tempname();
            mkdir(test.tmppath);
        end
    end
    methods(TestMethodTeardown)
        function removeTempPath(test)
            rmdir(test.tmppath, 's');
        end
    end
    %% Test Method Block
    methods(Test)
        function test_save_atomic(test)
            path1 = [test.tmppath, '/test_mat1'];
            data = struct('AA', [1, 2, 3, 4, 5], 'BBB', 'CDEFG');
            data.ccc = {1, 2, 3};
            save_atomic(path1, data);
            m = load([path1, '.mat']);
            test.verifyEqual(m, data);

            path2 = [test.tmppath, '/test_mat2.mat'];
            data = struct('AA', [1, 2, 3], 'BBB', 'CDEFGacd', 'CCCCC', struct('A', 1));
            data.ccc = {1, 2, 'xyz'};
            save_atomic(path2, data);
            m = load(path2);
            test.verifyEqual(m, data);
        end

        function test_dump_file(test)
            % Double
            p = [test.tmppath, '/test_bin1'];
            data = rand(1, 30);
            dump_to_file(p, data);
            f = fopen(p);
            rd = fread(f, Inf, 'double');
            test.verifyEqual(rd', data);

            % Int8
            p = [test.tmppath, '/test_bin2'];
            data = int8(rand(1, 49) * 100);
            dump_to_file(p, data);
            f = fopen(p);
            rd = fread(f, Inf, 'int8=>int8');
            test.verifyEqual(rd', data);

            % multi dimensional
            p = [test.tmppath, '/test_bin3'];
            data = int16(rand(11, 49) * 10000);
            dump_to_file(p, data);
            f = fopen(p);
            rd = fread(f, Inf, 'int16=>int16');
            test.verifyEqual(rd', reshape(data, [1, numel(data)]));

            % char
            p = [test.tmppath, '/test_bin3'];
            data = char(rand(1, 53) * 128);
            dump_to_file(p, data);
            f = fopen(p);
            rd = fread(f, Inf, 'int8=>char');
            test.verifyEqual(rd', data);

            % multi dimentional char
            p = [test.tmppath, '/test_bin3'];
            data = char(rand(7, 53) * 128);
            dump_to_file(p, data);
            f = fopen(p);
            rd = fread(f, Inf, 'int8=>char');
            test.verifyEqual(rd', reshape(data, [1, numel(data)]));
        end
    end
end
