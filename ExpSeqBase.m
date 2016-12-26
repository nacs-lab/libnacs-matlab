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
  properties(Hidden, Access=protected)
    curTime = 0;
  end

  methods
    function self = ExpSeqBase(varargin)
      if nargin >= 3
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

    function res = wait(self, t)
      self.curTime = self.curTime + t;
      res = self;
    end

    function res = waitAll(self)
      %% Wait for everything that have been currently added to finish.
      self.curTime = self.length();
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
        %% TODO? find a better way to determine the step length or figure out
        %% a way to add zero length pulse.
        len = 1e-5;
      end
      self.addBackground(@(s) s.addStep(len).add(name, pulse));
      step = self;
    end

    function step = addBackground(self, varargin)
      old_time = self.curTime;
      step = self.addStepReal(true, varargin{:});
      self.curTime = old_time;
    end

    function step = addStep(self, varargin)
      step = self.addStepReal(false, varargin{:});
    end
  end

  methods(Access=private)
    function step = addStepReal(self, is_background, first_arg, varargin)
      %% addStep(len[, offset=0])
      %%     Add a #TimeStep with len and offset from the last step
      %% addStep([offset=0, ]class_or_func, *extra_args)
      %%     Construct a step or sub sequence with @class_or_func(*extra_args)

      %%     If offset is not an absolute time (TODO: abstime not supported yet),
      %%     forward @self.curTime by the length of the step.
      if nargin <= 2
        error('addStep called with too few arguments.');
      elseif ~isnumeric(first_arg)
        %% If first arg is not a number, assume to be a custom step.
        %% What fall through should be (number, *arg)

        %% TODO: for absolute time, also check if the first arg is an absolute
        %% time object.
        step = self.addCustomStep(0, first_arg, varargin{:});
      elseif nargin == 3
        %% If we only have one numerical argument it must be a simple time step.
        %% What fall through should be (number, at_least_another_arg, *arg)
        if first_arg < 0
          step = self.addTimeStep(-first_arg, first_arg);
        else
          step = self.addTimeStep(first_arg, 0);
        end
      elseif isnumeric(varargin{1})
        %% If we only have two numerical argument it must be a simple time step
        %% with custom offset.
        %% What fall through should be (number, not_number, *arg)

        %% TODO: for absolute time, also check if the first arg is an absolute
        %% time object.
        if nargin > 4
          error('addStep called with too many arguments.');
        end
        offset = varargin{1};
        if ~is_background && offset + first_arg < 0
          error('Implicitly going back in time is not allowed.');
        end
        step = self.addTimeStep(first_arg, offset);
      else
        %% The not_number must be a custom step. Do it.
        step = self.addCustomStep(first_arg, varargin{:});
      end
    end

    function step = addTimeStep(self, len, offset)
      if len <= 0
        error('Length of time step must be positive.');
      end
      self.curTime = self.curTime + offset;
      step = TimeStep(self, self.curTime, len);
      self.curTime = self.curTime + len;
    end

    function step = addCustomStep(self, offset, cls, varargin)
      if ischar(cls)
        cls = str2func(cls);
      end
      self.curTime = self.curTime + offset;
      step = ExpSeqBase(self, self.curTime);
      %% return proxy since I'm not sure there's a good way to forward
      %% return values in matlab, especially since the return value can
      %% depend on the number of return values.
      cls(step, varargin{:});
      self.curTime = self.curTime + step.curTime;
    end
  end
end
