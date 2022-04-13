%% Copyright (c) 2021-2021, Yichao Yu <yyc1992@gmail.com>
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

classdef ScanAccessTracker < handle
    % Record and warn about unused scan parameters to catch naming errors.
    % The access is computed per-scan in a scan group.
    % As long as one of the sequence in a scan accessed a parameter it's counted as used.
    % This is to avoid false-positive warning when scanning over a parameter (e.g. time)
    % that disables part of the code which make some parameters unused in that sequence.
    properties(Access=private)
        % There's one scan_infos element per scan in a scan group
        % `accessed` is the union of all the parameter that are accessed from all the sequences
        % within the scan.
        % `seq_left` counts the number of sequences we still need to run in the scan.
        % `checked` is whether the scan has been checked for unused parameters.
        scan_infos = struct('fixed', {}, 'vars', {}, 'accessed', {}, ...
                            'seq_left', {}, 'checked', {});

        % From global sequece index to scans index.
        scan_index = [];
        % Whether a sequence has been run
        collected = logical.empty();
    end

    methods(Access=private)
        function process_scan(self, scan_idx)
            info = self.scan_infos(scan_idx);
            if info.checked
                return;
            end
            self.scan_infos(scan_idx).checked = true;

            % Don't print backtrace since it's not very useful (doesn't point to user code)
            state = warning('off', 'backtrace');
            cleanup = FacyOnCleanup(@(state) warning(state), state);
            unused_fixed = ScanAccessTracker.compute_unused(info.fixed, info.accessed);
            unused_vars = ScanAccessTracker.compute_unused(info.vars, info.accessed);
            ScanAccessTracker.warn_unused(unused_fixed, scan_idx, true);
            ScanAccessTracker.warn_unused(unused_vars, scan_idx, false);
        end
    end

    methods(Static, Access=private)
        function v = to_bool_struct(v)
            if ~DynProps.isscalarstruct(v)
                v = true;
                return;
            end
            fns = fieldnames(v);
            for i = 1:length(fns)
                name = fns{i};
                v.(name) = ScanAccessTracker.to_bool_struct(v.(name));
            end
        end

        function v = merge_struct(v, v2)
            if ~isstruct(v) || ~isstruct(v2)
                v = true;
                return;
            end
            fns = fieldnames(v2);
            for i = 1:length(fns)
                name = fns{i};
                if ~isfield(v, name)
                    v.(name) = v2.(name);
                else
                    v.(name) = ScanAccessTracker.merge_struct(v.(name), v2.(name));
                end
            end
        end

        function params = compute_unused(params, accessed)
            if ~isstruct(accessed)
                params = struct();
                return;
            elseif ~isstruct(params)
                return;
            end
            fns = fieldnames(params);
            for i = 1:length(fns)
                name = fns{i};
                if ~isfield(accessed, name)
                    continue;
                end
                sub_params = ScanAccessTracker.compute_unused(params.(name), accessed.(name));
                if isstruct(sub_params) && isempty(fieldnames(sub_params))
                    params = rmfield(params, name);
                else
                    params.(name) = sub_params;
                end
            end
        end

        function str = show_unused(s, indent, needs_dot)
            str = '';
            if ~isstruct(s)
                return;
            end
            fns = fieldnames(s);
            prefix = repmat(' ', 1, indent);
            for i = 1:length(fns)
                name = fns{i};
                if i ~= 1
                    str = [str, 10, prefix];
                end
                subindent = indent + length(name);
                if needs_dot
                    str = [str, '.', name];
                    subindent = subindent + 1;
                else
                    str = [str, name];
                end
                str = [str, ScanAccessTracker.show_unused(s.(name), subindent, true)];
            end
        end

        function warn_unused(unused, scan_idx, fixed)
            fns = fieldnames(unused);
            nfld = length(fns);
            if nfld == 0
                return;
            end
            if fixed
                msg = sprintf('Unused fixed parameters in scan #%d:', scan_idx);
            else
                msg = sprintf('Unused scanning parameters in scan #%d:', scan_idx);
            end
            warning([msg, 10, '  ', ScanAccessTracker.show_unused(unused, 2, false)]);
        end
    end

    methods
        function self = ScanAccessTracker(sg)
            nscans = groupsize(sg);
            for i = 1:nscans
                self.scan_infos(i).accessed = struct();
                ss = scansize(sg, i);
                self.scan_index(end + 1:end + ss) = i;
                self.scan_infos(i).seq_left = ss;
                self.scan_infos(i).checked = false;

                % Collect parameters from the scan.
                self.scan_infos(i).fixed = ScanAccessTracker.to_bool_struct(get_fixed(sg, i));
                vars = struct();
                for j = 1:scandim(sg, i)
                    new_vars = ScanAccessTracker.to_bool_struct(get_vars(sg, i, j));
                    vars = ScanAccessTracker.merge_struct(vars, new_vars);
                end
                self.scan_infos(i).vars = vars;
            end
            self.collected(1:length(self.scan_index)) = false;
        end

        function record_access(self, idx, accessed)
            scan_idx = self.scan_index(idx);
            accessed = ScanAccessTracker.merge_struct(self.scan_infos(scan_idx).accessed, ...
                                                      accessed);
            self.scan_infos(scan_idx).accessed = accessed;
            mark_collected(self, idx);
        end
        function mark_collected(self, idx)
            % Calling this currently have the safe effect as calling `record_access`
            % with an empty `accessed` struct.
            % Use a separate function here in case we also want to add warning
            % for individual sequences rather than for the whole scan.
            if self.collected(idx)
                return;
            end
            self.collected(idx) = true;
            scan_idx = self.scan_index(idx);
            count = self.scan_infos(scan_idx).seq_left - 1;
            self.scan_infos(scan_idx).seq_left = count;
            if count == 0
                process_scan(self, scan_idx);
            end
        end
        function force_check(self)
            % In case we aren't running some of the sequences,
            % force a check if we know we've run all the sequences we'll ever run.
            for i = 1:length(self.scan_infos)
                process_scan(self, i);
            end
        end
    end
end
