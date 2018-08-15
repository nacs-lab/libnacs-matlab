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
% Terminology:
% * Parameter: a nested struct that will be passed to `ExpSeq` as the context of a sequence.
% * Scan: a n-dimensional matrix of parameters to iterate over with sequences.
%     This is used to generate a list of parameters.
%     A scan may contain some fixed parameters and some variable parameters.
%     Represented by `ScanParam`.
% * Group: a (orderred) set of scans. Represented by `ScanGroup`.
% * Fallback (parameter/scan):
%     This contains the same information as a scan
%     (and is also represented by `ScanParam`)
%     but it does not correspond to any real sequence.
%     This contains the default fallback parameters for the real scans when the scan
%     does not have any value for a specific field.
% * Base index:
%     This is the index of the scan that is used as fallback for this scan.
%     If this is 0, the default one for the group is used.
% * Run parameter:
%     Parameters for the sequence runner rather than the sequences.
%     There can be only one per group.

%%
% This class represents a group of scans. Supported API:
% For sequence building:
% * grp() / grp() = ...:
%   grp(n) / grp(n) = ...:
%     Access the group's fallback parameter (`grp()`) or
%     the parameter for the n-th scan (`grp(n)`).
%     `n` can use `end` syntax for the number of scans.
%
%     Mutation to the fallback parameter will affect the fallback values of
%     **ALL** scans in this `ScanGroup` including future ones.
%
%     Read access returns a `ScanParam`.
%     Write access constructs a `ScanParam` to **replace** the existing one.
%     The RHS must be another `ScanParam` from the same `ScanGroup` or a `struct`.
%
%     For `ScanParam` RHS, everything is copied. Fallback values are not applied.
%     If the LHS is `grp()`, base index of the RHS is ignored (otherwise, it is copied).
%     For `struct` RHS, all fields are treated as non-scanning parameters.
%     Non-string array field will cause an error.
%     This (`struct` RHS) will also clear the scan and set the base index to `0` (default)
%     (base index ignored when LHS is `grp()`).
%
% * [grp1 grp2 ...] / [grp1, grp2, ...] / horzcat(grp1, grp2, ...):
%     Create a new `ScanGroup` that runs the individual all input scans
%     in the order they are listed.
%     The new group will **NOT** be affected if the inputs are mutated later.
%     The scans will all have their respected fallback parameters merged into them
%     and the base index reset to `0`.
%     The new group size (sequence count) will be the sum of that of the input
%     groups and the order of the scans/sequences will be maintained.
%     The run parameters will be the same as that of the first one.
%
% * setbase(grp, scan, base) / grp.setbase(scan, base):
%     Set the base index of the `scan` to `base`. A `0` `base` means the default base.
%     Throws an error if this would create a loop.
%
% All mutation on a scan (assignment and `setbase`) will make sure the scan being mutated
% is created if it didn't exist.
%
%
% For sequence running/saving/loading:
% * groupsize(grp) / grp.groupsize():
%     Number of scans in the group. (Each scan is a N-dimensional matrix)
%
% * scansize(grp, idx) / grp.scansize(idx):
%     Number of sequences in the specific (N-dimensional) scan.
%
% * nseq(grp) / grp.nseq():
%     Number of sequences in the group. This is the sum of `scansize` over all scans.
%
% * getseq(grp, n) / grp.getseq(n):
%     Get the n-th sequence parameter.
%
% * getseq_in_scan(grp, scan, n) / grp.getseq_in_scan(scan, n):
%     Get the n-th sequence parameter within the scan-th scan.
%
% * dump(grp) / grp.dump():
%     Return a low level MATLAB data structure that can be saved without
%     refering to any classes related to the scan.
%     This can be later loaded to create an identical scan.
%     If there are significant change on the representation of the scan,
%     the new version is expected to load and convert
%     the result generated by an older version without error.
%
% * ScanGroup.load(obj):
%     This is the reverse of `dump`. Returns a `ScanGroup` that is identical to the
%     one that generates the representation with `dump`.
%
%
% For both:
% * runp(grp) / grp.runp():
%     Run parameters. (parameters for RunSeq/RunScans etc)
%     The returned object is a `DynProps` and can be mutated.
%

