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

classdef (Sealed) jumpTo < PulseBase
    %jumpTo is a subclass of PulseBase. PulseBase only has property id
    %(number). jumpTo stores the value for the jump. The PulseBase
    %objects are stored in the TimeStep.pulses{cid} property, where cid is
    %the channel id for the jump.

  properties
    %PulseBase properties:  id = 0;
    val;  %the value to jump to
  end

  methods
      %%
    function s = toString(self)
      s = sprintf('jumpTo(val=%f)', self.val);
    end

    function self = jumpTo(v)
      self = self@PulseBase();
      self.val = v;
    end

    %%
    function val = calcValue(self, t, ~, old_val)
        %
      if isnumeric(old_val) || islogical(old_val)
        vals = [self.val, old_val];
        val = vals((t < 0) + 1);
      else
        if t < 0
          val = old_val;
        else
          val = self.val;
        end
      end
    end
  end
end
