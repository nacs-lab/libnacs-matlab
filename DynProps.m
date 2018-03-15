%% Copyright (c) 2018-2018, Yichao Yu <yyc1992@gmail.com>
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

classdef DynProps < handle
  properties(Hidden)
    V
  end
  methods
    function self = DynProps(V)
      if ~exist('V', 'var')
        V = struct();
      end
      self.V = V;
    end
    function B = subsref(self, S)
      def = 0;
      has_def = 0;
      switch S(1).type
        case '.'
          if length(S) > 2
            error('Too many levels of indexing');
          elseif length(S) == 2
            switch S(2).type
              case '()'
                if length(S(2).subs) ~= 1
                  error('More than one default value');
                end
                has_def = 1;
                def = S(2).subs{1};
              otherwise
                error('Second level indexing must be `()`');
            end
          end
          name = S(1).subs;
          if isfield(self.V, name)
            B = self.V.(name);
            return;
          end
          if ~has_def
            error('Undefined constant');
          end
          self.V.(name) = def;
          B = def;
          return;
        otherwise
          error('First level indexing must be `.`');
      end
    end
    function A = subsasgn(self, S, B)
      A = self;
      if length(S) > 1
        error('Too many levels of indexing in assignment');
      end
      switch S(1).type
        case '.'
          name = S(1).subs;
          self.V.(name) = B;
        otherwise
          error('Assignment indexing must be `.`');
      end
    end
  end
end
