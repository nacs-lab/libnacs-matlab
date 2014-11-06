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

%% tseq:
%% subseq1: [0, 2] cid1, cid3
%% subseq2:     [2, 5] cid1
%% subseq3:   [1, 3] cid2

function test_timestep()
  tseq = timeSeq();
  step1 = timeStep(tseq, 0, 2);
  step2 = timeStep(tseq, 2, 3);
  step3 = timeStep(tseq, 1, 2);

  step1.addPulse('1', linearRamp(1, 2)) ...
       .addPulse('3', linearRamp(0, 1));

  step2.addPulse('1', rampTo(10));

  step3.addPulse('2', linearRamp(2, 3));

  pulses1 = tseq.getPulses('1');
  pulses2 = tseq.getPulses('2');
  pulses3 = tseq.getPulses('3');

  assert(length(pulses1) == 2);
  assert(length(pulses2) == 1);
  assert(length(pulses3) == 1);

  assert(pulses1{1, 1} == 0);
  assert(pulses1{1, 2} == 2);
  assert(pulses1{2, 1} == 2);
  assert(pulses1{2, 2} == 3);

  assert(pulses2{1, 1} == 1);
  assert(pulses2{1, 2} == 2);

  assert(pulses3{1, 1} == 0);
  assert(pulses3{1, 2} == 2);
end
