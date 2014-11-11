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

classdef PulseTimeTracker < handle
  %% This class has no expection guarantee.
  properties
    cids; % channel ids
    pulses; % pulses time sorted in start time
    seqLen; % total length of the sequence

    %% index (in self.pulses) of the last pulse time which is already
    %% processed.
    curPulseIdx;

    curTime;
    curValues; % current values of all channels
    %% Old values of all channels at the beginning of the current pulse
    %% This should be used to calculate values of the pulses in self.curPulses
    %% and the next pulse for the channel if there isn't a pulse for the
    %% corresponding channel in self.curPulses.
    %% The value should be updated whenever a pulse is removed from
    %% self.curPulses
    startValues;
    curPulses; % pulses that are being processed in the current time slice
  end

  methods
    function self = PulseTimeTracker(seq, cids)
      if ischar(cids)
        cids = {cids};
      end
      self.cids = cids;
      self.pulses = seq.getPulseTimes(cids);
      self.seqLen = seq.length();

      self.curPulseIdx = 0;

      self.curTime = -1;
      self.curValues = containers.Map();
      self.startValues = containers.Map();
      self.curPulses = containers.Map();

      for cid = self.cids
        cid = cid{:};
        self.curValues(cid) = seq.getDefaults(cid);
        self.startValues(cid) = seq.getDefaults(cid);
      end
    end

    function t = getTime(self)
      t = self.curTime;
    end

    function v = getValue(self, cid)
      v = self.curValues(cid);
    end

    function vs = getValues(self)
      vs = containers.Map();
      for key = self.curValues.keys()
        key = key{:};
        vs(key) = self.curValues(key);
      end
    end

    function vs = getStartValues(self)
      vs = containers.Map();
      for key = self.startValues.keys()
        key = key{:};
        vs(key) = self.startValues(key);
      end
    end

    function [t, evt] = nextEvent(self, dt, mode)
      if nargin < 3
        mode = TrackMode.NoLater;
      end
      if nargin < 2
        dt = 0;
      end
      if self.curTime < 0
        [t, evt] = self.initEvent();
      else
        [t, evt] = self.nextEventReal(dt, mode);
      end
    end

    function res = getCurPulses(self)
      res = containers.Map();
      for key = self.curPulses.keys()
        key = key{:};
        res(key) = self.curPulses(key);
      end
    end
  end

  methods(Access=private)
    function res = nextTimeWithIn(self, t)
      res = (self.curPulseIdx < size(self.pulses, 1) && ...
             self.pulses{self.curPulseIdx + 1, 1} <= t);
    end

    function val = calcVal(self, pulse, t)
      val = pulse{3}.calcValue(t - pulse{4}, pulse{5}, ...
                               self.startValues(pulse{6}));
    end

    function updateStart(self, cid)
      self.curPulses.remove(cid);
      self.startValues(cid) = self.curValues(cid);
    end

    function evt_out = clearEvent(self, evt, cid)
      for i = 1:size(evt, 1)
        pulse = evt(i, :);
        if strcmp(pulse{5}, cid)
          evt(i, :) = [];
          break;
        end
      end
      evt_out = evt;
    end

    function [t, evt] = initEvent(self)
      self.curTime = 0;
      evt = {};
      t = 0;

      while self.nextTimeWithIn(0)
        self.curPulseIdx = self.curPulseIdx + 1;
        pulse = self.pulses(self.curPulseIdx, :);
        cid = pulse{6};

        switch pulse{2}
          case TimeType.Dirty
            if self.curPulses.isKey(cid)
              error('Overlaping pulses.');
            end
            self.curPulses(cid) = pulse;
            self.curValues(cid) = self.calcVal(pulse, 0);
            evt = [evt; pulse];
          case TimeType.Start
            if self.curPulses.isKey(cid)
              prev_pulse = self.curPulses(cid);
              if prev_pulse{2} ~= TimeType.Dirty
                error('Overlaping pulses.');
              end
              self.updateStart(cid);
              evt = self.clearEvent(evt, cid);
            end
            self.curPulses(cid) = pulse;
            self.curValues(cid) = self.calcVal(pulse, 0);
            evt = [evt; pulse];
          case TimeType.End
            error('Pulse ends too early.');
          otherwise
            error('Invalid time type.');
        end
      end
    end

    function [t, evt] = nextEventReal(self, dt, mode)
      evt = {};

      %% Remove dirty pulses from self.curPulses and update startValues
      for key = self.curPulses.keys()
        key = key{:};
        pulse = self.curPulses(key);
        if pulse{2} == TimeType.Dirty
          self.updateStart(key);
        end
      end

      if self.curPulseIdx >= size(self.pulses, 1)
        %% No more pulses, hold value till end
        if self.curPulses.Count > 0
          self.curPulses = containers.Map();
        end
        t = self.curTime + dt;
        if dt <= 0 || t > self.seqLen
          %% End-of-sequence
          t = -1;
        end
        return;
      end

      next_pulse = self.pulses(self.curPulseIdx + 1, :);
      if dt <= 0
        t = next_pulse{1};
      elseif mode == TrackMode.NoLater
        t = min(self.curTime + dt, next_pulse{1});
      elseif mode == TrackMode.NoEarlier && self.curPulses.Count == 0
        t = max(self.curTime + dt, next_pulse{1});
      else
        t = self.curTime + dt;
      end

      while self.nextTimeWithIn(t)
        self.curPulseIdx = self.curPulseIdx + 1;
        pulse = self.pulses(self.curPulseIdx, :);
        cid = pulse{6};

        switch pulse{2}
          case TimeType.Dirty
            if self.curPulses.isKey(cid)
              orig_pulse = self.curPulses(cid);
              %% multiple Dirty pulse in one time slice can happen
              %% when the user specifies a strict dt that is longer
              %% than the time between pulses.
              if orig_pulse{2} ~= TimeType.Dirty
                error('Overlaping pulses.');
              end
              self.updateStart(cid);
              evt = self.clearEvent(evt, cid);
            end
            self.curPulses(cid) = pulse;
            self.curValues(cid) = self.calcVal(pulse, pulse{1});
            evt = [evt; pulse];
          case TimeType.Start
            if self.curPulses.isKey(cid)
              prev_pulse = self.curPulses(cid);
              if prev_pulse{2} ~= TimeType.Dirty
                error('Overlaping pulses.');
              end
              self.updateStart(cid);
              evt = self.clearEvent(evt, cid);
            end
            self.curPulses(cid) = pulse;
            new_time = min(pulse{1} + pulse{2}, t);
            self.curValues(cid) = self.calcVal(pulse, new_time);
            evt = [evt; pulse];
          case TimeType.End
            if ~self.curPulses.isKey(cid)
              error('No pulse to finish.');
            end
            prev_pulse = self.curPulses(cid);
            if prev_pulse{2} ~= TimeType.Start
              error('Wrong pulse type to finish.');
            elseif prev_pulse{7} ~= pulse{7}
              error('Wrong pulse to finish.');
            end
            %% Finish up pulse
            self.curValues(cid) = self.calcVal(prev_pulse, pulse{1});
            self.updateStart(cid);
            evt = self.clearEvent(evt, cid);
          otherwise
            error('Invalid time type.');
        end
      end
      self.curTime = t;
    end
  end
end