%% WARNING!!!:
% Do **NOT** save this (or any) class to `mat` files.
% Saving class in mat files makes it almost (completely?) impossible
% to make major changes while keeping backward compatibility without
% renaming the class.
%
% Instead, one should store the necessary information as basic matlab types
% and allow convert from/to between the runtime format and the saving format.
% Ideally, this information should also be versioned so that future improvements
% can be added without breaking the loading of the old code.
classdef ScanGroup < handle
    properties(Constant, Access=?ScanParam)
        DEF_SCAN = struct('baseidx', 0, 'params', struct(), ...
                          'vars', struct('size', {}, 'params', {}));
        DEF_VARS = struct('size', 0, 'params', struct());
        DEF_SCANCACHE = struct('dirty', true, 'params', struct(), 'vars', struct());
    end
    properties(Access=?ScanParam)
        %% we don't use class here since
        % 1. it's annoy to use for simple stuff in MATLAB.
        % 2. it's harder to save (which I guess is also kind of annoy...)
        %
        % Structure:
        % * scans::array of Scan
        % * Scan: struct
        %     baseidx::integer (where to find the missing values for this group)
        %         A base index of `0` means that the base group is the toplevel base group.
        %     params::struct (simple structures holding the fixed parameters)
        %     vars::array of Scan1D
        %         Each element of the Scan1D array represent a scan dimension.
        %         The whole scan represent a rectangle N-dimension matrix.
        %         Different variables parameters are not allowed to have the same field.
        %         If this is empty, the group represent a single sequence.
        % * Scan1D: struct
        %     size::integer
        %         The size of the 1D scan. Must be greater than 1, (or 0)
        %         all the parameters in the scan must have the same length.
        %         0 size means a dummy/overwritten scan and should be ignored.
        %     params::struct
        %         Each array members of the struct represents a list of parameter to scan.
        scans = ScanGroup.DEF_SCAN;
        % * base::Scan
        %     This is the fallback parameter accessible by indexing without index, i.e. `grp()`.
        %     See above for the format of `Scan`.
        base = struct('params', struct(), 'vars', struct('size', {}, 'params', {}));
        runparam;

        %%
        % Fields below this line are caches that can be computed from the ones above
        % or book keeping information to keep these cache in sync.

        % Cache of the full scan after combining with the base scan.
        % The `dirty` flag marks whether this is invalid due to modification since last cache.
        % This should always be as long as `scans`.
        scanscache = ScanGroup.DEF_SCANCACHE;
    end
    methods
        function self=ScanGroup()
            self.runparam = DynProps();
        end
        function res=runp(self)
            res = self.runparam;
        end
        function obj=dump(self)
            obj.version = 1;
            obj.scans = self.scans;
            obj.base = self.base;
            obj.runparam = self.runparam();
        end
        function seq=getseq(self, n)
            for scani = 1:groupsize(self)
                ss = scansize(self, scani);
                if n <= ss
                    seq = getseq_in_scan(self, scani, n);
                    return;
                end
                n = n - ss;
            end
            error('Sequence index out of bound.');
        end
        function seq=getseq_in_scan(self, scanidx, seqidx)
            scan = getfullscan(self, scanidx);
            seq = scan.params;
            seqidx = seqidx - 1; % 0-based index from now on.
            function setparam_cb(v, path)
                seq = subsasgn(seq, path, v(subidx + 1));
            end
            for i=1:length(scan.vars)
                var = scan.vars(i);
                if var.size == 0
                    continue;
                end
                subidx = mod(seqidx, var.size); % 0-based
                seqidx = (seqidx - subidx) / var.size;
                ScanGroup.foreach_nonstruct(@setparam_cb, var.params);
            end
        end
        function res=nseq(self)
            res = 0;
            for i=1:groupsize(self)
                res = res + scansize(self, i);
            end
        end
        function res=scansize(self, idx)
            scan = getfullscan(self, idx);
            res = 1;
            for i = 1:length(scan.vars)
                sz1d = scan.vars(i).size;
                if sz1d ~= 0
                    res = res * sz1d;
                end
            end
        end
        function res=groupsize(self)
            res = length(self.scans);
        end
        function setbase(self, idx, base)
            % This always makes sure that the scan we set the base for exists
            % and is initialized. The cache entry for this will also be initialized.
            % The caller might depend on this behavior.
            if ~(base >= 0 && isscalar(base) && floor(base) == base)
                error('Base index must be non-negative integer.');
            elseif base > length(self.scans)
                error('Cannot set base to non-existing scan');
            elseif idx > length(self.scans)
                % New scan
                self.scans(length(self.scans) + 1:idx) = ScanGroup.DEF_SCAN;
                self.scans(idx).baseidx = base;
                self.scanscache(length(self.scanscache) + 1:idx) = ScanGroup.DEF_SCANCACHE;
                return;
            end
            % Fast pass to avoid invalidating anything
            if self.getbaseidx(idx) == base
                return;
            end
            if base == 0
                % Set back to default, no possibility of new loop.
                self.scans(idx).baseidx = base;
                self.scanscache(idx).dirty = true;
                return;
            end
            newbase = base;
            % Loop detection.
            visited = false(length(self.scans), 1);
            visited(idx) = true;
            while true
                if visited(base)
                    error('Base index loop detected.');
                end
                visited(base) = true;
                base = self.getbaseidx(base);
                if base == 0
                    break;
                end
            end
            self.scans(idx).baseidx = newbase;
            self.scanscache(idx).dirty = true;
        end
        function res=horzcat(varargin)
            res = ScanGroup();
            res.scans(end) = [];
            for i = 1:nargin
                grp = varargin{i};
                if ~isa(grp, 'ScanGroup')
                    error('Only ScanGroup allowed in concatenation.');
                end
                for j = 1:groupsize(grp)
                    scan = getfullscan(grp, j);
                    scan.baseidx = 0;
                    res.scans(end + 1) = scan;
                end
            end
            self = varargin{1};
            res.scanscache(1:length(res.scans)) = ScanGroup.DEF_SCANCACHE;
            res.runparam(self.runparam());
        end
        function res=get_fixed(self, idx)
            if idx == 0
                error('Out of bound scan index.');
            end
            scan = getfullscan(self, idx);
            res = scan.params;
        end
        function res=get_vars(self, idx, dim)
            if idx == 0
                error('Out of bound scan index.');
            end
            if ~exist('dim', 'var')
                dim = 1;
            end
            scan = getfullscan(self, idx);
            if scan.vars(dim).size == 0
                error('Non-existing dimension');
            end
            res = scan.vars(dim).params;
        end
        function res=get_scan(self, idx)
            if idx == 0
                error('Out of bound scan index.');
            end
            res = ScanInfo(self, idx);
        end
        function [val, path]=guess_scanaxis(self, idx, dim, fieldidx)
            if ~exist('fieldidx', 'var')
                fieldidx = 1;
            end
            if idx == 0
                error('Out of bound scan index.');
            end
            scan = getfullscan(self, idx);
            if scan.vars(dim).size == 0
                error('Non-existing dimension');
            end
            function check_path(v, p)
                fieldidx = fieldidx - 1;
                if fieldidx ~= 0
                    return;
                end
                val = v;
                path = p;
            end
            var = scan.vars(dim);
            ScanGroup.foreach_nonstruct(@check_path, var.params)
            if fieldidx > 0
                error('Cannot find scan field');
            end
        end

        function varargout = subsref(self, S)
            % This handles the `grp([n]) ...` syntax.
            % We support chained operation so this needs to forward
            % the trailing index to the next handler by calling `subsref` directly.
            nS = length(S);
            if nS >= 1 && strcmp(S(1).type, '()')
                if isempty(S(1).subs)
                    % grp(): Fallback
                    idx = 0;
                elseif length(S(1).subs) == 1
                    % grp(n): Real scan
                    idx = S(1).subs{1};
                    if ~(idx > 0)
                        % Don't allow implicitly addressing the fallback with `0`
                        % Also use the negative check to handle wierd thing like NaN...
                        error('Scan index must be positive');
                    end
                else
                    error('Too many scan index');
                end
                scan = ScanParam(self, idx);
                if nS > 1
                    [varargout{1:nargout}] = subsref(scan, S(2:end));
                else
                    % At most one return value in this branch.
                    % Throw and error if we got more than that.
                    nargoutchk(0, 1);
                    varargout{1} = scan;
                end
                return;
            end
            [varargout{1:nargout}] = builtin('subsref', self, S);
        end
        function A = subsasgn(self, S, B)
            % This handles the `grp([n]) ... = ...` syntax,
            % including both direct assignment `grp([n]) = ...`
            % and assignment to the `ScanParam` object in a chained operation,
            % i.e. `grp([n]). ... = ...`.
            % Therefore, if there's more than one index,
            % we need to pass those on to `ScanParam`.
            nS = length(S);
            if nS >= 1 && strcmp(S(1).type, '()')
                if isempty(S(1).subs)
                    % grp(): Fallback
                    idx = 0;
                elseif length(S(1).subs) == 1
                    % grp(n): Real scan
                    idx = S(1).subs{1};
                    if ~(idx > 0)
                        % Don't allow implicitly address fallback with 0.
                        error('Scan index must be positive');
                    end
                else
                    error('Too many scan index');
                end
                A = self;
                if nS > 1
                    % Assignment to the `ScanParam`, pass that on.
                    scan = ScanParam(self, idx);
                    scan = subsasgn(scan, S(2:end), B);
                    return;
                end
                if isa(B, 'ScanParam')
                    Bgroup = getgroup(B);
                    Bidx = getidx(B);
                    if Bgroup ~= self
                        error('Cannot assign scan from a different group.');
                    end
                    if Bidx == idx
                        % no-op
                        return;
                    end
                    if Bidx == 0
                        rscan = self.base;
                        rbase = 0; % base index
                    else
                        rscan = self.scans(Bidx);
                        rbase = self.getbaseidx(Bidx); % base index
                    end
                    if idx == 0
                        self.base.params = rscan.params;
                        self.base.vars = rscan.vars;
                        set_dirty_all(self);
                    else
                        % Call the setter function to check for loop.
                        % This also makes sure the scans and scanscache are initialized.
                        setbase(self, idx, rbase);
                        self.scans(idx).params = rscan.params;
                        self.scans(idx).vars = rscan.vars;
                        self.scanscache(idx).dirty = true;
                    end
                    return;
                elseif ScanGroup.hasarray(B)
                    error('Mixing fixed and variable parameters not allowed.');
                end
                if idx == 0
                    self.base.params = B;
                    self.base.vars = struct('size', {}, 'params', {});
                    set_dirty_all(self);
                else
                    self.scans(length(self.scans) + 1:idx) = ScanGroup.DEF_SCAN;
                    self.scans(idx).params = B;
                    self.scans(idx).vars = struct('size', {}, 'params', {});
                    self.scans(idx).baseidx = 0;
                    self.scanscache(length(self.scanscache) + 1:idx) = ScanGroup.DEF_SCANCACHE;
                    self.scanscache(idx).dirty = true;
                end
                return;
            elseif (nS > 2 && strcmp(S(1).type, '.') && strcmp(S(1).subs, 'runp') && ...
                    strcmp(S(2).type, '()') && isempty(S(2).subs))
                % Hack to make `grp.runp() ... = ...` working
                A = builtin('subsasgn', runp(self), S(3:end), B);
                A = self;
                return;
            end
            A = builtin('subsasgn', self, S, B);
        end
    end
    methods(Access=?ScanInfo)
        function [res, dim]=info_subsref(self, idx, info, S)
            nS = length(S);
            for i = 1:nS
                if strcmp(S(i).type, '.')
                    continue;
                end
                % Too lazy for anything fancier than this....
                if strcmp(S(i).type, '()')
                    if i ~= nS
                        error('Invalid parameter access syntax');
                    end
                    if length(S(i).subs) ~= 1
                        error('Wrong number of default value');
                    end
                    [res, dim] = try_getfield(self, idx, S(1:i - 1), 1);
                    if dim < 0
                        dim = 0;
                        res = S(i).subs{1};
                    end
                    return;
                end
            end
            [res, dim] = try_getfield(self, idx, S, 1);
            if dim < 0
                res = SubProps(info, S);
            end
        end
        function res=info_fieldnames(self, idx, info, S)
            res = {};
            function add_fieldnames(params)
                % Only handles `.` reference
                for i=1:length(S)
                    if ~ScanGroup.isscalarstruct(params)
                        error('Parameter parent overwriten');
                    end
                    name = S(i).subs;
                    if ~isfield(params, name)
                        return;
                    end
                    params = params.(name);
                end
                if ~ScanGroup.isscalarstruct(params)
                    return;
                end
                fields = fieldnames(params);
                for i=1:length(fields)
                    name = fields{i};
                    if any(strcmp(res, name))
                        continue;
                    end
                    res{end + 1} = name;
                end
            end
            scan = getfullscan(self, idx);
            add_fieldnames(scan.params);
            for j=1:length(scan.vars)
                add_fieldnames(scan.vars(j).params);
            end
        end
    end
    methods(Access=?ScanParam)
        function base=getbaseidx(self, idx)
            scan = self.scans(idx);
            base = scan.baseidx;
            if isempty(base)
                base = 0;
            end
        end
        function res=set_dirty_all(self)
            for i = 1:length(self.scanscache)
                self.scanscache(i).dirty = true;
            end
        end
        function res=check_dirty(self, idx)
            while idx ~= 0
                if self.scanscache(idx).dirty
                    res = true;
                    return;
                end
                idx = self.scans(idx).baseidx;
            end
            res = false;
        end
        function scan=getfullscan(self, idx)
            if idx == 0
                scan = self.base;
                return;
            elseif ~check_dirty(self, idx)
                scan = self.scanscache(idx);
                scan = rmfield(scan, 'dirty');
                return;
            end
            scan = self.scans(idx);
            base = getfullscan(self, getbaseidx(self, idx));
            % Merge the fixed parameters
            function param_cb(v, path)
                if ScanGroup.find_scan_dim(scan, path) >= 0
                    return;
                end
                scan.params = subsasgn(scan.params, path, v);
            end
            ScanGroup.foreach_nonstruct(@param_cb, base.params);
            % Merge the variable parameters
            function var_cb(v, path)
                if ScanGroup.find_scan_dim(scan, path) >= 0
                    return;
                end
                scan.vars(length(scan.vars) + 1:scanid) = ScanGroup.DEF_VARS;
                scan.vars(scanid).params = subsasgn(scan.vars(scanid).params, path, v);
            end
            for scanid = 1:length(base.vars)
                ScanGroup.foreach_nonstruct(@var_cb, base.vars(scanid).params);
            end
            function count_vars(v, path)
                nv = numel(v);
                if nv == 1
                    error('Too few elements to scan.');
                elseif scansize == 0;
                    scansize = nv;
                elseif scansize ~= nv
                    error('Inconsistent scan size.');
                end
            end
            for scanid = 1:length(scan.vars)
                scansize = 0;
                ScanGroup.foreach_nonstruct(@count_vars, scan.vars(scanid).params);
                scan.vars(scanid).size = scansize;
            end
            self.scanscache(idx).params = scan.params;
            self.scanscache(idx).vars = scan.vars;
            self.scanscache(idx).dirty = false;
        end
        % Check if there's any conflict if we want to scan `S` in the `dim` dimension
        % for the scan `idx`. `dim == 0` represent fixed parameter.
        function check_noconflict(self, idx, S, dim)
            if idx == 0
                scan = self.base;
            elseif length(self.scans) < idx
                % Initialize the scans, no need to check for conflict yet since it's empty.
                self.scans(length(self.scans) + 1:idx) = ScanGroup.DEF_SCAN;
                self.scanscache(length(self.scanscache) + 1:idx) = ScanGroup.DEF_SCANCACHE;
                return;
            else
                scan = self.scans(idx);
            end
            if dim ~= 0
                if ScanGroup.check_field(scan.params, S)
                    error('Cannot scan a fixed parameter.');
                end
            end
            for i = 1:length(scan.vars)
                if dim == i
                    continue;
                end
                if ScanGroup.check_field(scan.vars(i).params, S)
                    if dim == 0
                        error('Cannot fix a scanned parameter.');
                    else
                        error('Cannot scan a parameter in multiple dimensions.');
                    end
                end
            end
        end
        % Try to get the field for a specific scan
        % If `allow_scan` is `true`, also search for scan (variable) parameters.
        % If no (leaf) field is found, return `[], -1`.
        % Otherwise, return the value (possibly array) in `val` and the scan dimension
        % (0 for fixed parameters) in `dim`.
        % Throw an error if the field's parent is set to non-scalar struct
        function [val, dim] = try_getfield(self, idx, S, allow_scan)
            if idx == 0
                scan = self.base;
            elseif length(self.scans) < idx
                val = [];
                dim = -1;
                return;
            else
                scan = getfullscan(self, idx);
            end
            [val, res] = ScanGroup.get_leaffield(scan.params, S);
            if res
                dim = 0;
                return;
            end
            if ~allow_scan
                dim = -1;
                return;
            end
            for dim = 1:length(scan.vars)
                [val, res] = ScanGroup.get_leaffield(scan.vars(dim).params, S);
                if res
                    return;
                end
            end
            dim = -1;
        end
        function addparam(self, idx, S, val)
            check_noconflict(self, idx, S, 0);
            if idx == 0
                self.base.params = subsasgn(self.base.params, S, val);
                set_dirty_all(self);
            else
                self.scans(idx).params = subsasgn(self.scans(idx).params, S, val);
                self.scanscache(idx).dirty = true;
            end
        end
        function addscan(self, idx, S, dim, vals)
            if ~ScanGroup.isarray(vals)
                addparam(self, idx, S, vals);
                return;
            end
            if ~(dim > 0 && isscalar(dim) && floor(dim) == dim)
                error('Scan dimension must be positive integer.');
            end
            check_noconflict(self, idx, S, dim);
            nvals = numel(vals);
            if idx == 0
                self.base.vars(length(self.base.vars) + 1:dim) = ScanGroup.DEF_VARS;
                sz = self.base.vars(dim).size;
                if sz == 0
                    self.base.vars(dim).size = nvals;
                elseif sz ~= nvals
                    error('Scan parameter size does not match');
                end
                self.base.vars(dim).params = subsasgn(self.base.vars(dim).params, S, vals);
                set_dirty_all(self);
            else
                self.scans(idx).vars(length(self.scans(idx).vars) + 1:dim) = ScanGroup.DEF_VARS;
                sz = self.scans(idx).vars(dim).size;
                if sz == 0
                    self.scans(idx).vars(dim).size = nvals;
                elseif sz ~= nvals
                    error('Scan parameter size does not match');
                end
                self.scans(idx).vars(dim).params = subsasgn(self.scans(idx).vars(dim).params, ...
                                                            S, vals);
                self.scanscache(idx).dirty = true;
            end
        end
        function validate(self)
            % TODO
            % base is scalar integer and inbound.
            % base is loop free
            % parameter conflict between scans
            % scan size ~= 1
            % consistent scan size
        end
    end
    methods(Static, Access=?ScanParam)
        %% Check if the object is an array for scan parameter.
        % Rules are:
        % 1. All scalar are not array
        % 2. Cell arrays are always array
        % 3. char array alone the horizontal direction does not count as array
        % 4. All other arrays are array
        function res = isarray(obj)
            if iscell(obj)
                res = true;
            elseif ischar(obj)
                res = length(obj) ~= size(obj, 2);
            else
                res = ~isscalar(obj);
            end
        end
        %% Recursively check if any of the struct fields are array.
        function res = hasarray(obj)
            res = ScanGroup.isarray(obj);
            if res
                return;
            elseif ~isstruct(obj)
                return;
            end
            fns = fieldnames(obj);
            for i=1:length(fns)
                if ScanGroup.isarray(obj.(fns{i}))
                    res = true;
                    return;
                end
            end
        end
        function res=isscalarstruct(obj)
            if ~isstruct(obj)
                res = false;
            elseif ~isscalar(obj)
                res = false;
            else
                res = true;
            end
        end
        % Check if the struct field reference path is overwritten in `obj`.
        % Overwrite happens if the field itself exists or a parent of the field
        % is overwritten to something that's not scalar struct.
        function res=check_field(obj, path)
            % Only handles `.` reference
            for i = 1:length(path)
                if ~ScanGroup.isscalarstruct(obj)
                    % Non scalar struct in the path counts as existing override.
                    % shouldn't really happen though...
                    res = true;
                    return;
                end
                name = path(i).subs;
                if ~isfield(obj, name)
                    res = false;
                    return;
                end
                obj = obj.(name);
            end
            res = true;
        end
        % Check if the field is a leaf field within the parameter tree.
        % Throw an error if the field's parent is set to non-scalar struct.
        function [val, res]=get_leaffield(obj, path)
            % Only handles `.` reference
            val = [];
            for i = 1:length(path)
                if ~ScanGroup.isscalarstruct(obj)
                    error('Parameter parent overwriten');
                end
                name = path(i).subs;
                if ~isfield(obj, name)
                    res = false;
                    return;
                end
                obj = obj.(name);
            end
            res = ~ScanGroup.isscalarstruct(obj);
            if res
                val = obj;
            end
        end
        % Find the scan dimention for the field referenced in `path`.
        % Return `0` for fixed parameter, `-1` for not found in any scan.
        function res=find_scan_dim(scan, path)
            if ScanGroup.check_field(scan.params, path)
                res = 0;
                return;
            end
            for i = 1:length(scan.vars)
                if ScanGroup.check_field(scan.vars(i).params, path)
                    res = i;
                    return;
                end
            end
            res = -1;
        end
        % Helper to iterate through nested structure.
        % It's not very efficient in MATLAB but
        % I really don't want to write this multiple times.
        function foreach_nonstruct(cb, obj)
            if ~ScanGroup.isscalarstruct(obj)
                error('Object is not a struct.');
            end
            topfields = fieldnames(obj);
            if isempty(topfields)
                % no fields
                return;
            end
            cached_fields = {topfields};
            path = struct('type', '.', 'subs', topfields{1});
            state = [1];
            while true
                v = subsref(obj, path);
                if ScanGroup.isscalarstruct(v)
                    fields = fieldnames(v);
                    if ~isempty(fields)
                        cached_fields{end + 1} = fields;
                        state(end + 1) = 1;
                        path(end + 1) = struct('type', '.', 'subs', fields{1});
                        continue;
                    end
                else
                    cb(v, path);
                end
                state(end) = state(end) + 1;
                fields = cached_fields{end};
                while state(end) > length(fields)
                    cached_fields(end) = [];
                    state(end) = [];
                    path(end) = [];
                    if isempty(path)
                        return;
                    end
                    state(end) = state(end) + 1;
                    fields = cached_fields{end};
                end
                path(end).subs = fields{state(end)};
            end
        end
        function self=load_v1(obj)
            self = ScanGroup();
            self.scans = obj.scans;
            self.base = obj.base;
            self.runparam(obj.runparam);
            self.scanscache(1:length(self.scans)) = ScanGroup.DEF_SCANCACHE;
        end
        function self=load_v0(obj)
            % Loading the old style scan seq
            self = ScanGroup();
            self.runparam(obj.scan);
            p = obj.p;
            fields = fieldnames(p);
            for i=1:length(p)
                scan = ScanGroup.DEF_SCAN;
                vars = ScanGroup.DEF_VARS;
                for j=1:length(fields)
                    name = fields{j};
                    val = p(i).(name);
                    if isempty(val)
                        val = p(1).(name);
                    end
                    sz = numel(val);
                    if sz <= 1
                        scan.params.(name) = val;
                        continue;
                    end
                    if vars.size == 0
                        vars.size = sz;
                    elseif vars.size ~= sz
                        error('Scan size mismatch');
                    end
                    vars.params.(name) = val;
                end
                if vars.size ~= 0
                    scan.vars = vars;
                end
                self.scans(i) = scan;
            end
            self.scanscache(1:length(self.scans)) = ScanGroup.DEF_SCANCACHE;
        end
    end
    methods(Static)
        function self=load(obj)
            if isa(obj, 'ScanSeq')
                scanp = obj.scanp();
                self = ScanGroup.load_v0(struct('p', obj.p, 'scan', scanp()));
            elseif ~isfield(obj, 'version')
                error('Version missing.');
            elseif obj.version == 1
                self = ScanGroup.load_v1(obj);
            elseif obj.version == 0
                self = ScanGroup.load_v0(obj);
            else
                error('Wrong object version: %d', obj.version);
            end
            validate(self);
        end
    end
    % Put this function at the end so that it doesn't mess up the indent of the whole file...
    methods
        function res=end(self, a, b)
        assert(a == 1 && b == 1);
        res = length(self.scans);
    end
end
end
