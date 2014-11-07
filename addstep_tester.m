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

function addstep_tester(seq, len)
  if nargin < 2
    len = 1
  end
  seq.addStep(len) ...
     .addPulse('1', 3) ...
     .addPulse('1', jumpTo(2, len / 2));
  seq.addStep(len, 1) ...
     .addPulse('1', 2);
end
