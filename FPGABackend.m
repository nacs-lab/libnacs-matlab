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
    config;
    poster = [];
    type_cache = [];
    num_cache = [];
    param_cache = [];
    commands;
    cmd_str = '';
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
      self.commands = {};
    end

    function initDev(self, did)
      if ~strcmp('FPGA1', did)
        error('Unknown FPGA device "%s".', did);
      end
    end

    function initChannel(self, cid)
      if size(self.type_cache, 2) >= cid && self.type_cache(cid) > 0
        return;
      end
      name = self.seq.channelName(cid);
      if ~strncmp('FPGA1/', name, 5)
        error('Unknown channel name "%s"', name);
      end
      name = name(7:end);
      [chn_type, chn_num, chn_param] = self.parseCIdReal(name);
      self.type_cache(cid) = chn_type;
      self.num_cache(cid) = chn_num;
      self.param_cache(cid) = chn_param;
    end

    function enableClockOut(self, div)
      if div < 0 || div > 254
        error('Clock divider out of range.');
      end
      self.clock_div = div;
    end

    function generate(self, cids)
      t = self.INIT_DELAY;
      self.cmd_str = '';
      self.commands = {};
      self.commands{end + 1} = sprintf(['t=%.2f,TTL(all)=%x\n'], ...
                                       t * 1e6, self.getTTLDefault());
      if self.clock_div > 0
        t = t + self.CLOCK_DELAY;
        self.commands{end + 1} = sprintf(['t=%.2f,CLOCK_OUT(%d)\n'], ...
                                         t * 1e6, self.clock_div);
      end
      start_t = t + self.START_DELAY;
      tracker = PulseTimeTracker(self.seq, cids);

      while true
        min_delay = self.MIN_DELAY + t - (tracker.curTime + start_t);
        [new_t, new_pulses] = tracker.nextEvent(min_delay, TrackMode.NoEarlier);
        if new_t < 0
          break;
        end
        t = new_t + start_t;

        updated_chn = containers.Map();
        for i = 1:size(new_pulses, 1)
          pulse = new_pulses(i, :);
          cid = pulse{6};
          if pulse{2} == TimeType.Dirty
            %% TODO? merge TTL update, use more precise values
            %% TODO? update finished pulse
            self.appendPulse(cid, t, tracker.curValues(cid));
            t = t + self.MIN_DELAY;
            updated_chn(cid) = 1;
          end
        end

        %% Update channels that are currently active.
        cur_pulses = tracker.curPulses;
        for key = 1:tracker.nchn
          if updated_chn.isKey(key)
            continue
          end
          self.appendPulse(key, t, tracker.curValues(key));
          t = t + self.MIN_DELAY;
        end
      end

      if self.clock_div > 0
        t = t + self.MIN_DELAY;
        self.commands{end + 1} = sprintf(['t=%.2f,CLOCK_OUT(100)\n'], t * 1e6);
        t = t + self.FIN_CLOCK_DELAY;
        self.commands{end + 1} = sprintf(['t=%.2f,CLOCK_OUT(off)\n'], t * 1e6);
      end

      self.cmd_str = [self.commands{:}];

      self.seq.log('#### Start Generated Sequence File ####');
      self.seq.log(self.cmd_str);
      self.seq.log('#### End Sequence File ####');
    end

    function res = getCmd(self)
      res = self.cmd_str;
    end

    function run(self, rep)
      self.poster = URLPoster(self.url);
      self.poster.post({'command', 'runseq', ...
                        'debugPulses', 'off',
                        'reps', '1',
                        'seqtext', self.cmd_str});
    end

    function wait(self, rep)
      output = self.poster.reply();
      disp(output);
    end
  end

  methods(Access=private)
    function [chn_type, chn_num, chn_param] = parseCId(self, cid)
    end

    function [chn_type, chn_num, chn_param] = parseCIdReal(self, cid)
      cpath = strsplit(cid, '/');
      if strncmp(cpath{1}, 'TTL', 3)
        chn_type = self.TTL_CHN;
        chn_param = 0;
        if size(cpath, 2) ~= 1
          error('Invalid TTL channel id "%s".', cid);
        end
        matches = regexp(cpath{1}, '^TTL([1-9]\d*)$', 'tokens');
        if isempty(matches)
          error('No TTL channel number');
        end
        chn_num = str2double(matches{1}{1});
        if ~isfinite(chn_num) || chn_num < 0 || chn_num > 24 || ...
           mod(chn_num, 4) == 0
          error('Unconnected TTL channel %d.', chn_num);
        end
      elseif strncmp(cpath{1}, 'DDS', 3)
        chn_type = self.DDS_CHN;
        if size(cpath, 2) ~= 2
          error('Invalid DDS channel id "%s".', cid);
        end
        matches = regexp(cpath{1}, '^DDS([1-9]\d*)$', 'tokens');
        if isempty(matches)
          error('No DDS channel number');
        end
        chn_num = str2double(matches{1}{1});
        if ~isfinite(chn_num) || chn_num < 0 || chn_num > 22
          error('DDS channel number %d out of range.', chn_num);
        end
        if strcmp(cpath{2}, 'FREQ')
          chn_param = self.SET_FREQ;
        elseif strcmp(cpath{2}, 'AMP')
          chn_param = self.SET_AMP;
        else
          error('Invalid DDS parameter name "%s".', cpath{2});
        end
      else
        error('Unknown channel type "%s"', cpath{1});
      end
    end

    function val = singleTTLDefault(self, chn)
      val = uint64(0);
      try
        if self.seq.getDefaults(sprintf('FPGA1/TTL%d', chn))
          val = uint64(1);
        end
      catch
      end
    end

    function val = getTTLDefault(self)
      val = 0;
      for i = 0:31
        val = val | bitshift(self.singleTTLDefault(i), i);
      end
    end

    function appendPulse(self, cid, t, val)
      chn_type = self.type_cache(cid);
      chn_num = self.num_cache(cid);
      chn_param = self.param_cache(cid);
      if chn_type == self.TTL_CHN
        if val
          val = 1;
        else
          val = 0;
        end
        self.commands{end + 1} = sprintf(['t=%.2f,TTL(%d) = %d\n'], ...
                                         t * 1e6, chn_num, val);
      elseif chn_type == self.DDS_CHN
        if chn_param == self.SET_FREQ
          cmd_name = 'freq';
        elseif chn_param == self.SET_AMP
          cmd_name = 'amp';
        else
          error('Unknown DDS parameter.');
        end
        self.commands{end + 1} = sprintf(['t=%.2f,', cmd_name, ...
                                          '(%d) = %f\n'], ...
                                         t * 1e6, chn_num, val);
      else
        error('Unknown channel type.');
      end
    end
  end
end
