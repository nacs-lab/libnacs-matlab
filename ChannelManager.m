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

classdef ChannelManager < handle
    %A ChannelManager object is set as ExpSeq.chn_manager

  properties
    channels = {};
  end
  properties(Access=private)
    cid_map;
  end

  methods
      %%
    function self = ChannelManager()
      self.cid_map = containers.Map();
    end

    %%
    function id = findId(self, name)
      try
        id = self.cid_map(name);
      catch
        id = 0;
      end
    end

    %%
    function id = getId(self, name)
      try
        id = self.cid_map(name);
      catch
        id = size(self.channels, 2) + 1;
        self.channels{id} = name;
        self.cid_map(name) = id;
      end
    end
  end
end
