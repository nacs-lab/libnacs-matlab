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

classdef NiDACBackend < PulseBackend
  properties(Hidden, Access=private)
    dry_run = false;
    session;
    nicid_count = 1;
    cid_map;
    clock_connected;
    cids;
  end

  methods
    function self = NiDACBackend(seq, dry_run)
      self = self@PulseBackend(seq);
      if nargin > 1
        self.dry_run = dry_run;
      else
        self.dry_run = false;
      end
      if ~self.dry_run
        self.session = daq.createSession('ni');
        self.session.Rate = 5e5;
      end
      self.clock_connected = containers.Map();
    end

    function val = getPriority(self)
      val = 1;
    end

    function initDev(self, did)
    end

    function initDevLate(self, did)
      if ~self.clock_connected.isKey(did)
        self.clock_connected(did) = true;
        fpgadriver = self.seq.findDriver('FPGABackend');
        fpgadriver.enableClockOut(101);
        if ~self.dry_run
          self.session.addClockConnection('external', ...
                                          [did, '/', ...
                                           self.seq.config.niClocks(did)], ...
                                          'ScanClock');
        end
      end
    end

    function initChannel(self, cid)
      if size(self.cid_map, 2) >= cid && self.cid_map(cid) > 0
        return;
      end
      name = self.seq.channelName(cid);
      cpath = strsplit(name, '/');
      if size(cpath, 2) ~= 2
        error('Invalid NI channel "%s".', name);
      end
      dev_name = cpath{1};
      matches = regexp(cpath{2}, '^([1-9]\d*|0)$', 'tokens');
      if isempty(matches)
        error('No NI channel number');
      end
      output_id = str2double(matches{1}{1});

      if self.dry_run
        nicid = self.nicid_count;
        self.nicid_count = self.nicid_count + 1;
      else
        [~, nicid] = self.session.addAnalogOutputChannel(dev_name, ...
                                                         output_id, 'Voltage');
        self.initDevLate(dev_name);
      end
      self.cid_map(cid) = nicid;
      self.cids(nicid) = cid;
    end

    function generate(self, cids)
      if ~all(sort(cids), sort(self.cids))
        error('Channel mismatch.');
      end
      data = self.seq.getValues(2e-6, self.cids);
      if ~self.dry_run
        self.session.queueOutputData(data);
      end
    end

    function run(self)
      if ~self.dry_run
        self.session.startBackground();
      end
    end

    function wait(self)
      if ~self.dry_run
        self.session.wait();
      end
    end
  end
end
