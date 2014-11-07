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

function test_fpgabackend()
  backend = fpgaBackend();
  backend.initDev('FPGA1');
  backend.initChannel('FPGA1', 'TTL1');
  backend.initChannel('FPGA1', 'TTL2');
  backend.initChannel('FPGA1', 'ttl3');
  backend.initChannel('FPGA1', 'ttl5');

  backend.initChannel('FPGA1', 'DDS5/freq');
  backend.initChannel('FPGA1', 'dds5/AMP');

  seq = expSeqBase();
  seq.addStep(1) ...
     .addPulse('FPGA1/dds1/freq', linearRamp(10, 1)) ...
     .addPulse('FPGA1/dds3/freq', linearRamp(20, 2));

  seq.addStep(4) ...
     .addPulse('FPGA1/dds1/freq', rampTo(10)) ...
     .addPulse('FPGA1/dds2/freq', rampTo(20));

  seq.addStep(1, 1) ...
     .addPulse('FPGA1/dds1/freq', rampTo(0)) ...
     .addPulse('FPGA1/dds3/freq', rampTo(10));

  backend.enableClockOut(100);
  backend.generate(seq, ['FPGA1/dds1/freq', 'FPGA1/dds2/freq', ...
                         'FPGA1/dds3/freq']);
  backend.getCmd()
end
