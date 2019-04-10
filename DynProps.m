%% Copyright (c) 2018-2018, Yichao Yu <yyc1992@gmail.com>
%
% This library is free software; you can redistribute it and/or
% modify it under the terms of the GNU Lesser General Public
% License as published by the Free Software Foundation; either
% version 3.0 of the License, or (at your option) any later version.
% This library is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
% Lesser General Public License for more details.
% You should have received a copy of the GNU Lesser General Public
% License along with this library.

%%
% This is a class that provides an flexible API to access a nested struct with support
% of default values.
classdef DynProps < handle
    properties(Hidden)
        V;
    end
    methods(Static, Access=private)
        function [a, changed] = merge_struct(a, b, changed, undefnan)
            fns = fieldnames(b);
            for i = 1:length(fns)
                name = fns{i};
                newv = b.(name);
                if ~DynProps.isfield_def(a, name, undefnan)
                    changed = true;
                    a.(name) = newv;
                    continue;
                end
                defv = a.(name);
                if ~DynProps.isscalarstruct(defv) || ~DynProps.isscalarstruct(newv)
                    continue;
                end
                [a.(name), changed] = DynProps.merge_struct(defv, newv, changed, undefnan);
            end
        end
        function res = isfield_def(a, name, undefnan)
            if ~isfield(a, name)
                res = false;
            elseif ~undefnan
                res = true;
            else
                res = ~DynProps.isnanobj(a.(name));
            end
        end
        function res = isnanobj(obj)
            if ~isnumeric(obj)
                res = false;
                return;
            end
            res = isnan(obj);
        end
        function res = construct_struct(varargin)
            res = struct();
            i = 1;
            while i <= nargin
                v = varargin{i};
                if ~DynProps.isscalarstruct(v)
                    i = i + 1;
                    v = struct(v, varargin{i});
                end
                res = DynProps.merge_struct(res, v, 0, 1);
                i = i + 1;
            end
        end
    end
    methods(Static)
        function res = isscalarstruct(obj)
            if ~isstruct(obj)
                res = false;
            elseif ~isscalar(obj)
                res = false;
            else
                res = true;
            end
        end
    end
    methods
        function self = DynProps(V)
            if ~exist('V', 'var')
                V = struct();
            end
            self.V = V;
        end
        function res = getfields(self, varargin)
            res = struct();
            if isempty(varargin)
                return;
            end
            if DynProps.isscalarstruct(varargin{1})
                res = varargin{1};
                args = varargin{2:end};
            else
                args = varargin;
            end
            for i = 1:length(args)
                arg = args{i};
                v = self.V.(arg);
                if DynProps.isnanobj(v)
                    % Treat NaN as missing value
                    V = rmfield(self.V, arg);
                    % This throws the error similar to
                    % when access a undefined field in matlab
                    V.(arg);
                    %% unreachable
                    return;
                end
                res.(arg) = v;
            end
        end
        function res = fieldnames(self)
            res = fieldnames(self.V);
        end
        function res = subfieldnames(self, S)
            nS = length(S);
            % Scan through all the '.' in the leading access items
            v = self.V;
            for i = 1:nS
                switch S(i).type
                    case '.'
                        name = S(i).subs;
                        if isfield(v, name)
                            newv = v.(name);
                            % Treat NaN as missing value
                            if ~DynProps.isnanobj(newv)
                                v = newv;
                                continue;
                            end
                        end
                        res = {};
                        return;
                    otherwise
                        res = {};
                        return;
                end
            end
            res = fieldnames(v);
        end
        function B = subsref(self, S)
            nS = length(S);
            % Scan through all the '.' in the leading access items
            v = self.V;
            for i = 1:nS
                switch S(i).type
                    case '.'
                        name = S(i).subs;
                        if isfield(v, name)
                            newv = v.(name);
                            % Treat NaN as missing value
                            if ~DynProps.isnanobj(newv)
                                v = newv;
                                continue;
                            else
                                % Remove the field so that the error below can be
                                % triggerred correctly.
                                v = rmfield(v, name);
                            end
                        end
                        j = i;
                        found = 0;
                        % Check if this is an access with default
                        while j <= nS
                            switch S(j).type
                                case '.'
                                    j = j + 1;
                                    continue;
                                case {'()', '{}'}
                                    found = 1;
                            end
                            break;
                        end
                        if ~found
                            B = SubProps(self, S);
                            return;
                        end
                        if isempty(S(j).subs)
                            error('No default value given');
                        elseif length(S(j).subs) ~= 1
                            def = DynProps.construct_struct(S(j).subs{:});
                        else
                            def = S(j).subs{1};
                            if DynProps.isnanobj(def)
                                error('Default value cannot be NaN.');
                            end
                        end
                        % Assign default value
                        if j == 1
                            self.V = def;
                        else
                            self.V = subsasgn(self.V, S(1:j - 1), def);
                        end
                        if strcmp(S(j).type, '{}')
                            def = SubProps(self, S(1:j - 1));
                        end
                        if j == nS
                            B = def;
                        else
                            B = subsref(def, S(j + 1:end));
                        end
                        return;
                    case {'()', '{}'}
                        if ~isempty(S(i).subs)
                            if length(S(i).subs) ~= 1
                                def = DynProps.construct_struct(S(i).subs{:});
                            else
                                def = S(i).subs{1};
                                if DynProps.isnanobj(def)
                                    error('Default value cannot be NaN.');
                                end
                            end
                            if DynProps.isscalarstruct(v) & DynProps.isscalarstruct(def)
                                [v, changed] = DynProps.merge_struct(v, def, false, true);
                                if changed
                                    if i == 1
                                        self.V = v;
                                    else
                                        self.V = subsasgn(self.V, S(1:i - 1), v);
                                    end
                                end
                            end
                        end
                        if strcmp(S(i).type, '{}')
                            v = SubProps(self, S(1:i - 1));
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
            if DynProps.isscalarstruct(v)
                B = SubProps(self, S);
            else
                B = v;
            end
        end
        function A = subsasgn(self, S, B)
            A = self;
            self.V = subsasgn(self.V, S, B);
        end
        function disp(self)
            fprintf('DynProps:\n  %s\n', YAML.sprint(self.V, 2, true));
        end
        function display(self, name)
            fprintf('%s = ', name);
            disp(self);
        end
        function subdisp(self, S)
            path = ['.', strjoin({S.subs}, '.')];
            fprintf('SubProps{DynProps}: ');
            cprintf('*magenta', '[%s]\n  ', path);
            nS = length(S);
            v = self.V;
            for i = 1:nS
                switch S(i).type
                    case '.'
                        name = S(i).subs;
                        if isfield(v, name)
                            newv = v.(name);
                            % Treat NaN as missing value
                            if ~DynProps.isnanobj(newv)
                                v = newv;
                                continue;
                            end
                        end
                        fprintf('{}');
                        return;
                    otherwise
                        fprintf('{}');
                        return;
                end
            end
            YAML.print(v, 2, true);
        end
        function subdisplay(self, S, name)
            fprintf('%s = ', name);
            subdisp(self, S);
        end
    end
end
