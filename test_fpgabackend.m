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
     .addPulse('FPGA1/DDS1/AMP', linearRamp(1, 0.1)) ...
     .addPulse('FPGA1/DDS3/FREQ', linearRamp(20e6, 2e6)) ...
     .addPulse('FPGA1/TTL1', 1);

  seq.addStep(4e-2) ...
     .addPulse('FPGA1/DDS1/FREQ', rampTo(10e6)) ...
     .addPulse('FPGA1/DDS2/FREQ', rampTo(20e6)) ...
     .addPulse('FPGA1/TTL1', jumpTo(1, 2e-2)) ...
     .addPulse('FPGA1/TTL1', jumpTo(0, 1e-2));

  seq.addStep(1e-2, 5) ...
     .addPulse('FPGA1/DDS1/FREQ', rampTo(0e6)) ...
     .addPulse('FPGA1/DDS1/AMP', rampTo(0.5)) ...
     .addPulse('FPGA1/DDS3/FREQ', rampTo(10e6)) ...
     .addPulse('FPGA1/TTL1', 0);

  backend = FPGABackend(seq);
  backend.initDev('FPGA1');
  backend.initChannel(seq.translateChannel('FPGA1/DDS1/FREQ'));
  backend.initChannel(seq.translateChannel('FPGA1/DDS2/FREQ'));
  backend.initChannel(seq.translateChannel('FPGA1/DDS3/FREQ'));
  backend.initChannel(seq.translateChannel('FPGA1/DDS1/AMP'));
  backend.initChannel(seq.translateChannel('FPGA1/DDS2/AMP'));
  backend.initChannel(seq.translateChannel('FPGA1/DDS3/AMP'));
  backend.initChannel(seq.translateChannel('FPGA1/DDS4/AMP'));
  backend.initChannel(seq.translateChannel('FPGA1/DDS5/AMP'));
  backend.initChannel(seq.translateChannel('FPGA1/DDS6/AMP'));
  backend.initChannel(seq.translateChannel('FPGA1/DDS7/AMP'));
  backend.initChannel(seq.translateChannel('FPGA1/DDS8/AMP'));
  backend.initChannel(seq.translateChannel('FPGA1/DDS9/AMP'));
  backend.initChannel(seq.translateChannel('FPGA1/DDS10/AMP'));
  backend.initChannel(seq.translateChannel('FPGA1/DDS11/AMP'));
  backend.initChannel(seq.translateChannel('FPGA1/DDS12/AMP'));
  backend.initChannel(seq.translateChannel('FPGA1/DDS13/AMP'));
  backend.initChannel(seq.translateChannel('FPGA1/DDS14/AMP'));
  backend.initChannel(seq.translateChannel('FPGA1/DDS15/AMP'));
  backend.initChannel(seq.translateChannel('FPGA1/DDS16/AMP'));
  backend.initChannel(seq.translateChannel('FPGA1/DDS17/AMP'));
  backend.initChannel(seq.translateChannel('FPGA1/DDS18/AMP'));

  backend.initChannel(seq.translateChannel('FPGA1/TTL1'));
  backend.initChannel(seq.translateChannel('FPGA1/TTL2'));
  backend.initChannel(seq.translateChannel('FPGA1/TTL3'));
  backend.initChannel(seq.translateChannel('FPGA1/TTL5'));

  backend.enableClockOut(100);
  backend.generate([seq.translateChannel('FPGA1/DDS1/FREQ'), ...
                    seq.translateChannel('FPGA1/DDS1/AMP'), ...
                    seq.translateChannel('FPGA1/DDS2/FREQ'), ...
                    seq.translateChannel('FPGA1/DDS3/FREQ'), ...
                    seq.translateChannel('FPGA1/DDS2/AMP'), ...
                    seq.translateChannel('FPGA1/DDS3/AMP'), ...
                    seq.translateChannel('FPGA1/DDS4/AMP'), ...
                    seq.translateChannel('FPGA1/DDS5/AMP'), ...
                    seq.translateChannel('FPGA1/DDS6/AMP'), ...
                    seq.translateChannel('FPGA1/DDS7/AMP'), ...
                    seq.translateChannel('FPGA1/DDS8/AMP'), ...
                    seq.translateChannel('FPGA1/DDS9/AMP'), ...
                    seq.translateChannel('FPGA1/DDS10/AMP'), ...
                    seq.translateChannel('FPGA1/DDS11/AMP'), ...
                    seq.translateChannel('FPGA1/DDS12/AMP'), ...
                    seq.translateChannel('FPGA1/DDS13/AMP'), ...
                    seq.translateChannel('FPGA1/DDS14/AMP'), ...
                    seq.translateChannel('FPGA1/DDS15/AMP'), ...
                    seq.translateChannel('FPGA1/DDS16/AMP'), ...
                    seq.translateChannel('FPGA1/DDS17/AMP'), ...
                    seq.translateChannel('FPGA1/DDS18/AMP'), ...
                    seq.translateChannel('FPGA1/TTL1')]);
  backend.getCmd();
end
