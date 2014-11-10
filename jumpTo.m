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

classdef jumpTo < PulseBase
  properties(Access=private)
    val;
    time;
  end

  methods
    function self = jumpTo(v, t)
      self = self@PulseBase();
      if nargin <= 1
        t = 0;
      elseif t < 0;
        error('Cannot jump value at negative time.');
      end
      self.val = v;
      self.time = t;
    end
    function [tstart, tlen] = timeSpan(self, ~)
      tstart = self.time;
      tlen = 0;
    end
    function times = dirtyTime(self, ~)
      times = [self.time];
    end
    function val = calcValue(self, t, ~, old_val)
      if t < self.time
        val = old_val;
      else
        val = self.val;
      end
    end
  end
end
