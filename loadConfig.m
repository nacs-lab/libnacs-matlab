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

classdef loadConfig < handle
  properties(Access=private)
    name_map;
  end
  properties
    logDir;
    pulseDrivers;
    channelAlias;
    defaultVals;
    consts;

    fpgaUrls;

    niClocks;
    niStart;
  end

  methods
    function self = loadConfig()
      self.name_map = containers.Map();
      self.load();
    end

    function load(self)
      fpgaUrls = containers.Map();
      pulseDrivers = containers.Map();
      [path, ~, ~] = fileparts(mfilename('fullpath'));
      logDir = fullfile(path, '..', 'log');
      channelAlias = containers.Map();
      defaultVals = containers.Map();
      niClocks = containers.Map();
      niStart = containers.Map();
      consts = containers.Map();

      nacsConfig();

      self.logDir = logDir;
      self.fpgaUrls = fpgaUrls;
      self.niClocks = niClocks;
      self.niStart = niStart;
      self.consts = consts;

      for key = channelAlias.keys()
        key = key{:};

        if ~isempty(strfind(key, '/'))
          error('Channel name should not have "/"');
        end

        matches = regexp(channelAlias(key), '^(.*[^/])/*$', 'tokens');
        if ~isempty(matches)
          channelAlias(key) = matches{1}{1};
        end
      end
      self.channelAlias = channelAlias;

      for key = pulseDrivers.keys()
        key = key{:};
        if ~ischar(pulseDrivers(key))
          error('pulseDrivers should be a string');
        end
      end
      self.pulseDrivers = pulseDrivers;

      self.defaultVals = containers.Map();
      for key = defaultVals.keys()
        key = key{:};
        name = self.translateChannel(key);
        if self.defaultVals.isKey(name)
          error('Conflict default values for channel "%s" (%s).', key, name);
        end
        self.defaultVals(name) = defaultVals(key);
      end
    end

    function res = translateChannel(self, name)
      try
        res = self.name_map(name);
      catch
        cpath = strsplit(name, '/');
        self.name_map(name) = [];
        if self.channelAlias.isKey(cpath{1})
          cpath{1} = self.channelAlias(cpath{1});
          res = self.translateChannel(strjoin(cpath, '/'));
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
end
