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

classdef(Abstract) pulseBase < handle
  methods(Abstract=true)
    val = calcValue(self, t, len, old_val);
  end

  methods
    function avail = available(self, t, len)
      [tstart, tlen] = self.timeSpan(len);
      %% The time availability check (in general) might miss the case when
      %% two jump want to happen at the same time. Ignore this issue for now.
      avail = ~(tstart < t && tstart + tlen > t);
    end
    function [tstart, tlen] = timeSpan(self, len)
      tstart = 0;
      tlen = len;
    end
    function times = dirtyTime(self)
      times = [];
    end
  end
end
