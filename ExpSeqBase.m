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

classdef ExpSeqBase < TimeSeq
    %ExpSeqBase is a subclass of TimeSeq, and the parent class of ExpSeq.
    %It only adds one property, 'curTime' (number), which keeps track of
    %the current time.
    %Its role is to store other ExpSeqBase objects (in the SubSeqs
    %property).  The methods of ExpSeqBase are used to add ExpSeqBase's and
    %pulses to the experiment.

    %All Methods:
        % self = ExpSeqBase(varargin)
        % res = wait(self, t)
        % res = waitAll(self)
        % res = waitBackground(self)
        % step = add(self, name, pulse, len)
        % step = addBackground(self, varargin)
        % step = addStep(self, varargin)
        % Private:
        % step = addStepReal(self, curtime, is_background, first_arg, varargin)
        % step = addTimeStep(self, len, offset)
        % step = addCustomStep(self, start_time, cls, varargin)
  properties(Hidden)
    %TimeSeq properties: config (class), logger (class), subSeqs (struct), len,  parnet, seq_id, tOffset
    curTime = 0;
  end
  properties(SetAccess = private, Hidden)
    C;
  end

  methods
    function self = ExpSeqBase(parent_or_C, toffset)
      %% Constructor. Just initializes a TimeSeq object.
      if exist('toffset', 'var')
        toplevel = 0;
        ts_args = {parent_or_C, toffset};
      else
        toplevel = 1;
        ts_args = {};
      end
      self = self@TimeSeq(ts_args{:});
      if ~toplevel
        self.C = self.parent.C;
        return
      end
      C = struct();
      consts = self.config.consts;
      fields = fieldnames(consts);
      for i = 1:length(fields)
        fn = fields{i};
        C.(fn) = consts.(fn);
      end
      if exist('parent_or_C', 'var')
        %% Allow parameters to overwrite consts in config
        fields = fieldnames(parent_or_C);
        for i = 1:length(fields)
          fn = fields{i};
          C.(fn) = parent_or_C.(fn);
        end
      end
      self.C = DynProps(C);
    end

    %%
    function res = wait(self, t)
        %Just steps the curTime of 'self' forward by t, and returns 'self'
      self.curTime = self.curTime + t;
      res = self;
    end

    %%
    function res = waitAll(self)
      % Wait for everything that have been currently added to finish.
      self.curTime = self.length(); %method in TimeSeq
      res = self;
    end

    function res = waitFor(self, steps, offset)
        if ~exist('offset', 'var')
            offset = 0;
        end
        t = self.curTime;
        for step = steps
            if iscell(step)
                real_step = step{:};
            else
                real_step = step;
            end
            tstep = endof(real_step) + offset;
            if real_step.parent ~= self
                tstep = tstep + offsetDiff(self, real_step.parent);
            end
            if tstep > t
                t = tstep;
            end
        end
        self.curTime = t;
        res = self;
    end

    function res = waitBackground(self)
      %% Wait for background steps that are added directly to this sequence
      % to finish
      function checkBackgroundTime(sub_seq)
        if ~isa(sub_seq, 'ExpSeqBase')
          len = sub_seq.len;
        else
          len = sub_seq.curTime;
        end
        sub_cur = sub_seq.tOffset + len;
        if isnan(sub_cur)
          error('Cannot wait for background with floating sub sequences.');
        end
        if sub_cur > self.curTime
          self.curTime = sub_cur;
        end
      end
      self.subSeqForeach(@checkBackgroundTime);
      res = self;
    end

    function step = add(self, name, pulse, len)
      if isnumeric(pulse)
        if nargin > 3
          error('Too many arguments for ExpSeq.add');
        end
        % TODO? find a better way to determine the step length or figure out
        % a way to add zero length pulse.
        len = 1e-5;
      end
      self.addBackground(len).add(name, pulse);
      step = self;
    end

    %%
    function step = addBackground(self, first_arg, varargin)
      %% Shortcut for addStepReal with 'is_background' = true ,
      % and does not advanceself.curTime.  addStepReal usually advances curTime.

      old_time = self.curTime;
      step = addStepReal(self, old_time, true, first_arg, varargin{:});
      self.curTime = old_time;
    end

    function step = addStep(self, first_arg, varargin)
      step = addStepReal(self, self.curTime, false, first_arg, varargin{:});
    end

    function step = addFloating(self, first_arg, varargin)
      old_time = self.curTime;
      step = addStepReal(self, nan, true, first_arg, varargin{:});
      self.curTime = old_time;
    end

    function res = endof(self)
      %% Do not include background pulse as current time.
      toffset = self.tOffset;
      if isnan(toffset)
        error('Cannot get end time of floating sequence.');
      end
      res = toffset + self.curTime;
    end

    function alignEnd(self, seq1, seq2, offset)
      if ~exist('offset', 'var')
        offset = 0;
      end
      if ~isnan(seq1.tOffset) || ~isnan(seq2.tOffset)
        error('alignEnd requires two floating sequences as inputs.');
      end
      if ~isa(seq1, 'ExpSeqBase')
        len1 = seq1.len;
      else
        len1 = seq1.curTime;
      end
      if ~isa(seq2, 'ExpSeqBase')
        len2 = seq2.len;
      else
        len2 = seq2.curTime;
      end
      if len1 > len2
        seq1.setTime(endTime(self), 0, offset);
        seq2.setEndTime(endTime(seq1));
      else
        seq2.setTime(endTime(self), 0, offset);
        seq1.setEndTime(endTime(seq2));
      end
    end
  end

  methods(Access=private)
    %%
    function step = addStepReal(self, curtime, is_background, first_arg, varargin)
      % step = addStepReal(self, curtime, is_background [logic], first_arg, varargin)
      %     addStepReal is called by shortcut methods addStep  (is_background=false) and addBackground (is_background=true).
      %     It is private and not called outside this class.
      %     Case 1:  self.addStepReal(curtime, true/false, len>0)
      %          first_arg = len,  varargin is empty.  Only runs line with  %Case 1(labeled below).
      %          Case 1 calls step = self.addTimeStep( len , 0), which adds
      %          an empty TimeStep and advances self.curTime by len.
      %     Case 2: s.addStepReal(curtime, true, function handle)
      %          first_arg = function handle, varargin empty.
      %          Only runs line %Case 2, which calls  s.addCustomStep(curtime, function_handle)
      %          This case is used by s.add('Channel',value).


      % addStep(len[, offset=0])
      %     Add a #TimeStep with len and offset from the last step
      % addStep([offset=0, ]class_or_func, *extra_args)
      %     Construct a step or sub sequence with @class_or_func(*extra_args)

      %     If offset is not an absolute time (TODO: abstime not supported yet),
      %     forward @self.curTime by the length of the step.
      if ~isnumeric(first_arg)
        % If first arg is not a number, assume to be a custom step.
        % What fall through should be (number, *arg)
        step = self.addCustomStep(curtime, first_arg, varargin{:});   %Case 2
      elseif isempty(varargin)
        % If we only have one numerical argument it must be a simple time step.
        % What fall through should be (number, at_least_another_arg, *arg)
        if first_arg < 0
          if isnan(curtime)
            error('Floating time step with time offset not allowed.');
          end
          step = self.addTimeStep(-first_arg, first_arg + curtime);
        else
          step = self.addTimeStep(first_arg, curtime);  %Case 1
        end
      elseif isnumeric(varargin{1})
        % If we only have two numerical argument it must be a simple time step
        % with custom offset.
        % What fall through should be (number, not_number, *arg)
        if length(varargin) > 1
          error('addStep called with too many arguments.');
        elseif isnan(curtime)
          error('Floating time step with time offset not allowed.');
        end
        offset = varargin{1};
        if ~is_background && offset + first_arg < 0
          error('Implicitly going back in time is not allowed.');
        end
        step = self.addTimeStep(first_arg, offset + curtime);
      else
        % The not_number must be a custom step. Do it.
        if isnan(curtime)
          error('Floating time step with time offset not allowed.');
        end
        step = self.addCustomStep(curtime + first_arg, varargin{:});
      end
    end

    %%
    function step = addTimeStep(self, len, start_time)
      %% step [TimeStep] = addTimeStep(self [ExpSeqBase], len, start_time)
      %     addTimeStep makes an empty TimeStep object 'step' and adds it to subSeqs
      %     of self.  A pulse is added to the TimeStep by applying add
      %     (equiv to addPulse) to the TimeStep.
      %     addTimeStep and addCustomStep are the only functions that add
      %     TimeStep objects (which contain pulses).
      %     All above methods eventually call one of these methods.

      if len <= 0
        error('Length of time step must be positive.');
      end

      self.curTime = start_time;
      % makes a TimeStep object 'step', and adds it to the subSeq of self.
      step = TimeStep(self, start_time, len);
      self.curTime = self.curTime + len;
    end

    %%
    function step = addCustomStep(self, start_time, cls, varargin)
        % step [TimeStep] = addCustomStep(self [ExpSeq], offset, cls [function handle], varargin [optional])
            %Inserts a new ExpSeqBase in self.subSeqs, then applies the
            %function handle cls to it. Advances self.curTime.
            %addTimeStep and addCustomStep are the only functions that add
            %TimeStep objects (which contain pulses).  All above methods eventually call one of these
            %mtehods.


      if ischar(cls)  %if cls is string, converts to function handle
        cls = str2func(cls);
      end

      self.curTime = start_time; %advance current time
      step = ExpSeqBase(self, start_time); %creates ExpSeqBase in self.subSeqs.
      % return proxy since I'm not sure there's a good way to forward
      % return values in matlab, especially since the return value can
      % depend on the number of return values.
      cls(step, varargin{:}); %runs the function handle
      self.curTime = self.curTime + step.curTime;
    end
  end
end
