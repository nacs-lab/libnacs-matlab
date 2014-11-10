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

classdef ExpSeq < ExpSeqBase
  properties(Access=private)
    drivers;
  end

  methods
    function self = ExpSeq(name)
      if nargin < 1
        name = 'seq';
      elseif ~ischar(name)
        error('Sequence name must be a string.');
      end
      self = self@ExpSeqBase(name);
      self.drivers = containers.Map();
    end
  end
end
