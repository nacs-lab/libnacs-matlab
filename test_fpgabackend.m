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
  backend = FPGABackend();
  backend.initDev('FPGA1');
  backend.initChannel('FPGA1', 'TTL1');
  backend.initChannel('FPGA1', 'TTL2');
  backend.initChannel('FPGA1', 'ttl3');
  backend.initChannel('FPGA1', 'ttl5');

  backend.initChannel('FPGA1', 'DDS5/FREQ');
  backend.initChannel('FPGA1', 'DDS5/AMP');

  seq = ExpSeqBase();
  seq.addStep(1e-3) ...
     .addPulse('FPGA1/DDS1/FREQ', linearRamp(10, 1)) ...
     .addPulse('FPGA1/DDS3/FREQ', linearRamp(20, 2));

  seq.addStep(4e-3) ...
     .addPulse('FPGA1/DDS1/FREQ', rampTo(10)) ...
     .addPulse('FPGA1/DDS2/FREQ', rampTo(20));

  seq.addStep(1e-3, 1e-3) ...
     .addPulse('FPGA1/DDS1/FREQ', rampTo(0)) ...
     .addPulse('FPGA1/DDS3/FREQ', rampTo(10));

  backend.enableClockOut(100);
  backend.generate(seq, {'FPGA1/DDS1/FREQ', 'FPGA1/DDS2/FREQ', ...
                         'FPGA1/DDS3/FREQ'});
  backend.getCmd()
end
