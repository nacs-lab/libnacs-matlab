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

classdef expSeqBase < timeSeq
  properties(Hidden, Access=private)
    curTime = 0;
  end

  methods
    function self = expSeqBase(varargin)
      self = self@timeSeq(varargin{:2});
    end

    function step = addStep(self, first_arg, varargin)
      %% addStep(len[, offset=0])
      %%     Add a #timeStep with len and offset from the last step
      %% addStep([offset=0, ]class_or_func, *extra_args)
      %%     Construct a step or sub sequence with @class_or_func(*extra_args)

      %%     If offset is not an absolute time (TODO: abstime not supported yet),
      %%     forward @self.curTime by the length of the step.
      if nargin <= 1
        error('addStep called with too few arguments.');
      elseif ~isnumerical(first_arg)
        %% If first arg is not a number, assume to be a custom step.
        %% What fall through should be (number, *arg)

        %% TODO: for absolute time, also check if the first arg is an absolute
        %% time object.
        step = self.addCustomStep(0, first_arg, varargin{:});
      elseif nargin == 2
        %% If we only have one numerical argument it must be a simple time step.
        %% What fall through should be (number, at_least_another_arg, *arg)
        step = self.addTimeStep(first_arg, 0);
      elseif isnumerical(varargin{1})
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
      step = timeStep(self, self.curTime, len);
      self.curTime = self.curTime + len;
    end
    function step = addCustomStep(self, offset, cls, varargin)
      if ischar(cls)
        cls = str2func(cls);
      end
      self.curTime = self.curTime + offset;
      proxy = expSeqBase(self, self.curTime);
      step = cls(proxy, varargin{:});
      self.curTime = self.curTime + proxy.curTime;
    end
  end

  %% methods(Access=protected)
  %%   function time = getCurTime(self)
  %%     time = self.curTime;
  %%   end
  %% end
end
