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
%% step1: [0, 1] cid1, cid3
%% step2:       [1, 5] cid1, cid2
%% step3:             [6, 7] cid1, cid3
%% sub_seq1: step1:         [7, 8] cid1 * 2
%%           step2:               [9, 10] cid1
%% sub_seq2: step1:                      [11, 12] cid1 * 2
%%           step2:                              [13, 14] cid1
%% sub_seq3: step1:                                      [15, 17] cid1 * 2
%%           step2:                                             [18, 20] cid1

function test_expseqbase()
  seq = expSeqBase();
  seq.addStep(1) ...
     .addPulse('1', linearRamp(10, 1)) ...
     .addPulse('3', linearRamp(20, 2));

  seq.addStep(4) ...
     .addPulse('1', rampTo(10)) ...
     .addPulse('2', rampTo(20));

  seq.addStep(1, 1) ...
     .addPulse('1', rampTo(0)) ...
     .addPulse('3', rampTo(-2));

  seq.addStep('addstep_tester');
  seq.addStep(1, @addstep_tester);
  seq.addStep(1, 'addstep_tester', 2);

  pulses1 = tseq.getPulses('1');
  pulses2 = tseq.getPulses('2');
  pulses3 = tseq.getPulses('3');

  assert(size(pulses1, 1) == 12);
  assert(size(pulses2, 1) == 1);
  assert(size(pulses3, 1) == 2);

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
