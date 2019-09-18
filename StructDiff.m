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

classdef StructDiff
    properties(Hidden)
        v1;
        v2;
    end
    methods(Static, Access=private)
        function res = compare(v1, v2)
            try
                s1 = isscalar(v1);
                s2 = isscalar(v2);
                if ischar(v1) && ischar(v2)
                    res = strcmp(v1, v2);
                elseif ~s1 && ~s2
                    if ndims(v1) ~= ndims(v2) || ~all(size(v1) == size(v2))
                        res = false;
                    else
                        res = all(v1 == v2);
                    end
                elseif s1 && s2
                    res = v1 == v2;
                else
                    res = false;
                end
            catch
                res = false;
            end
        end
        function [d1, d2] = compute_real(v1, v2)
            d1 = struct();
            d2 = struct();
            fns1 = fieldnames(v1);
            for i = 1:length(fns1)
                name = fns1{i};
                f1 = v1.(name);
                if ~isfield(v2, name)
                    d1.(name) = f1;
                    continue;
                end
                f2 = v2.(name);
                if DynProps.isscalarstruct(f1) && DynProps.isscalarstruct(f2)
                    [df1, df2] = StructDiff.compute_real(f1, f2);
                    if ~isempty(fieldnames(df1))
                        d1.(name) = df1;
                    end
                    if ~isempty(fieldnames(df2))
                        d2.(name) = df2;
                    end
                elseif ~StructDiff.compare(f1, f2)
                    d1.(name) = f1;
                    d2.(name) = f2;
                end
            end
            fns2 = fieldnames(v2);
            for i = 1:length(fns2)
                name = fns2{i};
                if ~isfield(v1, name)
                    d2.(name) = v2.(name);
                end
            end
        end
        % All printing should have a indent of at least `indent`.
        % For `toplevel`, the first line already has an indent of `indent`,
        % outputs without additional prefix should be outputed with an indent of
        % `indent` (implicit for the first line)
        % and additional indent is needed when new prefix is added/printed.
        % For non `toplevel`, the first line already have prefix printed.
        % Only additional prefix should be printed without new line.
        % Outputs without additional prefix should be outputed after a new line
        % with an indent of `indent` after.
        % The output always ends with a new line.
        function print(v1, v2, indent, toplevel)
            spaces = [repmat(' ', 1, indent)];
            if ~DynProps.isscalarstruct(v1) || ~DynProps.isscalarstruct(v2)
                assert(~toplevel);
                fprintf(':\n');
                cprintf('red', '%s- %s\n', spaces, ...
                        YAML.sprint(v1, indent + 2, true));
                cprintf('green', '%s+ %s\n', spaces, ...
                        YAML.sprint(v2, indent + 2, true));
                return;
            end

            fns1 = fieldnames(v1);
            fns2 = fieldnames(v2);

            % If there's only one field difference and it's the same for both
            % Print the single prefix and
            % move on to print the field value under the longer prefix.
            if length(fns1) == 1 && length(fns2) == 1 && strcmp(fns1{1}, fns2{1})
                name = fns1{1};
                if toplevel
                    fprintf('%s', name);
                    indent = indent + 2;
                else
                    fprintf('.%s', name);
                end
                StructDiff.print(v1.(name), v2.(name), indent, false);
                return;
            end

            has_output = false;

            % More than one fields to print.

            % First print the fields that only exist in one.
            % Terminate the prefix line we are currently on with `:\n` if needed
            % and print the diff with `+` or `-` prefix and additional indentation.
            for i = 1:length(fns1)
                name = fns1{i};
                if isfield(v2, name)
                    continue;
                end
                if ~has_output
                    has_output = true;
                    if ~toplevel
                        fprintf(':\n%s', spaces)
                    end
                else
                    fprintf('%s', spaces);
                end
                cprintf('red', '- %s:\n    %s%s\n', name, spaces, ...
                        YAML.sprint(v1.(name), indent + 4, true));
            end
            for i = 1:length(fns2)
                name = fns2{i};
                if isfield(v1, name)
                    continue;
                end
                if ~has_output
                    has_output = true;
                    if ~toplevel
                        fprintf(':\n%s', spaces)
                    end
                else
                    fprintf('%s', spaces);
                end
                cprintf('green', '+ %s:\n    %s%s\n', name, spaces, ...
                        YAML.sprint(v2.(name), indent + 4, true));
            end

            for i = 1:length(fns1)
                name = fns1{i};
                if ~isfield(v2, name)
                    continue;
                end
                if ~has_output
                    has_output = true;
                    if ~toplevel
                        fprintf(':\n%s', spaces)
                    end
                else
                    fprintf('%s', spaces);
                end
                fprintf('%s', name);
                StructDiff.print(v1.(name), v2.(name), indent + 2, false);
            end

            if ~has_output
                % I don't think this can actually happen....
                fprintf('\n');
            end
        end
        function v = get_struct(v)
            if isa(v, 'ExpSeq')
                v = v.C();
            elseif isa(v, 'DynProps')
                v = v();
            elseif isa(v, 'SubProps') && isa(get_parent(v), 'DynProps')
                v = v();
            end
        end
    end
    methods(Static)
        function [d1, d2] = compute(v1, v2)
            v1 = StructDiff.get_struct(v1);
            v2 = StructDiff.get_struct(v2);
            if ~DynProps.isscalarstruct(v1) || ~DynProps.isscalarstruct(v2)
                error('Input must be scalar structures');
            end
            [d1, d2] = StructDiff.compute_real(v1, v2);
        end
    end
    methods
        function self = StructDiff(v1, v2)
            [self.v1, self.v2] = StructDiff.compute(v1, v2);
        end
        function disp(self)
            if isempty(fieldnames(self.v1)) && isempty(fieldnames(self.v2))
                fprintf('StructDiff:\n  ');
                cprintf('blue', '<empty>\n');
            else
                fprintf('StructDiff: ');
                cprintf('red', '-1 ');
                cprintf('green', '+2');
                fprintf('\n  ');
                StructDiff.print(self.v1, self.v2, 2, true);
            end
        end
        function display(self, name)
            fprintf('%s = ', name);
            disp(self);
        end
    end
end
