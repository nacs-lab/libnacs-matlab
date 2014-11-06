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
        error('Time steps should have a fixed and positive length');
      end
    end

    function ret = addPulse(self, cid, func)
      %% @func has to be a function now, which will span the whole duration
      %% of the time step.
      %% TODO: also accept @func to be an object of certain class with
      %% methods to query values and the time period which it happens.
      %% This can also be implemented with nisted timeSeq's although it might
      %% be too much for this purpose and hard to support zero length pulse
      %% (jump value).

      %% TODO, check if cid is valid. (chaining to parent)
      ret = self;
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

    function res = getPulses(self, cid)
      %% Return a array of tuples (toffset, length, generator_function)
      %% the generator function should take 3 parameters:
      %%     time_in_pulse, length, old_val_before_pulse
      %% and should return the new value @time_in_pulse after the pulse starts.
      res = getPulses@timeSeq(self, cid);
      len = self.length();
      for key = self.pulses.keys()
        res = [res, {0; len; self.pulses(key)}]
      end
    end
  end
end
