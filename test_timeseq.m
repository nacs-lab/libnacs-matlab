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

classdef test_timeseq < TimeSeq
  methods
    function self = test_timeseq()
      self = self@TimeSeq();
      subseq1 = TimeSeq(self, 0);
      subseq2 = TimeSeq(self, 2);

      assert(self.globChannelAvailable('', 2) == 1);
      assert(self.globChannelAvailable('', 1) == 1);
      assert(self.globChannelAvailable('', 0) == 1);

      assert(subseq1.globChannelAvailable('', 2) == 1);
      assert(subseq1.globChannelAvailable('', 1) == 1);
      assert(subseq1.globChannelAvailable('', 0) == 1);

      assert(subseq2.globChannelAvailable('', 2) == 1);
      assert(subseq2.globChannelAvailable('', 1) == 1);
      assert(subseq2.globChannelAvailable('', 0) == 1);

      assert(isempty(self.getPulses('')));
      assert(isempty(subseq1.getPulses('')));
      assert(isempty(subseq2.getPulses('')));
    end
  end
end
