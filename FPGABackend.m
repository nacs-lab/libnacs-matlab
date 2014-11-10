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

classdef FPGABackend < PulseBackend
  properties(Hidden, Access=private)
    url = '';
    clock_div = 0;
    cmd = '';
    config;
    poster = [];
  end

  properties(Constant, Hidden, Access=private)
    INIT_DELAY = 100e-6;
    CLOCK_DELAY = 100e-6;
    MIN_DELAY = 1e-6;
    START_DELAY = 0.5e-6;
    FIN_CLOCK_DELAY = 100e-6;

    TTL_CHN = 1;
    DDS_CHN = 2;

    SET_FREQ = 1;
    SET_AMP = 2;
    SET_PHASE = 3;
  end

  methods
    function self = FPGABackend(varargin)
      self = self@PulseBackend(varargin{:});
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
      self.parseCId(cid);
    end

    function enableClockOut(self, div)
      if div < 0 or div > 254
        error('Clock divider out of range.');
      end
      self.clock_div = div;
    end

    function generate(self, seq, cids)
      t = self.INIT_DELAY;
      self.cmd = '';
      self.appendCmd('TTL(all)=%x', t, self.getTTLDefault(seq));
      if self.clock_div > 0
        t = t + self.CLOCK_DELAY;
        self.appendCmd('CLOCK_OUT(%d)', t, self.clock_div);
      end
      start_t = t + self.START_DELAY;
      tracker = pulseTimeTracker(seq, cids);

      while true
        min_delay = self.MIN_DELAY + t - (tracker.getTime() + start_t);
        [new_t, new_pulses] = tracker.nextEvent(min_delay, trackMode.NoEarlier);
        if new_t < 0
          break;
        end
        t = new_t + start_t;

        updated_chn = containers.Map();
        for i = size(new_pulses, 1)
          pulse = new_pulses(i, :);
          cid = pulse{6};
          if pulse{2} == timeType.Dirty
            %% TODO? merge TTL update, use more precise values
            %% TODO? update finished pulse
            self.appendPulse(cid, tracker.getValue(cid));
            t = t + self.MIN_DELAY;
            updated_chn(cid) = 1;
          end
        end

        %% Update channels that are currently active.
        cur_pulses = tracker.getCurPulses();
        for key = cur_pulses.keys()
          key = key{:};
          if updated_chn.isKey(key)
            continue
          end
          pulse = cur_pulses(key);
          self.appendPulse(key, tracker.getValue(key));
          t = t + self.MIN_DELAY;
        end
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
      self.poster = urlPoster(self.url);
      self.poster.post({'command', 'runseq', ...
                        'debugPulses', 'off',
                        'reps', '1',
                        'seqtext', self.cmd});
    end

    function wait(self, rep)
      output = self.poster.reply();
      disp(output);
    end
  end

  methods(Access=private)
    function [chn_type, chn_num, chn_param] = parseCId(self, cid)
      cpath = strsplit(cid, '/');
      if strncmpi(cpath(1), 'TTL', 3)
        chn_type = TTL_CHN;
        chn_param = 0;
        if size(cpath, 2) ~= 1
          error('Invalid TTL channel id "%s".', cid);
        end
        matches = regexpi(cpath, '^ttl([1-9]\d*)$', 'tokens');
        if isempty(matches)
          error('No TTL channel number');
        end
        chn_num = str2double(matches{1}{1});
        if ~isfinite(chn_num) || chn_num < 0 || chn_num > 24 || ...
           mod(chn_num, 4) == 0
          error('Unconnected TTL channel %d.', chn_num);
        end
      elseif strncmpi(cpath(1), 'DDS', 3)
        chn_type = DDS_CHN;
        if size(cpath, 2) ~= 2
          error('Invalid DDS channel id "%s".', cid);
        end
        matches = regexpi(cpath, '^dds([1-9]\d*)$', 'tokens');
        if isempty(matches)
          error('No DDS channel number');
        end
        chn_num = str2double(matches{1}{1});
        if ~isfinite(chn_num) || chn_num < 0 || chn_num > 22
          error('DDS channel number %d out of range.', chn_num);
        end
        if strcmpi(cpath(2), 'freq')
          chn_param = SET_FREQ;
        elseif strcmpi(cpath(2), 'amp')
          chn_param = SET_AMP;
        else
          error('Invalid DDS parameter name "%s".', cpath(2));
        end
      end
    end

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

    function appendPulse(self, cid, val)
      if ~strncmpi('FPGA1/', cid, 5)
        error('Unknown channel ID "%s"', cid);
      end
      cid = cid(6:end);
      [chn_type, chn_num, chn_param] = parseCId(self, cid);
      if chn_type == TTL_CHN
        if val
          val = 1
        else
          val = 0
        end
        self.appendCmd('TTL(%d) = %d', chn_num, val);
      elseif chn_type == DDS_CHN
        if chn_param == SET_FREQ
          cmd = 'freq';
        elseif chn_param == SET_AMP
          cmd = 'amp';
        else
          error('Unknown DDS parameter.');
        end
        self.appendCmd('%s(%d) = %f', cmd, chn_num, val);
      else
        error('Unknown channel type.');
      end
    end
  end
end
