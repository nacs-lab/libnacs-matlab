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

    clk_period;
    clk_rate;
  end

  properties(Constant, Hidden, Access=private)
    EXTERNAL_CLOCK = true;
    CLOCK_DIVIDER = 100;
  end

  methods
    function self = NiDACBackend(seq)
      self = self@PulseBackend(seq);
      self.cid_map = {};
      self.cids = [];

      self.clk_period = 10e-9 * self.CLOCK_DIVIDER * 2;
      self.clk_rate = 1 / self.clk_period;
    end

    function val = getPriority(self)
      val = 1;
    end

    function initDev(self, did)
      if self.EXTERNAL_CLOCK
        fpgadriver = self.seq.findDriver('FPGABackend');
        fpgadriver.enableClockOut(self.CLOCK_DIVIDER);
      end
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
      %% It seems that the trigger connection has to be added before clock.
      [~] = self.session.addTriggerConnection('External', ...
                                              [did, '/', ...
                                               self.seq.config.niStart(did)], ...
                                              'StartTrigger');
      if ~self.EXTERNAL_CLOCK
        return;
      end
      [~] = self.session.addClockConnection('External', ...
                                            [did, '/', ...
                                             self.seq.config.niClocks(did)], ...
                                            'ScanClock');
    end

    function generate(self, cids)
      if ~all(sort(cids) == sort(self.cids))
        error('Channel mismatch.');
      end
      cids = num2cell(self.cids);
      self.data = self.seq.getValues(self.clk_period, cids{:})';
    end

    function run(self)
      self.session = daq.createSession('ni');
      %% Setting to a high clock rate makes the NI card to wait for more
      %% clock cycles after the sequence finished. However, setting to
      %% a rate lower than the real one cause the card to not update
      %% at the end of the sequence.
      self.session.Rate = self.clk_rate;
      inited_devs = containers.Map();

      for i = 1:size(self.cids, 2)
        cid = self.cids(i);
        dev_name = self.cid_map{cid}{1};
        output_id = self.cid_map{cid}{2};
        [~] = self.session.addAnalogOutputChannel(dev_name, output_id, ...
                                                  'Voltage');
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
