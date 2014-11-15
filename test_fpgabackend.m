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
  seq = ExpSeqBase();
  seq.addStep(1e-2) ...
     .addPulse('FPGA1/DDS1/FREQ', linearRamp(10e6, 1e6)) ...
     .addPulse('FPGA1/DDS3/FREQ', linearRamp(20e6, 2e6));

  seq.addStep(4e-2) ...
     .addPulse('FPGA1/DDS1/FREQ', rampTo(10e6)) ...
     .addPulse('FPGA1/DDS2/FREQ', rampTo(20e6));

  seq.addStep(1e-2, 5) ...
     .addPulse('FPGA1/DDS1/FREQ', rampTo(0e6)) ...
     .addPulse('FPGA1/DDS3/FREQ', rampTo(10e6));

  backend = FPGABackend(seq);
  backend.initDev('FPGA1');
  backend.initChannel(seq.translateChannel('FPGA1/DDS1/FREQ'));
  backend.initChannel(seq.translateChannel('FPGA1/DDS2/FREQ'));
  backend.initChannel(seq.translateChannel('FPGA1/DDS3/FREQ'));

  backend.initChannel(seq.translateChannel('FPGA1/TTL2'));
  backend.initChannel(seq.translateChannel('FPGA1/TTL3'));
  backend.initChannel(seq.translateChannel('FPGA1/TTL5'));

  backend.enableClockOut(100);
  backend.generate([seq.translateChannel('FPGA1/DDS1/FREQ'), ...
                    seq.translateChannel('FPGA1/DDS2/FREQ'), ...
                    seq.translateChannel('FPGA1/DDS3/FREQ')]);
  backend.getCmd()
end
