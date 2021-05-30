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

classdef TestExpSeq < matlab.unittest.TestCase
    %% Test Method Block
    properties
        path;
    end

    methods
        function res = read_json(test, path)
            str = fileread(path);
            str = regexprep([str 10], '//[^\n]*\n', ''); % Manualy remove comments from json
            res = jsondecode(str);
        end
    end

    methods(TestMethodSetup)
        function setup(test)
            [test.path, ~, ~] = fileparts(mfilename('fullpath'));
            SeqManager.override_tick_per_sec(1000);
        end
    end

    methods(TestMethodTeardown)
        function teardown(test)
            SeqManager.override_tick_per_sec(0);
        end
    end

    methods(Test)
        function test1(test)
            s = ExpSeq();
            s.addStep(1).add('Device1/CH1', 4);
            test.verifyEqual(s.curTime, 1);
            s.conditional(false).addStep(0.1).add('Device1/CH5', 3);
            test.verifyEqual(s.curTime, 1);
            s.conditional(true).addStep(0.1004).add('Device2/CH3', -1);
            test.verifyEqual(s.curTime, 1.1);
            s.wait(2.3);
            test.verifyEqual(s.curTime, 3.4);
            s.conditional(false).wait(100);
            test.verifyEqual(s.curTime, 3.4);

            g = s.newGlobal();
            s.wait(g);
            test.verifyClass(s.curTime, 'SeqVal');;
            test.verifyEqual(SeqVal.toString(s.curTime), '(3400 + round(g(0) * 1000)) / 1000');
            m1 = s.addMeasure('Device2/CH5');
            s.conditional(m1 < 0).wait(3.4);
            test.verifyEqual(SeqVal.toString(s.curTime), ...
                             '(3400 + ifelse(m(4) < 0, 3400, 0) + round(g(0) * 1000)) / 1000');
            s.addStep(1.2).add('Device1/CH5', @(t) t - 2.3);

            test.verifyEqual(SeqVal.toString(s.totalTime()), ...
                             '(4600 + ifelse(m(4) < 0, 3400, 0) + round(g(0) * 1000)) / 1000');
            test.verifyEqual([toString(s) char(10)], fileread([test.path '/seq1.txt']));

            % It should be clear that nothing needs to be waited for.
            s.waitBackground();
            test.verifyEqual(SeqVal.toString(s.totalTime()), ...
                             '(4600 + ifelse(m(4) < 0, 3400, 0) + round(g(0) * 1000)) / 1000');
            test.verifyEqual([toString(s) char(10)], fileread([test.path '/seq1.txt']));
            s.waitAll();
            test.verifyEqual(SeqVal.toString(s.totalTime()), ...
                             '(4600 + ifelse(m(4) < 0, 3400, 0) + round(g(0) * 1000)) / 1000');
            test.verifyEqual([toString(s) char(10)], fileread([test.path '/seq1.txt']));
            bytes = serialize(s);
            test.verifyEqual(serialize(s), bytes);
            test.verifyEqual(bytes, int8(test.read_json([test.path '/seq1.json']))');
        end
        function test2(test)
            s = ExpSeq();
            g = s.newGlobal();
            s.add('Device2/CH2', g + 2);
            function subseq(s, len)
                m = s.addMeasure('Device2/CH2');
                s.addStep(len) ...
                 .add('Device2/CH2', 3.4) ...
                 .add('Device3/CH1', @(t) t * 5 - m);
                s.add('Device2/CH2', 0) ...
                 .add('Device3/CH1', 0);
            end
            s.addStep(@subseq, g * 0.2);
            test.verifyEqual(SeqVal.toString(s.curTime), 'round(g(0) * 0.2 * 1000) / 1000');
            test.verifyEqual(SeqVal.toString(s.totalTime()), 'round(g(0) * 0.2 * 1000) / 1000');
            s.addBackground(@subseq, 0.4);
            test.verifyEqual(SeqVal.toString(s.curTime), 'round(g(0) * 0.2 * 1000) / 1000');
            test.verifyEqual(SeqVal.toString(s.totalTime()), ...
                             'max(round(g(0) * 0.2 * 1000), 400 + round(g(0) * 0.2 * 1000)) / 1000');
            test.verifyEqual([toString(s) char(10)], fileread([test.path '/seq2.txt']));
            s.waitBackground();
            test.verifyEqual(SeqVal.toString(s.totalTime()), ...
                             'max(round(g(0) * 0.2 * 1000), 400 + round(g(0) * 0.2 * 1000)) / 1000');
            test.verifyEqual([toString(s) char(10)], fileread([test.path '/seq2_waitbg.txt']));
            % Make sure the second wait is no-op
            s.waitBackground();
            test.verifyEqual(SeqVal.toString(s.totalTime()), ...
                             'max(round(g(0) * 0.2 * 1000), 400 + round(g(0) * 0.2 * 1000)) / 1000');
            test.verifyEqual([toString(s) char(10)], fileread([test.path '/seq2_waitbg.txt']));
            s.waitAll();
            test.verifyEqual(SeqVal.toString(s.totalTime()), ...
                             'max(round(g(0) * 0.2 * 1000), 400 + round(g(0) * 0.2 * 1000)) / 1000');
            test.verifyEqual([toString(s) char(10)], fileread([test.path '/seq2_waitbg.txt']));
            % Make sure the second wait is no-op
            s.waitAll();
            test.verifyEqual(SeqVal.toString(s.totalTime()), ...
                             'max(round(g(0) * 0.2 * 1000), 400 + round(g(0) * 0.2 * 1000)) / 1000');
            test.verifyEqual([toString(s) char(10)], fileread([test.path '/seq2_waitbg.txt']));
            bytes = serialize(s);
            test.verifyEqual(serialize(s), bytes);
            test.verifyEqual(bytes, int8(test.read_json([test.path '/seq2_waitbg.json']))');
        end
        function test3(test)
            s = ExpSeq();
            g = s.newGlobal();
            s.add('Device2/CH2', g + 2);
            function subseq(s, len)
                m = s.addMeasure('Device2/CH2');
                s.addStep(len) ...
                 .add('Device2/CH2', 3.4) ...
                 .add('Device3/CH1', @(t) t * 5 - m);
                s.add('Device2/CH2', 0) ...
                 .add('Device3/CH1', 0);
            end
            s.addStep(@subseq, g * 0.2);
            test.verifyEqual(SeqVal.toString(s.curTime), 'round(g(0) * 0.2 * 1000) / 1000');
            test.verifyEqual(SeqVal.toString(s.totalTime()), 'round(g(0) * 0.2 * 1000) / 1000');
            s.addBackground(@subseq, 0.4);
            test.verifyEqual(SeqVal.toString(s.curTime), 'round(g(0) * 0.2 * 1000) / 1000');
            test.verifyEqual(SeqVal.toString(s.totalTime()), ...
                             'max(round(g(0) * 0.2 * 1000), 400 + round(g(0) * 0.2 * 1000)) / 1000');
            test.verifyEqual([toString(s) char(10)], fileread([test.path '/seq2.txt']));
            % waitBackground and waitAll should have the same effect here.
            % (and short background step created with `s.add` should be ignored in both cases)
            s.waitAll();
            test.verifyEqual(SeqVal.toString(s.totalTime()), ...
                             'max(round(g(0) * 0.2 * 1000), 400 + round(g(0) * 0.2 * 1000)) / 1000');
            test.verifyEqual([toString(s) char(10)], fileread([test.path '/seq2_waitbg.txt']));
            s.waitAll();
            test.verifyEqual(SeqVal.toString(s.totalTime()), ...
                             'max(round(g(0) * 0.2 * 1000), 400 + round(g(0) * 0.2 * 1000)) / 1000');
            test.verifyEqual([toString(s) char(10)], fileread([test.path '/seq2_waitbg.txt']));
            s.waitBackground();
            test.verifyEqual(SeqVal.toString(s.totalTime()), ...
                             'max(round(g(0) * 0.2 * 1000), 400 + round(g(0) * 0.2 * 1000)) / 1000');
            test.verifyEqual([toString(s) char(10)], fileread([test.path '/seq2_waitbg.txt']));
            s.waitBackground();
            test.verifyEqual(SeqVal.toString(s.totalTime()), ...
                             'max(round(g(0) * 0.2 * 1000), 400 + round(g(0) * 0.2 * 1000)) / 1000');
            test.verifyEqual([toString(s) char(10)], fileread([test.path '/seq2_waitbg.txt']));
            bytes = serialize(s);
            test.verifyEqual(serialize(s), bytes);
            test.verifyEqual(bytes, int8(test.read_json([test.path '/seq2_waitbg.json']))');
        end
        function test4(test)
            s = ExpSeq();
            g = s.newGlobal();
            step = s.conditional(false).addBackground(g * 2, g + 2);
            step.add('Device0/CH9', g / 2);
            test.verifyEqual(s.curTime, 0);
            test.verifyEqual(s.totalTime(), 0);
            test.verifyEqual([toString(s) char(10)], fileread([test.path '/seq3.txt']));
            s.waitFor(step);
            test.verifyEqual(s.curTime, 0);
            test.verifyEqual(s.totalTime(), 0);
            test.verifyEqual([toString(s) char(10)], fileread([test.path '/seq3_waitfor.txt']));
            s.waitBackground();
            test.verifyEqual(s.curTime, 0);
            test.verifyEqual(s.totalTime(), 0);
            test.verifyEqual([toString(s) char(10)], fileread([test.path '/seq3_waitfor.txt']));
            s.waitAll();
            test.verifyEqual(s.curTime, 0);
            test.verifyEqual(s.totalTime(), 0);
            test.verifyEqual([toString(s) char(10)], fileread([test.path '/seq3_waitfor.txt']));
            bytes = serialize(s);
            test.verifyEqual(serialize(s), bytes);
            test.verifyEqual(bytes, int8(test.read_json([test.path '/seq3_waitfor.json']))');
        end
        function test5(test)
            s = ExpSeq();
            g = s.newGlobal();
            step = s.addFloating(5);
            s.wait(g * 4);
            step.setTime(endTime(s));
            s.waitFor(step);
            test.verifyEqual([toString(s) char(10)], fileread([test.path '/seq4.txt']));
            test.verifyEqual(SeqVal.toString(s.totalTime()), ...
                             'max(round(g(0) * 4 * 1000), 5000 + round(g(0) * 4 * 1000)) / 1000');
            bytes = serialize(s);
            test.verifyEqual(serialize(s), bytes);
            test.verifyEqual(bytes, int8(test.read_json([test.path '/seq4.json']))');
        end
        function test6(test)
            s = ExpSeq();
            g = s.newGlobal();
            step = s.addFloating(5);
            s.wait(g * 4);
            step.setEndTime(endTime(s));
            s.waitFor(step);
            test.verifyEqual([toString(s) char(10)], fileread([test.path '/seq5.txt']));
            test.verifyEqual(SeqVal.toString(s.totalTime()), 'round(g(0) * 4 * 1000) / 1000');
            bytes = serialize(s);
            test.verifyEqual(serialize(s), bytes);
            test.verifyEqual(bytes, int8(test.read_json([test.path '/seq5.json']))');
        end
        function test7(test)
            s = ExpSeq();
            g = s.newGlobal();
            step = s.addFloating(5);
            s.wait(g * 4);
            s.alignEnd(step);
            test.verifyEqual([toString(s) char(10)], fileread([test.path '/seq6.txt']));
            test.verifyEqual(SeqVal.toString(s.totalTime()), ...
                             'max(round(g(0) * 4 * 1000), 5000 + round(g(0) * 4 * 1000)) / 1000');
            bytes = serialize(s);
            % serialization is not repeatable here since each time a new ed time is created
            % and serialized.
            % test.verifyEqual(serialize(s), bytes);
            test.verifyEqual(bytes, int8(test.read_json([test.path '/seq6.json']))');
        end
    end
end
