%% Copyright (c) 2018-2018, Yichao Yu <yyc1992@gmail.com>
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

g = ScanGroup();
assert(g.groupsize() == 1);

g().a = 1;
b = g();
b.b = 2;
assert(g.nseq() == 1);

b.c.scan([1, 2, 3]);
assert(g.nseq() == 3);

g(1).c = 3;
assert(g.nseq() == 1);

b.d.scan(2, [1, 2]);
assert(g.nseq() == 2);

s2 = g(2);
s2.d = 0;
assert(g.groupsize() == 2);
assert(g.scansize(1) == 2);
assert(g.scansize(2) == 3);
assert(g.nseq() == 5);
assert(isequaln(g.getseq(1), struct('c', 3, 'a', 1, 'b', 2, 'd', 1)));
assert(isequaln(g.getseq(2), struct('c', 3, 'a', 1, 'b', 2, 'd', 2)));
assert(isequaln(g.getseq(3), struct('d', 0, 'a', 1, 'b', 2, 'c', 1)));
assert(isequaln(g.getseq(4), struct('d', 0, 'a', 1, 'b', 2, 'c', 2)));
assert(isequaln(g.getseq(5), struct('d', 0, 'a', 1, 'b', 2, 'c', 3)));

g(end).k.a.b.c = 2;
assert(g.nseq() == 5);
kstruct = struct('a', struct('b', struct('c', 2)));
assert(isequaln(g.getseq(3), struct('d', 0, 'k', kstruct, 'a', 1, 'b', 2, 'c', 1)));

g2 = [g, g];
assert(g2.nseq() == 10);
for i=1:5
    assert(isequaln(g.getseq(i), g2.getseq(i)));
    assert(isequaln(g.getseq(i), g2.getseq(i + 5)));
end

g.setbase(2, 1);
assert(g.groupsize() == 2);
assert(g.scansize(1) == 2);
assert(g.scansize(2) == 1);
assert(g.nseq() == 3);
assert(isequaln(g.getseq(1), struct('c', 3, 'a', 1, 'b', 2, 'd', 1)));
assert(isequaln(g.getseq(2), struct('c', 3, 'a', 1, 'b', 2, 'd', 2)));
assert(isequaln(g.getseq(3), struct('d', 0, 'k', kstruct, 'c', 3, 'a', 1, 'b', 2)));

assert(isequaln(g.dump(), ...
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
                       'runparam', struct())));

g3 = ScanGroup.load(g.dump());
assert(g3.nseq() == 3);
assert(isequaln(g3.getseq(1), struct('c', 3, 'a', 1, 'b', 2, 'd', 1)));
assert(isequaln(g3.getseq(2), struct('c', 3, 'a', 1, 'b', 2, 'd', 2)));
assert(isequaln(g3.getseq(3), struct('d', 0, 'k', kstruct, 'c', 3, 'a', 1, 'b', 2)));

rp = runp(g);
g.runp().a = 3;
rp.b = 2;
assert(g.runp().a == 3);
assert(g.runp().b == 2);
