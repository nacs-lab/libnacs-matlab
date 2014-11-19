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
    session;
    cid_map;
    cids;
    data;
  end

  methods
    function self = NiDACBackend(seq)
      self = self@PulseBackend(seq);
      self.cid_map = {};
      self.cids = [];
    end

    function val = getPriority(self)
      val = 1;
    end

    function initDev(self, did)
      fpgadriver = self.seq.findDriver('FPGABackend');
      fpgadriver.enableClockOut(101);
    end

    function initChannel(self, cid)
      if size(self.cid_map, 2) >= cid && ~isempty(self.cid_map{cid})
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

      self.cid_map{cid} = {dev_name, output_id};
      self.cids(end + 1) = cid;
    end

    function connectClock(self, did)
      self.session.addClockConnection('External', ...
                                      [did, '/', ...
                                       self.seq.config.niClocks(did)], ...
                                      'ScanClock');
      self.session.addTriggerConnection('External', ...
                                        [did, '/', ...
                                         self.seq.config.niStart(did)], ...
                                        'StartTrigger');
    end

    function generate(self, cids)
      if ~all(sort(cids) == sort(self.cids))
        error('Channel mismatch.');
      end
      cids = num2cell(self.cids);
      self.data = self.seq.getValues(2e-6, cids{:})';
    end

    function run(self)
      self.session = daq.createSession('ni');
      self.session.Rate = 5e5;
      inited_devs = containers.Map();

      for i = 1:size(self.cids, 2)
        cid = self.cids(i);
        dev_name = self.cid_map{cid}{1};
        output_id = self.cid_map{cid}{2};
        self.session.addAnalogOutputChannel(dev_name, output_id, 'Voltage');
        if ~inited_devs.isKey(dev_name)
          self.connectClock(dev_name);
          inited_devs(dev_name) = true;
        end
      end
      self.session.queueOutputData(self.data);
      self.session.startBackground();
    end

    function wait(self)
      self.session.wait();
      delete(self.session);
      self.session = [];
    end
  end
end
