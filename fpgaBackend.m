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

classdef fpgaBackend < pulseBackend
  properties(Hidden, Access=private)
    url = '';
    clock_div = 0;
    cmd = '';
    config;
  end

  properties(Constant, Hidden, Access=private)
    START_DELAY = 100e-6;
    CLOCK_DELAY = 100e-6;
    MIN_DELAY = 1e-6;
    FIN_CLOCK_DELAY = 100e-6;
  end

  methods
    function self = fpgaBackend(varargin)
      self = self@pulseBackend(varargin{:});
      self.config = loadConfig();
      self.url = self.config.fpgaUrls('FPGA1');
    end

    function initDev(self, did)
      if ~strcmpi('FPGA1', did)
        error('Unknown FPGA device "%s".', did);
      end
    end

    function initChannel(self, did, cid)
      self.initDev(did);
      cpath = strsplit(cid, '/');
      if strncmpi(cpath(1), 'TTL', 3)
        if size(cpath, 2) ~= 1
          error('Invalid TTL channel id "%s".', cid);
        end
        matches = regexpi(cpath, '^ttl([1-9]\d*)$', 'tokens');
        if isempty(matches)
          error('No TTL channel number');
        end
        chn = str2double(matches{1}{1});
        if ~isfinite(chn) || chn < 0 || chn > 24 || (mod(chn, 4) == 0)
          error('Unconnected TTL channel %d.', chn);
        end
      elseif strncmpi(cpath(1), 'DDS', 3)
        if size(cpath, 2) ~= 2
          error('Invalid DDS channel id "%s".', cid);
        end
        matches = regexpi(cpath, '^dds([1-9]\d*)$', 'tokens');
        if isempty(matches)
          error('No DDS channel number');
        end
        chn = str2double(matches{1}{1});
        if ~isfinite(chn) || chn < 0 || chn > 22
          error('DDS channel number %d out of range.', chn);
        end
        if ~(strcmpi(cpath(2), 'freq') || strcmpi(cpath(2), 'amp'))
          error('Invalid DDS parameter name "%s".', cpath(2));
        end
      end
    end

    function enableClockOut(self, div)
      %% TODO, add check
      self.clock_div = div;
    end

    function generate(self, seq, cids)
      %% TODO
      %% use clock_div
      crit_ts = seq.getPulseTimes(cids);

      ntime = size(crit_ts, 1);
      t = self.START_DELAY;
      self.cmd = '';
      self.appendCmd('TTL(all)=%x', t, self.getTTLDefault(seq));
      if self.clock_div > 0
        t = t + self.CLOCK_DELAY;
        self.appendCmd('CLOCK_OUT(%d)', t, self.clock_div);
      end
      start_t = t;
      tracker = pulseTimeTracker(seq, cids);

      %% WIP
      i = 0;
      while i < ntime
        i = i + 1;
      end

      if self.clock_div > 0
        t = t + self.MIN_DELAY;
        self.appendCmd('CLOCK_OUT(100)', t);
        t = t + self.FIN_CLOCK_DELAY;
        self.appendCmd('CLOCK_OUT(off)', t);
      end

      seq.log('#### Start Generated Sequence File ####');
      seq.log(self.cmd);
      seq.log('#### End Sequence File ####');
    end

    function res = getCmd(self)
      res = self.cmd;
    end

    function run(self, rep)
      %% TODO
    end
  end

  methods(Access=private)
    function val = singleTTLDefault(self, seq, chn)
      val = uint64(0);
      try
        if seq.getDefaults(sprintf('FPGA1/TTL%d', chn))
          val = uint64(1);
        end
      catch
      end
    end

    function val = getTTLDefault(self, seq)
      val = 0;
      for i = 0:31
        val = val | bitshift(self.singleTTLDefault(seq, i), i);
      end
    end

    function appendCmd(self, fmt, t, varargin)
      self.cmd = [self.cmd, sprintf(['t=%.2f,', fmt, '\n'], ...
                                    t * 1e6, varargin{:})];
    end
  end
end
