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
%% step1: [0, 2] cid1, cid3
%% step2:     [2, 5] cid1
%% step3:   [1, 3]   [6, 8] cid2

function test_timestep()
  tseq = timeSeq();
  timeStep(tseq, 2, 3) ...
          .addPulse('1', rampTo(10));

  timeStep(tseq, 0, 2) ...
          .addPulse('1', linearRamp(1, 2)) ...
          .addPulse('3', linearRamp(0, 1));

  timeStep(tseq, 1, 2) ...
          .addPulse('2', linearRamp(2, 3));

  timeStep(tseq, 6, 2) ...
          .addPulse('2', 4);

  pulses1 = tseq.getPulses('1');
  pulses2 = tseq.getPulses('2');
  pulses3 = tseq.getPulses('3');

  assert(size(pulses1, 1) == 2);
  assert(size(pulses2, 1) == 2);
  assert(size(pulses3, 1) == 1);

  assert(pulses1{1, 1} == 0);
  assert(pulses1{1, 2} == 2);
  assert(pulses1{1, 4} == 0);
  assert(pulses1{1, 5} == 2);

  assert(pulses1{2, 1} == 2);
  assert(pulses1{2, 2} == 3);
  assert(pulses1{2, 4} == 2);
  assert(pulses1{2, 5} == 3);


  assert(pulses2{1, 1} == 1);
  assert(pulses2{1, 2} == 2);
  assert(pulses2{1, 4} == 1);
  assert(pulses2{1, 5} == 2);

  assert(pulses2{2, 1} == 6);
  assert(pulses2{2, 2} == 0);
  assert(pulses2{2, 4} == 6);
  assert(pulses2{2, 5} == 2);


  assert(pulses3{1, 1} == 0);
  assert(pulses3{1, 2} == 2);
  assert(pulses3{1, 4} == 0);
  assert(pulses3{1, 5} == 2);
end
