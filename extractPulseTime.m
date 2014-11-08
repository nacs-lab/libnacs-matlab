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

function res = extractPulseTime(seq, cids)
  if ischar(cids)
    cids = {cids};
  end
  res = {};
  for cid = cids
    pulses = seq.getPulses(cid);
    for i = 1:size(pulses, 1)
      pulse = pulses(i, :);
      pulse_obj = pulse{3};
      toffset = pulse{4};
      step_len = pulse{5};
      dirty_times = pulse_obj.dirtyTimes(step_len);
      if ~isempty(dirty_times)
        for t = dirty_times
          res = [res; {t + toffset, timeType.Dirty, pulse_obj, ...
                       toffset, step_len, cid, pulse_obj.getID()}];
        end
      else
        tstart = pulse{1} + toffset;
        tlen = pulse{2};
        res = [res; {tstart, timeType.Start, pulse_obj, ...
                     toffset, step_len, cid, pulse_obj.getID()}];
        res = [res; {tstart + tlen, timeType.End, pulse_obj, ...
                     toffset, step_len, cid, pulse_obj.getID()}];
      end
    end
  end
  if ~isempty(res)
    res = sortrows(res, [1, 2, 7]);
  end
end
