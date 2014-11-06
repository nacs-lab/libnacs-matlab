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
      self = self@timeSeq(varargin{:});
      self.pulses = containers.Map();
      if self.length() <= 0
        error('Time steps should have a fixed and positive length');
      end
    end

    function ret = addPulse(self, cid, pulse)
      ret = self;
      if ~self.checkChannel(cid)
        error('Invalid Channel ID.');
      elseif ~self.globChannelAvailable(cid, 0, self.length())
        error('Overlaping pulses.');
      elseif isnumeric(pulse)
        if ~isscalar(pulse)
          error('Pulse cannot be a non-scalar value.');
        end
        pulse = jumpTo(pulse, 0);
      elseif ~isa(pulse, @pulseBase)
        %% Treat as function
        pulse = funcPulse(pulse);
      end
      if self.pulses.isKey(cid)
        pulse_list = self.pulses(cid);
      else
        pulse_list = [];
      end
      pulse_list = [pulse_list, pulse];
      self.pulses(cid) = pulse_list;
    end
  end

  methods(Access=protected)
    function avail = channelAvailable(self, cid, t, dt)
      if nargin < 4 || dt < 0
        dt = 0;
      end
      len = self.length();
      if t >= len || t + dt <= 0
        avail = 1;
        return;
      elseif self.pulses.isKey(cid)
        for pulse = self.pulses(cid)
          if ~pulse.available(len)
            avail = 0;
            return;
          end
        end
      end
      avail = channelAvailable@timeSeq(self, cid, t, dt);
    end

    function res = getPulsesRaw(self, cid)
      res = getPulsesRaw@timeSeq(self, cid);
      if self.pulses.isKey(cid)
        step_len = self.length();
        for pulse = self.pulses(cid)
          [tstart, tlen] = pulse.timeSpan(step_len);
          res = [res; {tstart, tlen, pulse, 0, step_len}];
        end
      end
    end
  end
end
