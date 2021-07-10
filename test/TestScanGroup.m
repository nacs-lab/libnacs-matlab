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

classdef TestScanGroup < matlab.unittest.TestCase
    %% Test Method Block
    methods(Test)
        function dotest(test)
            g = ScanGroup();
            test.verifyEqual(g.groupsize(), 1);

            g().a = 1;
            b = g();
            b.b = 2;
            test.verifyEqual(g.nseq(), 1);

            b.c.scan(1) = [1, 2, 3];
            test.verifyEqual(g.nseq(), 3);

            g(1).c = 3;
            test.verifyEqual(g.nseq(), 1);

            b.d.scan(2) = [1, 2];
            test.verifyEqual(g.nseq(), 2);

            s2 = g(2);
            s2.d = 0;
            test.verifyEqual(g.groupsize(), 2);
            test.verifyEqual(g.scansize(1), 2);
            test.verifyEqual(g.scansize(2), 3);
            test.verifyEqual(g.nseq(), 5);
            test.verifyEqual(g.getseq(1), struct('c', 3, 'a', 1, 'b', 2, 'd', 1));;
            test.verifyEqual(g.getseq(2), struct('c', 3, 'a', 1, 'b', 2, 'd', 2));;
            test.verifyEqual(g.getseq(3), struct('d', 0, 'a', 1, 'b', 2, 'c', 1));;
            test.verifyEqual(g.getseq(4), struct('d', 0, 'a', 1, 'b', 2, 'c', 2));;
            test.verifyEqual(g.getseq(5), struct('d', 0, 'a', 1, 'b', 2, 'c', 3));;

            g(end).k.a.b.c = 2;
            test.verifyEqual(g.nseq(), 5);
            kstruct = struct('a', struct('b', struct('c', 2)));
            test.verifyEqual(g.getseq(3), struct('d', 0, 'k', kstruct, 'a', 1, 'b', 2, 'c', 1));;

            [x, y] = g.get_scan(2).c;
            test.verifyEqual(x, [1, 2, 3]);
            test.verifyEqual(y, 1);

            g2 = [g, g];
            test.verifyEqual(g2.nseq(), 10);
            for i = 1:5
                test.verifyEqual(g.getseq(i), g2.getseq(i));;
                test.verifyEqual(g.getseq(i), g2.getseq(i + 5));;
            end

            g3 = [g2(1), g2(2:end)];
            test.verifyEqual(g3.nseq(), 10);
            for i = 1:10
                test.verifyEqual(g2.getseq(i), g3.getseq(i));;
            end

            g.setbase(2, 1);
            test.verifyEqual(g.groupsize(), 2);
            test.verifyEqual(g.scansize(1), 2);
            test.verifyEqual(g.scansize(2), 1);
            test.verifyEqual(g.nseq(), 3);
            test.verifyEqual(g.getseq(1), struct('c', 3, 'a', 1, 'b', 2, 'd', 1));;
            test.verifyEqual(g.getseq(2), struct('c', 3, 'a', 1, 'b', 2, 'd', 2));;
            test.verifyEqual(g.getseq(3), struct('d', 0, 'k', kstruct, 'c', 3, 'a', 1, 'b', 2));;

            test.verifyEqual(fieldnames(g.get_scan(1)), {'c', 'a', 'b', 'd'});
            test.verifyEqual(fieldnames(g.get_scan(2)), {'d', 'k', 'c', 'a', 'b'});
            test.verifyEqual(fieldnames(g.get_scan(2).k), {'a'});

            [x, y] = g.get_scan(1).c;
            test.verifyEqual(x, 3);
            test.verifyEqual(y, 0);
            [x, y] = g.get_scan(1).d;
            test.verifyEqual(x, [1, 2]);;
            test.verifyEqual(y, 2);
            [x, y] = g.get_scan(2).k;
            test.verifyClass(x, 'SubProps');
            test.verifyEqual(y, -1);
            [x, y] = g.get_scan(2).e;
            test.verifyClass(x, 'SubProps');
            test.verifyEqual(y, -1);
            [x, y] = g.get_scan(2).e(2);
            test.verifyEqual(x, 2);
            test.verifyEqual(y, 0);
            [x, y] = g.get_scan(2).e;
            test.verifyClass(x, 'SubProps');
            test.verifyEqual(y, -1);

            test.verifyEqual(g.dump(), ...
                             struct('version', 1, ...
                                    'scans', struct('baseidx', {0, 1}, ...
                                                    'params', {struct('c', 3), ...
                                                               struct('d', 0, 'k', kstruct)}, ...
                                                    'vars', {struct('size', {}, 'params', {}), ...
                                                             struct('size', {}, 'params', {})}), ...
                                    'base', struct('params', struct('a', 1, 'b', 2), ...
                                                   'vars', struct('size', {3, 2}, ...
                                                                  'params', {struct('c', [1, 2, 3]), ...
                                                                             struct('d', [1, 2])})), ...
                                    'runparam', struct()));

            g3 = ScanGroup.load(g.dump());
            test.verifyEqual(g3.nseq(), 3);
            test.verifyEqual(g3.getseq(1), struct('c', 3, 'a', 1, 'b', 2, 'd', 1));;
            test.verifyEqual(g3.getseq(2), struct('c', 3, 'a', 1, 'b', 2, 'd', 2));;
            test.verifyEqual(g3.getseq(3), struct('d', 0, 'k', kstruct, 'c', 3, 'a', 1, 'b', 2));;
            test.verifyEqual(g3().a(), 1);
            test.verifyEqual(g3().b(), 2);
            test.verifyEqual(g3(1).c(), 3);
            test.verifyEqual(g3(2).d(), 0);
            test.verifyEqual(g3(2).k.a.b.c(), 2);
            g3(3) = g3(1);
            test.verifyEqual(g3.nseq(), 5);
            for i = 1:2
                test.verifyEqual(g3.getseq(i), g3.getseq(3 + i));;
            end
            g3(5) = g3(2);
            test.verifyEqual(g3.nseq(), 12);
            test.verifyEqual(g3.getseq(12), g3.getseq(3));;
            i = 1;
            for d = 1:2
                for c = 1:3
                    test.verifyEqual(g3.getseq(5 + i), struct('a', 1, 'b', 2, 'c', c, 'd', d));;
                    i = i + 1;
                end
            end
            g3().name = 'a long string';
            test.verifyEqual(g3.nseq(), 12);
            test.verifyEqual(g3.getseq(6), struct('a', 1, 'b', 2, 'c', 1, 'd', 1, 'name', 'a long string'));
            g3(4) = struct('c', 5, 'd', 10);
            test.verifyEqual(g3.nseq(), 7);
            test.verifyEqual(g3.getseq(6), struct('a', 1, 'b', 2, 'c', 5, 'd', 10, 'name', 'a long string'));

            rp = runp(g);
            g.runp().a = 3;
            rp.b = 2;
            test.verifyEqual(g.runp().a, 3);
            test.verifyEqual(g.runp().b, 2);

            clear p0;

            p0.A = 1;
            p0.B = linspace(10.1, 11, 10);

            p0(2).A = 2;

            g4 = ScanGroup.load(struct('version', 0, 'p', p0, 'scan', struct()));
            test.verifyEqual(g4.nseq(), 20);
            test.verifyEqual(g4.get_fixed(1), struct('A', 1));;
            test.verifyEqual(g4.get_fixed(2), struct('A', 2));;
            test.verifyEqual(g4.get_vars(1), struct('B', p0(1).B));;
            test.verifyEqual(g4.get_vars(1, 1), struct('B', p0(1).B));;
            test.verifyEqual(g4.get_vars(2), struct('B', p0(1).B));;
            test.verifyEqual(g4.get_vars(2, 1), struct('B', p0(1).B));;
            [val, path] = g4.get_scanaxis(1, 1);
            test.verifyEqual(val, p0(1).B);;
            test.verifyEqual(path, 'B');;
            [val, path] = g4.get_scanaxis(1, 1, 'B');
            test.verifyEqual(val, p0(1).B);;
            test.verifyEqual(path, 'B');;

            ary2 = (1:length(p0(1).B)) * 2.5;
            g4(2).a.b.c.d.scan(ary2);
            [val, path] = g4.get_scanaxis(2, 1, 'a.b.c.d');
            test.verifyEqual(val, ary2);;
            test.verifyEqual(path, 'a.b.c.d');;
        end
    end
end
