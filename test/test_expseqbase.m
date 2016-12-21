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

classdef test_expseqbase < ExpSeqBase
  methods
    function self = test_expseqbase()
      self = self@ExpSeqBase();
      self.addStep(1) ...
          .add('1', linearRamp(10, 1)) ...
          .add('3', linearRamp(20, 2));

      self.addStep(4) ...
          .add('1', rampTo(10)) ...
          .add('2', rampTo(20));

      self.addStep(1, 1) ...
          .add('1', rampTo(0)) ...
          .add('3', rampTo(-2));

      self.addStep('addstep_tester');
      self.addStep(1, @addstep_tester);
      self.addStep(1, 'addstep_tester', 2);

      pulses1 = self.getPulses(self.translateChannel('1'));
      pulses2 = self.getPulses(self.translateChannel('2'));
      pulses3 = self.getPulses(self.translateChannel('3'));

      assert(size(pulses1, 1) == 12);
      assert(size(pulses2, 1) == 1);
      assert(size(pulses3, 1) == 2);

      pulses1_expected = {{0, 1, 0, 1}, ...
                          {1, 4, 1, 4}, ...
                          {6, 1, 6, 1}, ...
                          {7, 0, 7, 1}, ...
                          {7.5, 0, 7, 1}, ...
                          {9, 0, 9, 1}, ...
                          {11, 0, 11, 1}, ...
                          {11.5, 0, 11, 1}, ...
                          {13, 0, 13, 1}, ...
                          {15, 0, 15, 2}, ...
                          {16, 0, 15, 2}, ...
                          {18, 0, 18, 2}};

      for i = 1:size(pulses1, 1)
        assert(pulses1{i, 1} == pulses1_expected{i}{1});
        assert(pulses1{i, 2} == pulses1_expected{i}{2});
        assert(pulses1{i, 4} == pulses1_expected{i}{3});
        assert(pulses1{i, 5} == pulses1_expected{i}{4});
        assert(pulses1{i, 6} == self.translateChannel('1'));
      end

      pulses2_expected = {{1, 4, 1, 4}};

      for i = 1:size(pulses2, 1)
        assert(pulses2{i, 1} == pulses2_expected{i}{1});
        assert(pulses2{i, 2} == pulses2_expected{i}{2});
        assert(pulses2{i, 4} == pulses2_expected{i}{3});
        assert(pulses2{i, 5} == pulses2_expected{i}{4});
        assert(pulses2{i, 6} == self.translateChannel('2'));
      end

      pulses3_expected = {{0, 1, 0, 1}, ...
                          {6, 1, 6, 1}};

      for i = 1:size(pulses3, 1)
        assert(pulses3{i, 1} == pulses3_expected{i}{1});
        assert(pulses3{i, 2} == pulses3_expected{i}{2});
        assert(pulses3{i, 4} == pulses3_expected{i}{3});
        assert(pulses3{i, 5} == pulses3_expected{i}{4});
        assert(pulses3{i, 6} == self.translateChannel('3'));
      end
    end
  end
end
