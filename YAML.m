%% Copyright (c) 2019-2019, Yichao Yu <yyc1992@gmail.com>
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

classdef YAML
    methods(Static)
        function str = sprint(s, indent, relaxed)
            if ~exist('indent', 'var')
                indent = 0;
            end
            if ~exist('relaxed', 'var')
                relaxed = 0;
            end
            str = YAML.print_generic(s, indent, indent, relaxed);
        end
        function print(varargin)
            fprintf('%s\n', YAML.sprint(varargin{:}));
        end
    end
    methods(Static, Access=private)
        function str = print_generic(s, indent, cur_indent, relaxed)
            if isscalar(s) && ~iscell(s)
                % Length-1 cell array is `isscalar` but we still want
                % to treat it as array.
                str = YAML.print_scalar(s, indent, cur_indent, relaxed);
            else
                str = YAML.print_array(s, indent, cur_indent, relaxed);
            end
        end

        function res = needs_quote(s) % Assuming string non-empty
            if s(1) == ' ' || s(end) == ' '
                res = true;
                return;
            end
            % Good enough for now........
            if regexp(s, '[":\n\b\\]')
                res = true;
                return;
            end
            res = false;
        end

        function str = print_string(s, indent, cur_indent, relaxed)
            s = char(s);
            if isempty(s)
                str = '""';
                return;
            end
            if YAML.needs_quote(s)
                s = strrep(s, '\', '\\');
                s = strrep(s, '"', '\"');
                s = strrep(s, char(8), '\b');
                s = strrep(s, char(10), '\n');
                str = ['"', s, '"'];
            else
                str = s;
            end
            if indent < cur_indent && cur_indent + length(str) > 85
                str = [char(10), repmat(' ', 1, indent), str];
            end
        end

        function str = print_single_field_struct(s, indent, cur_indent, relaxed)
            strary = {};
            while isstruct(s) && isscalar(s)
                fields = fieldnames(s);
                if length(fields) ~= 1
                    break;
                end
                field = fields{1};
                strary{end + 1} = field;
                s = s.(field);
            end
            if relaxed
                str = [strjoin(strary, '.'), ':'];
            else
                str = [strjoin(strary, ': '), ':'];
            end
            strfield = YAML.print_generic(s, indent + 2, indent + length(str) + 1, relaxed);
            if ~isempty(strfield) && strfield(1) ~= char(10)
                str = [str, ' ', strfield];
            else
                str = [str, strfield];
            end
            if indent < cur_indent
                str = [char(10), repmat(' ', 1, indent), str];
            end
        end

        function str = print_struct(s, indent, cur_indent, relaxed)
            fields = fieldnames(s);
            if isempty(fields)
                str = '{}';
                return;
            elseif length(fields) == 1
                str = YAML.print_single_field_struct(s, indent, cur_indent, relaxed);
                return;
            end
            strary = cell(1, length(fields));
            for i = 1:length(fields)
                name = fields{i};
                strary{i} = [name, ': ', ...
                             YAML.print_generic(s.(name), indent + 2 + length(name), ...
                                                indent + 2 + length(name), relaxed)];
            end
            str = [strjoin(strary, [char(10) repmat(' ', 1, indent)])];
            if indent < cur_indent
                str = [char(10), repmat(' ', 1, indent), str];
            end
        end

        function str = print_scalar(s, indent, cur_indent, relaxed)
            if islogical(s)
                if s
                    str = 'true';
                else
                    str = 'false';
                end
            elseif isnumeric(s)
                str = num_to_str(s);
            elseif isstruct(s)
                str = YAML.print_struct(s, indent, cur_indent, relaxed);
            elseif ischar(s) || isstring(s)
                str = YAML.print_string(s, indent, cur_indent, relaxed);
            else
                str = '"<unknown object>"';
            end
        end

        function str = print_array(ary, indent, cur_indent, relaxed)
            if isvector(ary) && ischar(ary)
                str = YAML.print_string(ary, indent, cur_indent, relaxed);
                return;
            end
            nele = numel(ary);
            if nele == 0
                str = '[]';
                return;
            end
            if isnumeric(ary) || islogical(ary)
                threshold = 85 - cur_indent;
                if threshold < 50
                    threshold = 50;
                end
                % Print all arrays as vector for now...
                single_line = indent < cur_indent;
                prefix = '[';
                len = 0;
                strary = {};
                for i = 1:nele
                    s = num_to_str(ary(i));
                    if len > threshold && i < nele % at least two elements on the last line
                        prefix = [prefix strjoin(strary, ', '), ',', char(10), ...
                                  repmat(' ', 1, indent + 1)];
                        if single_line
                            single_line = false;
                            threshold = 85 - indent;
                            if threshold < 50
                                threshold = 50;
                            end
                            prefix = [char(10), repmat(' ', 1, indent), prefix];
                        end
                        strary = {};
                        len = 0;
                    end
                    strary{end + 1} = s;
                    len = len + length(s) + 2;
                end
                str = [prefix strjoin(strary, ', '), ']'];
                return;
            elseif iscell(ary)
                strary = cell(1, nele);
                for i = 1:nele
                    strary{i} = YAML.print_generic(ary{i}, indent + 2, indent + 2, relaxed);
                end
                str = ['- ' strjoin(strary, [char(10) repmat(' ', 1, indent) '- '])];
            else
                strary = cell(1, nele);
                for i = 1:nele
                    strary{i} = YAML.print_generic(ary(i), indent + 2, indent + 2, relaxed);
                end
                str = ['- ' strjoin(strary, [char(10) repmat(' ', 1, indent) '- '])];
            end
            if indent < cur_indent
                str = [char(10), repmat(' ', 1, indent), str];
            end
        end
    end
end
