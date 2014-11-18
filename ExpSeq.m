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
    drivers;
    driver_cids;
    generated = false;
    default_override;
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
      self.driver_cids = containers.Map();
      self.name_map = containers.Map();
      self.default_override = {};
    end

    function cid = translateChannel(self, name)
      name = self.config.translateChannel(name);
      cpath = strsplit(name, '/');
      did = cpath{1};
      [driver, driver_name] = self.initDeviceDriver(did);
      cid = translateChannel@ExpSeqBase(self, name);
      driver.initChannel(cid);
      cur_cids = self.driver_cids(driver_name);
      self.driver_cids(driver_name) = [cur_cids, cid];
    end

    function cid = findChannelId(self, name)
      name = self.config.translateChannel(name);
      cid = findChannelId@ExpSeqBase(self, name);
    end

    function driver = findDriver(self, driver_name)
      try
        driver = self.drivers(driver_name);
      catch
        driver_func = str2func(driver_name);
        driver = driver_func(self);
        self.drivers(driver_name) = driver;
        self.driver_cids(driver_name) = [];
      end
    end

    function generate(self)
      if ~self.generated
        for key = self.drivers.keys()
          driver_name = key{:};
          driver = self.drivers(driver_name);
          cids = self.driver_cids(driver_name);
          driver.prepare(cids);
        end
        for key = self.drivers.keys()
          driver_name = key{:};
          driver = self.drivers(driver_name);
          cids = self.driver_cids(driver_name);
          driver.generate(cids);
        end
        self.generated = true;
      end
    end

    function run_async(self)
      self.generate();
      drivers = {};
      for driver = self.drivers.values()
        drivers = [drivers; {driver, -driver.getPriority()}];
      end
      if ~isempty(drivers)
        drivers = sortrows(drivers, [2]);
      end
      for i = 1:size(drivers, 1)
        drivers{i, 1}.run();
      end
    end

    function wait(self)
      drivers = {};
      for driver = self.drivers.values()
        drivers = [drivers; {driver, -driver.getPriority()}];
      end
      if ~isempty(drivers)
        drivers = sortrows(drivers, [2]);
      end
      for i = 1:size(drivers, 1)
        drivers{i, 1}.wait();
      end
    end

    function run(self)
      self.run_async();
      self.wait();
    end

    function res = setDefault(self, name, val)
      res = self;
      cid = self.translateChannel(name);
      self.default_override{cid} = val;
    end
  end

  methods(Access=protected)
    function val = getDefault(self, cid)
      try
        val = self.default_override{cid};
        if ~isempty(val)
          return;
        end
      catch
      end
      name = self.channelName(cid);
      try
        val = self.config.defaultVals(name);
      catch
        val = 0;
      end
    end
  end

  methods(Access=private)
    function [driver, driver_name] = initDeviceDriver(self, did)
      driver_name = self.config.pulseDrivers(did);
      driver = self.findDriver(driver_name);
      driver.initDev(did);
    end
  end
end
