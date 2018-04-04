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
    V;
  end
  methods(Access=private)
  end
  methods
    function self = DynProps(V)
      if ~exist('V', 'var')
        V = struct();
      end
      self.V = V;
    end
    function B = subsref(self, S)
      nS = length(S);
      %% Scan through all the '.' in the leading access items
      v = self.V;
      for i = 1:nS
        switch S(i).type
          case '.'
            name = S(i).subs;
            if isfield(v, name)
              v = v.(name);
              continue;
            end
            j = i;
            found = 0;
            % Check if this is an access with default
            while j <= nS
              switch S(j).type
                case '.'
                  j = j + 1;
                  continue;
                case '()'
                  found = 1;
              end
              break;
            end
            if ~found
              % This throws the error similar to when access a undefined field in matlab
              B = v.(name);
              % The return here is just to make the control flow more clear and should never be
              % reached.
              return;
            end
            if length(S(j).subs) ~= 1
              error('More than one default value');
            end
            def = S(j).subs{1};
            % Assign default value
            self.V = subsasgn(self.V, S(1:j - 1), def);
            if j == nS
              B = def;
            else
              B = subsref(def, S(j + 1:end));
            end
            return;
          case '()'
            if length(S(i).subs) ~= 1
              error('More than one default value');
            end
            if i == nS
              B = v;
            else
              B = subsref(v, S(i + 1:end));
            end
            return;
          otherwise
            B = subsref(v, S(i:end));
            return;
        end
      end
      if isstruct(v)
        B = SubProps(self, S);
      else
        B = v;
      end
    end
    function A = subsasgn(self, S, B)
      A = self;
      self.V = subsasgn(self.V, S, B);
    end
  end
end
