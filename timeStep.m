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

classdef timeStep < timeSeq
  properties(Hidden, Access=private)
    pulses;
  end

  methods
    function self = timeStep(varargin)
      self.pulses = containers.Map();
      self = self@timeSeq(varargin{:});
      if self.length() <= 0
        error('Time steps should have a fixed length');
      end
    end

    function addPulse(self, cid, func)
      if ~self.globChannelAvailable(cid, 0, self.length())
        error('Overlaping pulses.');
      end
      self.pulses(cid) = func;
    end
  end

  methods(Access=protected)
    function avail = channelAvailable(self, cid, t, dt)
      if nargin < 4 || dt < 0
        dt = 0;
      end
      if t >= self.length() || t + dt <= 0
        avail = 1;
        return;
      end
      if self.pulses.isKey(cid)
        avail = 0;
        return;
      end
      avail = channelAvailable@timeSeq(self, cid, t, dt);
    end
  end
end
