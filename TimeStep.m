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
  properties
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

    function ret = add(self, name, pulse)
      ret = self;
      if isnumeric(name)
        cid = name;
      else
        cid = translateChannel(self, name);
      end
      if isnumeric(pulse) || islogical(pulse)
        if ~isscalar(pulse)
          error('Pulse cannot be a non-scalar value.');
        end
        pulse = jumpTo(pulse);
      elseif ~isa(pulse, 'PulseBase')
        %% Treat as function
        pulse = FuncPulse(pulse);
      end
      if size(self.pulses, 2) >= cid && ~isempty(self.pulses{cid})
          error('Overlapping pulses');
      end
      self.pulses{cid} = pulse;
    end
  end

  methods(Access=protected)
    function res = getPulsesRaw(self, cid)
      % Caller checks that pulses exists
      step_len = self.len;
      pulse = self.pulses{cid};
      res = {0, step_len, pulse};
    end
  end
end
