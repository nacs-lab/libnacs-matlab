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
        % step = addStepReal(self, is_background, first_arg, varargin)
        % step = addTimeStep(self, len, offset)
        % step = addCustomStep(self, offset, cls, varargin)
  properties(Hidden)
    %TimeSeq properties: config (class), logger (class), subSeqs (struct), len,  parnet, seq_id, tOffset
    curTime = 0;
  end

  methods
    function self = ExpSeqBase(varargin)
       % Constructor. Just initializes a TimeSeq object.
      if nargin > 2
        error('Too many arguments for ExpSeqBase.');
      end
      self = self@TimeSeq(varargin{:});
      consts = self.config.consts;
      function res = get_getter(key)
        res = @(obj) consts(key);
      end
      function res = get_setter(key)
        function setter(obj, val)
          consts(key) = val;
        end
        res = @setter;
      end
      for key = consts.keys()
        prop = self.addprop(key{:});
        prop.GetMethod = get_getter(key{:});
        prop.SetMethod = get_setter(key{:});
      end
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

    function res = offsetDiff(self, step)
      %% Use an array of offset to reduce the rounding error when taking the difference
      % especially when the step we are querying shares a common parent.
      self_offset = globalOffset(self);
      other_offset = globalOffset(step);
      len_self = length(self_offset);
      len_other = length(other_offset);
      if len_self > len_other
        self_offset(1:len_other) = self_offset(1:len_other) - other_offset;
        res = -sum(self_offset);
      else
        other_offset(1:len_self) = other_offset(1:len_self) - self_offset;
        res = sum(other_offset);
      end
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
      %% to finish
      function checkBackgroundTime(sub_seq)
        if ~isa(sub_seq.seq, 'ExpSeqBase')
          len = sub_seq.seq.len;
        else
          len = sub_seq.seq.curTime;
        end
        sub_cur = sub_seq.offset + len;
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
    function step = addBackground(self, varargin)
        % Shortcut for addStepReal with 'is_background' = true ,
        %and does not advanceself.curTime.  addStepReal usually advances curTime.

      old_time = self.curTime;
      step = self.addStepReal(true, varargin{:});
      self.curTime = old_time;
    end

    function step = addStep(self, varargin)
      step = self.addStepReal(false, varargin{:});
    end

    function res = endof(self)
      %% Do not include background pulse as current time.
      res = self.tOffset + self.curTime;
    end
  end

  methods(Access=private)
      %%
    function step = addStepReal(self, is_background, first_arg, varargin)
      % step [TimeStep] = addStepReal(self [ExpSeq], is_background [logic], first_arg, varargin)
          % addStepReal is called by shortcut methods addStep  (is_background=false) and addBackground (is_background=true).
          % It is private and not called outside this class.
          %Case 1:  self.addStepReal( true/false, len>0)
                %first_arg = len,  varargin is empty.  Only runs line with  %Case 1(labeled below).
                %Case 1 calls step = self.addTimeStep( len , 0), which adds
                %an empty TimeStep and advances self.curTime by len.
          %Case 2: s.addStepReal(true, function handle)
                %first_arg = function handle, varargin empty.
                %Only runs line %Case 2, which calls  s.addCustomStep(0, function_handle)
                %This case is used by s.add('Channel',value).


        % addStep(len[, offset=0])
      %     Add a #TimeStep with len and offset from the last step
      % addStep([offset=0, ]class_or_func, *extra_args)
      %     Construct a step or sub sequence with @class_or_func(*extra_args)

      %     If offset is not an absolute time (TODO: abstime not supported yet),
      %     forward @self.curTime by the length of the step.
      if nargin <= 2
        error('addStep called with too few arguments.');
      elseif ~isnumeric(first_arg)
        % If first arg is not a number, assume to be a custom step.
        % What fall through should be (number, *arg)

        % TODO: for absolute time, also check if the first arg is an absolute
        % time object.
        step = self.addCustomStep(0, first_arg, varargin{:});   %Case 2
      elseif nargin == 3
        % If we only have one numerical argument it must be a simple time step.
        % What fall through should be (number, at_least_another_arg, *arg)
        if first_arg < 0
          step = self.addTimeStep(-first_arg, first_arg);
        else
          step = self.addTimeStep(first_arg, 0);  %Case 1
        end
      elseif isnumeric(varargin{1})
        % If we only have two numerical argument it must be a simple time step
        % with custom offset.
        % What fall through should be (number, not_number, *arg)

        % TODO: for absolute time, also check if the first arg is an absolute
        % time object.
        if nargin > 4
          error('addStep called with too many arguments.');
        end
        offset = varargin{1};
        if ~is_background && offset + first_arg < 0
          error('Implicitly going back in time is not allowed.');
        end
        step = self.addTimeStep(first_arg, offset);
      else
        % The not_number must be a custom step. Do it.
        step = self.addCustomStep(first_arg, varargin{:});
      end
    end

    %%
    function step = addTimeStep(self, len, offset)
        %step [TimeStep] = addTimeStep(self [ExpSeqBase], len, offset)
            %addTimeStep makes an empty TimeStep object 'step' and adds it to subSeqs
            %of self.  A pulse is added to the TimeStep by applying add
            %(equiv to addPulse) to the TimeStep.
            %addTimeStep and addCustomStep are the only functions that add
            %TimeStep objects (which contain pulses).  All above methods eventually call one of these
            %mtehods.

      if len <= 0
        error('Length of time step must be positive.');
      end

      self.curTime = self.curTime + offset;
      step = TimeStep(self, self.curTime, len); %makes a TimeStep object 'step', and adds it to the subSeq of self.
      self.curTime = self.curTime + len;
    end

    %%
    function step = addCustomStep(self, offset, cls, varargin)
        % step [TimeStep] = addCustomStep(self [ExpSeq], offset, cls [function handle], varargin [optional])
            %Inserts a new ExpSeqBase in self.subSeqs, then applies the
            %function handle cls to it. Advances self.curTime.
            %addTimeStep and addCustomStep are the only functions that add
            %TimeStep objects (which contain pulses).  All above methods eventually call one of these
            %mtehods.


      if ischar(cls)  %if cls is string, converts to function handle
        cls = str2func(cls);
      end

      self.curTime = self.curTime + offset; %advance current time
      step = ExpSeqBase(self, self.curTime); %creates ExpSeqBase in self.subSeqs.
      % return proxy since I'm not sure there's a good way to forward
      % return values in matlab, especially since the return value can
      % depend on the number of return values.
      cls(step, varargin{:}); %runs the function handle
      self.curTime = self.curTime + step.curTime;
    end
  end
end
