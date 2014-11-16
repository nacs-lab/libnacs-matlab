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

classdef test_getvalues < ExpSeqBase
  properties
    vals;
  end

  methods
    function self = test_getvalues()
      self = self@ExpSeqBase();
      self.addStep(1) ...
          .addPulse('1', linearRamp(10, 1)) ...
          .addPulse('3', linearRamp(20, 2));

      self.addStep(4) ...
          .addPulse('1', rampTo(10)) ...
          .addPulse('2', rampTo(20));

      self.addStep(1, 1) ...
          .addPulse('1', rampTo(0)) ...
          .addPulse('3', rampTo(-2));

      self.addStep('addstep_tester');
      self.addStep(1, @addstep_tester);
      self.addStep(1, 'addstep_tester', 2);

      self.vals = self.getValues(1e-6, self.translateChannel('1'), ...
                                 self.translateChannel('2'), ...
                                 self.translateChannel('3'));
    end
  end
end
