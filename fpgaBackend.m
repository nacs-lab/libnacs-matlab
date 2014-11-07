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
      crit_ts = {};
      DIRTY_TIME = 0;
      START_TIME = 1;
      END_TIME = 2;
      for cid = cids
        pulses = seq.getPulses(cid);
        for i = 1:size(pulses, 1)
          pulse = pulses(i, :);
          pulse_obj = pulse{3};
          toffset = pulse{4};
          step_len = pulse{5};
          dirty_times = pulse_obj.dirtyTimes(step_len);
          if ~isempty(dirty_times)
            for t = dirty_times
              crit_ts = [crit_ts; {t + toffset, DIRTY_TIME, pulse_obj, ...
                                   toffset, step_len}];
            end
          else
            tstart = pulse{1} + toffset;
            tlen = pulse{2};
            crit_ts = [crit_ts; {tstart, START_TIME, pulse_obj, ...
                                 toffset, step_len}];
            crit_ts = [crit_ts; {tstart + tlen, END_TIME, pulse_obj, ...
                                 toffset, step_len}];
          end
        end
      end
      if ~isempty(crit_ts)
        crit_ts = sortrows(crit_ts, 1);
      end

      ntime = size(crit_ts, 1);
      %% FIXME hard code
      t = 100e-6;
      self.cmd = sprintf('t=100,TTL(all)=%x\n', self.getTTLDefault());
      if self.clock_div > 0
        %% FIXME hard code
        self.cmd = [self.cmd, ...
                    sprintf('t=200,CLOCK_OUT(%d)\n', self.clock_div)];
        t = 200e-6;
      end
      start_t = t;

      %% WIP
      i = 0;
      while i < ntime
        i = i + 1;
      end

      if self.clock_div > 0
        %% FIXME hard code
        t = t + 1e-6;
        self.cmd = [self.cmd, sprintf('t=%.2f,CLOCK_OUT(100)\n', t * 1e6)];
        %% FIXME hard code
        t = t + 100e-6;
        self.cmd = [self.cmd, sprintf('t=%.2f,CLOCK_OUT(off)\n', t * 1e6)];
      end
    end

    function res = getCmd(self)
      res = self.cmd;
    end

    function run(self, rep)
      %% TODO
    end
  end

  methods(Access=private)
      function val = getTTLDefault(self)
      %% FIXME
      val = 0;
      return;
    end
  end
end
