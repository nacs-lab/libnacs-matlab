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

classdef(Abstract) PulseBackend < handle
  properties(Access=protected)
    seq;
  end

  methods(Abstract=true)
    initDev(self, did); % Check and add device
    initChannel(self, cid); % Check and add channel
    generate(self, cids); % Generate sequence.
    run(self, rep); % Start sequence.
  end

  methods
    function self = PulseBackend(seq)
      self.seq = seq;
    end

    function val = getPriority(self)
      %% There's probably a better way to let the backend specify the necessary
      %% dependencies for running each functions. A simple priority is good
      %% enough for now.
      val = 0;
    end

    function prepare(self, cids)
      %% Prepare channels, connect clock etc.
    end

    function wait(self, rep)
      %% Wait for the sequence to finish.
    end
  end
end
