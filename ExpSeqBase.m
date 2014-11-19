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
    end

    function res = wait(self, t)
      self.curTime = self.curTime + t;
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
      step = self.addStep(varargin{:});
      self.curTime = old_time;
    end

    function step = addStep(self, first_arg, varargin)
      %% addStep(len[, offset=0])
      %%     Add a #TimeStep with len and offset from the last step
      %% addStep([offset=0, ]class_or_func, *extra_args)
      %%     Construct a step or sub sequence with @class_or_func(*extra_args)

      %%     If offset is not an absolute time (TODO: abstime not supported yet),
      %%     forward @self.curTime by the length of the step.
      if nargin <= 1
        error('addStep called with too few arguments.');
      elseif ~isnumeric(first_arg)
        %% If first arg is not a number, assume to be a custom step.
        %% What fall through should be (number, *arg)

        %% TODO: for absolute time, also check if the first arg is an absolute
        %% time object.
        step = self.addCustomStep(0, first_arg, varargin{:});
      elseif nargin == 2
        %% If we only have one numerical argument it must be a simple time step.
        %% What fall through should be (number, at_least_another_arg, *arg)
        step = self.addTimeStep(first_arg, 0);
      elseif isnumeric(varargin{1})
        %% If we only have two numerical argument it must be a simple time step
        %% with custom offset.
        %% What fall through should be (number, not_number, *arg)

        %% TODO: for absolute time, also check if the first arg is an absolute
        %% time object.
        if nargin > 3
          error('addStep called with too many arguments.');
        end
        step = self.addTimeStep(first_arg, varargin{1});
      else
        %% The not_number must be a custom step. Do it.
        step = self.addCustomStep(first_arg, varargin{:});
      end
    end
  end

  methods(Access=private)
    function step = addTimeStep(self, len, offset)
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
