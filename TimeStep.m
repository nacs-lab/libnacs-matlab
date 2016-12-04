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

    function res = add(self, varargin)
      res = self.addPulse(varargin{:});
    end

    function ret = addPulse(self, name, pulse)
      ret = self;
      cid = self.translateChannel(name);
      if isnumeric(pulse) || islogical(pulse)
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
      pulse.id = self.nextPulseId();
      pulse_list{end + 1} = pulse;
      self.pulses{cid} = pulse_list;
    end
  end

  methods(Access=protected)
    function res = getPulsesRaw(self, cid)
      all_pulses = self.pulses;
      if size(all_pulses, 2) >= cid
        pulses = all_pulses{cid};
        if ~isempty(pulses)
          step_len = self.len;
          npulses = size(pulses, 2);
          res = cell(npulses, 6);
          for i = 1:npulses
            pulse = pulses{i};
            [tstart, tlen] = pulse.timeSpan(step_len);
            res(i, :) = {tstart, tlen, pulse, 0, step_len, cid};
          end
        else
          res = {};
        end
      else
        res = {};
      end
    end
  end
end
