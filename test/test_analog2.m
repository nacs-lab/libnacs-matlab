%% Copyright (c) 2014-2014, Yichao Yu <yyc1992@gmail.com>
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

s = ExpSeq('test_analog');

s.add('FPGA1/TTL27', 0);
s.add('Dev2/4', 0.5);

s.addStep(100e-3, 1000e-6) ...
 .add('Dev2/4', 1) ...
 .add('FPGA1/TTL27', 0);

s.add('Dev2/4', 0);
s.add('FPGA1/TTL27', 1);

s.addStep(10e-6, 10e-6) ...
 .add('FPGA1/TTL27', 0) ...
 .add('Dev2/4', linearRamp(0, 10));

s.generate();
