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

classdef ExpSeq < ExpSeqBase
  properties(Access=private)
    driver_names;
    drivers;

    name_map;
  end

  methods
    function self = ExpSeq(name)
      if nargin < 1
        name = 'seq';
      elseif ~ischar(name)
        error('Sequence name must be a string.');
      end
      self = self@ExpSeqBase(name);
      self.drivers = containers.Map();
      self.name_map = containers.Map();
    end

    function cid = translateChannel(self, name)
      name = self.transChnName(name);
      cpath = strsplit(name, '/');
      did = cpath{1};
      driver = self.loadDriver(did);
      cid = translateChannel@ExpSeqBase(self, name);
      driver.initChannel(cid);
    end

    function cid = findChannelId(self, name)
      name = self.transChnName(name);
      cid = findChannelId@ExpSeqBase(self, name);
    end
  end

  methods(Access=private)
    function driver = loadDriver(self, did)
      %% TODO
    end

    function res = transChnName(self, name)
      try
        res = self.name_map(name);
      catch
        cpath = strsplit(name, '/');
        self.name_map(name) = [];
        if self.channelAlias.isKey(cpath{1})
          cpath{1} = self.channelAlias(cpath{1});
          res = self.transChnName(strjoin(cpath, '/'));
        else
          res = name;
        end
        self.name_map(name) = res;
        return;
      end
      if isempty(res)
        error('Alias loop detected: %s.', name);
      end
    end
  end

  %% TODO translateChannel
  %% getDefault
  %% findDriver
end
