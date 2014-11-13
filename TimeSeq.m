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

classdef TimeSeq < handle
  properties
    config;
    logger;
    chn_manager;
  end

  properties(Hidden, Access=protected)
    len = 0;
  end

  properties(Hidden, Access=private)
    subSeqs;
    tOffset;
    parent = 0;
  end

  methods
    function self = TimeSeq(parent_or_name, toffset, len)
      self.subSeqs = {};
      if nargin < 1
        self.logger = NaCsLogger('seq');
        self.config = loadConfig();
        self.chn_manager = ChannelManager();
      elseif nargin < 2
        self.logger = NaCsLogger(parent_or_name);
        self.config = loadConfig();
        self.chn_manager = ChannelManager();
      else
        self.parent = parent_or_name;
        self.tOffset = toffset;

        self.logger = parent_or_name.logger;
        self.config = parent_or_name.config;
        self.chn_manager = parent_or_name.chn_manager;
        parent_or_name.addSubSeq(self, toffset);
        if nargin >= 3
          self.len = len;
        end
      end
    end

    function log(self, s)
      self.logger.log(s);
    end

    function logf(self, varargin)
      self.logger.logf(varargin{:});
    end

    function res = length(self)
      if self.len > 0
        res = self.len;
        return;
      else
        res = 0;
        nsub = size(self.subSeqs, 2);
        for i = 1:nsub
          seq_t = self.subSeqs{i};
          sub_end = seq_t.seq.length() + seq_t.offset;
          if sub_end > res
            res = sub_end;
          end
        end
      end
    end

    function vals = getDefaults(self, cids)
      %% @cid: a column array of channel id numbers
      if isnumeric(cids)
        vals = self.getDefault(cids);
      else
        nchn = size(cids, 1);
        vals = zeros(nchn, 1);
        for i = 1:nchn
          vals(i) = self.getDefault(cids(i));
        end
      end
    end

    function res = getPulseTimes(self, cids)
      %% TODOPULSE use struct
      nchn = size(cids, 1);
      res = {};
      for j = 1:nchn
        cid = cids(j);
        pulses = self.getPulses(cid);
        for i = 1:size(pulses, 1)
          pulse = pulses(i, :);
          pulse_obj = pulse{3};
          toffset = pulse{4};
          step_len = pulse{5};
          dirty_times = pulse_obj.dirtyTime(step_len);
          if ~isempty(dirty_times)
            for t = dirty_times
              res = [res; {t + toffset, int32(TimeType.Dirty), pulse_obj, ...
                           toffset, step_len, cid, pulse_obj.getID()}];
            end
          else
            %% Maybe treating a zero length pulse as hasDirtyTime?
            tstart = pulse{1} + toffset;
            tlen = pulse{2};
            res = [res; {tstart, int32(TimeType.Start), pulse_obj, ...
                         toffset, step_len, cid, pulse_obj.getID()}];
            res = [res; {tstart + tlen, int32(TimeType.End), pulse_obj, ...
                         toffset, step_len, cid, pulse_obj.getID()}];
          end
        end
      end
      if ~isempty(res)
        res = sortrows(res, [1, 2, 7]);
      end
    end

    function vals = getValues(self, dt, varargin)
      %% TODOPULSE refactor
      total_t = self.length();
      nstep = floor(total_t / dt) + 1;
      nchn = nargin - 2;

      vals = zeros(nchn, nstep);
      for i = 1:nchn
        chn = varargin{i};
        if ischar(chn)
          scale = 1;
        else
          scale = chn{2};
          chn = chn{1};
        end
        tracker = PulseTimeTracker(self, chn);

        for j = 1:nstep
          [t, evt] = tracker.nextEvent(dt, TrackMode.Strict);
          vals(i, j) = tracker.curValues(chn);
        end
      end
    end
  end

  methods(Access=protected)
    function res = getPulses(self, cid)
      %% Return a array of tuples (toffset, length, pulse_obj,
      %%                           step_start, step_len, cid)
      %% the pulse_obj should have a method calcValue that take 3 parameters:
      %%     time_in_pulse, length, old_val_before_pulse
      %% and should return the new value @time_in_pulse after the step_start.
      %% The returned value should be sorted with toffset.
      res = self.getPulsesRaw(cid);
      if ~isempty(res)
        res = sortrows(res, 1);
      end
    end

    function avail = globChannelAvailable(self, cid, t, dt)
      if nargin < 4 || dt < 0
        dt = 0;
      end
      if self.hasParent()
        avail = self.parent.globChannelAvailable(cid, t + self.tOffset, dt);
      else
        avail = self.channelAvailable(cid, t, dt);
      end
    end

    function val = getDefault(self, ~)
      val = 0;
      return;
    end

    function res = hasParent(self)
      res = isobject(self.parent);
    end

    function parent = getParent(self)
      parent = self.parent;
    end

    function addSubSeq(self, sub_seq, toffset)
      len = self.len;
      if len > 0
        sub_len = sub_seq.len;
        if sub_len <= 0
          error(['Cannot add a variable length sequence to' ...
                   'a fixed length sequence']);
        elseif toffset > len
          error('Too big sub-sequence time offset.');
        elseif toffset + sub_len > len
          error('Too long sub-sequence.');
        end
      end
      if sub_seq.hasParent() && sub_seq.getParent() ~= self
        error('Reparenting time sequence is not allowed.');
      end
      self.subSeqs{end + 1} = struct('offset', toffset, 'seq', sub_seq);
    end

    function avail = channelAvailable(self, cid, t, dt)
      if nargin < 4 || dt < 0
        dt = 0;
      end
      avail = true;
      len = self.len;
      if len > 0 && t >= len
        return;
      end
      nsub = size(self.subSeqs, 2);
      for i = 1:nsub
        seq_t = self.subSeqs{i};
        sub_t = t - seq_t.offset;
        if sub_t + dt > 0 && ~seq_t.seq.channelAvailable(cid, sub_t, dt)
          avail = false;
          return;
        end
      end
    end

    function res = getPulsesRaw(self, cid)
      %% TODOPULSE use struct
      res = {};
      nsub = size(self.subSeqs, 2);
      for i = 1:nsub
        seq_t = self.subSeqs{i};
        sub_pulses = seq_t.seq.getPulsesRaw(cid);

        for i = 1:size(sub_pulses, 1)
          sub_tuple = sub_pulses(i, :);
          pulse_toffset = sub_tuple{1};
          pulse_len = sub_tuple{2};
          pulse_func = sub_tuple{3};
          step_toffset = sub_tuple{4};
          step_len = sub_tuple{5};

          res = [res; {pulse_toffset + seq_t.offset, pulse_len, pulse_func, ...
                       step_toffset + seq_t.offset, step_len, cid}];
        end
      end
    end

    function res = translateChannel(self, cid)
      if self.hasParent()
        res = self.parent.translateChannel(cid);
      else
        %% Mainly for testing.
        %% The top level time sequence should implement proper check.
        res = self.chn_manager.getId(cid);
      end
    end
  end
end
