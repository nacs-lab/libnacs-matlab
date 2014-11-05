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

classdef timeSeq < handle
  properties(Hidden, Access=protected)
    logger;
  end
  properties(Hidden, Access=private)
    subSeqs = [];
    tOffset;
    parent = 0;
  end

  methods
    function self = timeSeq(parent, toffset)
      if nargin < 1
        self.logger = nacsLogger('seq');
      elseif nargin < 2
        error('Creating sub time sequence without a time offset');
      else
        self.parent = parent;
        self.tOffset = toffset;

        self.logger = parent.logger;
        parent.addSubSeqs(self, toffset);
      end
    end

    function avail = globChannelAvailable(self, cid, t)
      if self.hasParent()
        avail = self.parent.globChannelAvailable(cid, t + self.tOffset);
      else
        avail = self.channelAvailable(cid, t);
      end
    end
  end

  methods(Access=private)
    function res = hasParent(self)
      res = isobject(self.parent);
    end
  end

  methods(Access=protected)
    function addSubSeqs(self, sub_seq, toffset)
      self.subSeqs = [self.subSeqs, {toffset; sub_seq}];
    end

    function avail = channelAvailable(self, cid, t)
      avail = 1;
      for seq_t = self.subSeqs
        toffset = seq_t{1};
        sub_seq = seq_t{2};
        sub_t = t - toffset;
        if sub_t >= 0 && sub_seq.channelAvailable(cid, sub_t)
          avail = 0;
          break;
        end
      end
    end
  end
end
