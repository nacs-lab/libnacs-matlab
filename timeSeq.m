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
    len = 0;
  end

  methods
    function self = timeSeq(parent, toffset, len)
      if nargin < 1
        self.logger = nacsLogger('seq');
      elseif nargin < 2
        error('Creating sub time sequence without a time offset');
      else
        self.parent = parent;
        self.tOffset = toffset;

        self.logger = parent.logger;
        parent.addSubSeqs(self, toffset);
        if nargin >= 3
          self.len = len;
        end
      end
    end

    function avail = globChannelAvailable(self, cid, t, dt)
      if nargin < 4
        dt = 0;
      end
      if self.hasParent()
        avail = self.parent.globChannelAvailable(cid, t + self.tOffset, dt);
      else
        avail = self.channelAvailable(cid, t, dt);
      end
    end
  end

  methods(Access=private)
    function res = hasParent(self)
      res = isobject(self.parent);
    end
  end

  methods(Access=protected)
    function len = length(self)
      len = self.len;
    end

    function addSubSeqs(self, sub_seq, toffset)
      len = self.length();
      if len > 0
        sub_len = sub_seq.length();
        if sub_len <= 0
          error('Cannot add a variable length sequence to' ...
                  'a fixed length sequence');
        elseif toffset > len
          error('Too big sub-sequence time offset.');
        elseif toffset + sub_len > len
          error('Too long sub-sequence.');
        end
      end
      self.subSeqs = [self.subSeqs, {toffset; sub_seq}];
    end

    function avail = channelAvailable(self, cid, t, dt)
      if nargin < 4
        dt = 0;
      end
      avail = 1;
      len = self.length();
      if len > 0 && t < len
        return;
      end
      for seq_t = self.subSeqs
        toffset = seq_t{1};
        sub_seq = seq_t{2};
        sub_t = t - toffset;
        if sub_t >= 0 && ~sub_seq.channelAvailable(cid, sub_t, dt)
          avail = 0;
          return;
        end
      end
    end

    function res = getPulses(self, cid)
      %% Return a array of tuples (toffset, length, generator_function)
      %% the generator function should take 3 parameters:
      %%     time_in_pulse, length, old_val_before_pulse
      %% and should return the new value @time_in_pulse after the pulse starts.
      res = [];
      for seq_t = self.subSeqs
        seq_toffset = seq_t{1};
        sub_seq = seq_t{2};

        for sub_tuple = sub_seq.getPulses(cid)
          pulse_toffset = sub_tuple{1};
          pulse_len = sub_tuple{2};
          pulse_func = sub_tuple{3};

          res = [res, {pulse_toffset + seq_toffset; pulse_len, pulse_func}];
        end
      end
    end
  end
end
