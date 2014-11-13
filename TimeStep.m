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

classdef TimeStep < TimeSeq
  properties(Hidden, Access=private)
    pulses;
  end

  methods
    function self = TimeStep(varargin)
      self = self@TimeSeq(varargin{:});
      self.pulses = {};
      if self.len <= 0
        error('Time steps should have a fixed and positive length');
      end
    end

    function ret = addPulse(self, name, pulse)
      ret = self;
      cid = self.translateChannel(name);
      if ~self.globChannelAvailable(cid, 0, self.len)
        error('Overlaping pulses.');
      elseif isnumeric(pulse)
        if ~isscalar(pulse)
          error('Pulse cannot be a non-scalar value.');
        end
        pulse = jumpTo(pulse, 0);
      elseif ~isa(pulse, 'PulseBase')
        %% Treat as function
        pulse = FuncPulse(pulse);
      end
      if size(self.pulses, 2) < cid
        pulse_list = {};
      else
        pulse_list = self.pulses{cid};
      end
      pulse_list{end + 1} = pulse;
      self.pulses{cid} = pulse_list;
    end
  end

  methods(Access=protected)
    function avail = channelAvailable(self, cid, t, dt)
      if nargin < 4 || dt < 0
        dt = 0;
      end
      len = self.len;
      if t >= len || t + dt <= 0
        avail = true;
        return;
      elseif size(self.pulses, 2) >= cid
        pulses = self.pulses{cid};
        for i = 1:size(pulses, 2)
          pulse = pulses{i};
          if ~pulse.available(t, dt, len)
            avail = false;
            return;
          end
        end
      end
      avail = channelAvailable@TimeSeq(self, cid, t, dt);
    end

    function res = getPulsesRaw(self, cid)
      res = getPulsesRaw@TimeSeq(self, cid);
      if size(self.pulses, 2) >= cid
        step_len = self.len;
        pulses = self.pulses{cid};
        for i = 1:size(pulses, 2)
          pulse = pulses{i};
          [tstart, tlen] = pulse.timeSpan(step_len);
          res = [res; {tstart, tlen, pulse, 0, step_len, cid}];
        end
      end
    end
  end
end
