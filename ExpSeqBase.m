% Copyright (c) 2014-2021, Yichao Yu <yyc1992@gmail.com>
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

classdef ExpSeqBase < TimeSeq
    %% `ExpSeqBase`s are generally non-leaf nodes in the experiment sequence (tree/DAG).
    % See `TimeSeq` for the general structure of the sequence.

    % Other than the fields to keep track of the tree structure,
    % this also keeps track of a current time which makes it easier to construct a
    % step-by-step sequence in most cases.
    %
    % The most basic timing API: `addStep` automatically forward the current time
    % so that the next step/subsequence will be added after the previous one finishes.
    % Other API's allow adding steps or subsequences with more flexible timing.
    % (`addBackground`, `addFloating`, `addAt`).
    %
    % All of the API's ensure that the current time can only be forwarded.
    % This makes it easy to infer the timing of the sequence when reading the code.

    properties(SetAccess=protected, GetAccess=?TimeSeq)
        % This is length of the current (sub)sequence (not including background sequences)
        % and is also where sub sequences and time steps are added to by default.
        curSeqTime;
    end
    properties(Hidden)
        % Subnodes in the tree. Only non-empty ones matters.
        % The preallocation here makes constructing a normal sequence slightly faster.
        subSeqs = {[], [], [], [], [], []};
        nSubSeqs = 0;
        % This is the flag that records if all the parents (recursively)
        % have the `totallen_after_parent` flag set.
        % In general, whenever we set the `totallen_after_parent` to `true`,
        % we have to set it for all the parents recursively as well.
        % However, once we did that we don't have to do it again if nothing else changed.
        latest_seq = true;
    end
    properties(SetAccess=protected, Hidden)
        % This is the nested struct (`DynProp`) that contains global constant
        % and scan parameters. See `ScanGroup` for more detail.
        C; % ::DynProp
        % Global context.
        % For a sequence as part of a scan (or runSeq),
        % this is shared between all the sequences in the scan
        % and can be used to share information between sequences.
        G; % ::DynProp
    end

    methods
        %% API's to add steps and subsequences.

        % These functions creates sub node in the sequence DAG
        % which can be either a step (`TimeStep`) or a subsequence (`SubSeq`).
        % (For simplicity, we may call both of these steps below.)
        %
        % The steps are created relative to a certain reference point,
        % which can be,
        % 1. Unknown (to be fixed later): `addFloating`.
        % 2. Known now. The known time could be,
        %     A. Current time of this (sub)sequence,
        %        in which case one decide whether the current time should be updated.
        %         a. Yes: `addStep`
        %         b. No: `addBackground`
        %     B. A specific `TimePoint`: `addAt`.
        %
        % All the functions use the same syntax to specify the type of
        % the step to be added (`TimeStep` or `SubSeq`),
        % the parameter to construct the step (length for `TimeStep` or
        % callback with arbitrary arguments for `SubSeq`),
        % and the offset relative to the reference point for each function.
        % (The offset cannot be specified for `addFloating`).
        % This is handled by `addStepReal` and the allowed arguments conbinations are,
        %
        % 1. To construct a subsequence (`SubSeq`), a callback is always required.
        %    (The callback can be a function handle, a class, or any callable,
        %    i.e. indexable non-numerical and non-logical object).
        %    Therefore, to construct a subsequence the arguments are,
        %    `([offset=0, ]callback, extra_arguments_for_callback...)`.
        %    The sub sequence will be constructed at the specified time point
        %    and passed to the `callback` (as first argument) followed by the extra
        %    arguments to populate the subsequence.
        % 2. To construct a `TimeStep`, one need to specify only the length.
        %    Since the offset is rarely used, the arguments to construct a `TimeStep` is,
        %    `(len[, offset=0])`. `len` in must be positive.
        %
        % In both cases, the step constructed will be returned.
        % Note that the offset is not allowed for `addStep`
        % to prevent `curSeqTime` from going backward.
        % Is is also forbidden for `addFloating` since it doesn't really make much sense.
        function step = addStep(self, varargin)
            %% The most basic timing API. Add a step (`TimeStep`) or
            % subsequence (`SubSeq`) and forward the current time based
            % on the length of the added step.
            % The length for this purpose is the length for `TimeStep` and
            % `curSeqTime` for `SubSeq`. Same as the definition for `TimePoint`.
            [step, end_time] = addStepReal(self, false, self.curSeqTime, varargin{:});
            self.curSeqTime = end_time;
            step.end_after_parent = false;
            if step.is_step
                step.totallen_after_parent = false;
            end
            self.end_after_parent = true;
        end

        function step = addBackground(self, varargin)
            %% Add a background step or subsequence
            % (same as `addStep` without forwarding current time).
            step = addStepReal(self, true, self.curSeqTime, varargin{:});
        end

        function step = addFloating(self, varargin)
            %% Add a floating step or subsequence
            % The time is not fixed and will be determined later.
            step = addStepReal(self, false, nan, varargin{:});
        end

        function step = addAt(self, tp, varargin)
            %% Add a step or subsequence at a specific time point.
            % The standard arguments for creating the step or subsequence comes after
            % the time point.
            % FIXME: Not sure what to do when adding something at a different time
            % in a disabled subsequence.
            step = addStepReal(self, true, getTimePointOffset(self, tp), varargin{:});
        end

        %% Wait API's
        % Allow waiting for time, background sequences, everything,
        % or specific subsequences or steps.

        function self = wait(self, t)
            %% Forward current time.
            if isnumeric(t) && t < 0
                error('Wait time cannot be negative.');
            end
            self.curSeqTime = create(self.curSeqTime, SeqTime.NonNeg, ...
                                     round(t * self.topLevel.time_scale));
            self.end_after_parent = true;
            while ~self.latest_seq
                self.totallen_after_parent = true;
                self.latest_seq = true;
                self = self.parent;
                if isempty(self)
                    break;
                end
            end
        end

        function self = waitAll(self)
            %% Wait for everything that have been currently added to finish.
            % This is the recursive version of `waitBackground`.
            self.curSeqTime = waitAllTime(self, true);
            self.end_after_parent = true;
        end

        function self = waitFor(self, steps, offset)
            % `offset` is in real unit and not scaled.
            %% Wait for all the steps or subsequences within `steps` with an offset.
            % It is allowed to wait for steps or subsequences that are not a child
            % of `self`. It is also allowed to wait for floating sequence provided
            % that all the floating part is shared (i.e. only the common parents are floating
            % and the offset between `self` and the step to be waited for is well defined).
            if ~exist('offset', 'var')
                offset = 0;
                hasoffset = false;
                nonnegoffset = true;
            elseif isnumeric(offset)
                hasoffset = offset ~= 0;
                nonnegoffset = offset >= 0;
            else
                hasoffset = true;
                nonnegoffset = false;
            end
            t = self.curSeqTime;
            tval = getVal(t);
            has_other_parent = false;
            for step = steps
                if iscell(step)
                    % Deal with MATLAB cell array indexing weirdness....
                    real_step = step{:};
                else
                    real_step = step;
                end
                if self == real_step
                    error('Cannot wait for the sequence itself.');
                end
                if checkParent(self, real_step)
                    error('Cannot wait for parent sequence.');
                end
                step_toffset = real_step.tOffset;
                if isnan(step_toffset)
                    error('Cannot get offset of floating sequence.');
                end
                if real_step.parent ~= self
                    step_toffset = combine(offsetDiff(self, real_step.parent), ...
                                           step_toffset);
                    has_other_parent = true;
                end
                assert(step_toffset.seq == self);
                if real_step.is_step
                    tstep = create(step_toffset, SeqTime.Pos, round(real_step.len));
                else
                    tstep = combine(step_toffset, real_step.curSeqTime);
                end
                if hasoffset
                    tstep = create(tstep, SeqTime.Unknown, ...
                                   round(offset * self.topLevel.time_scale));
                end
                if nonnegoffset && real_step.parent == self
                    real_step.end_after_parent = false;
                    if real_step.is_step
                        real_step.totallen_after_parent = false;
                    end
                end
                new_tval = max(tval, getVal(tstep));
                new_t = create(SeqTime.zero(self), SeqTime.NonNeg, new_tval);
                addOrder(self.root, SeqTime.NonNeg, tstep, new_t);
                addOrder(self.root, SeqTime.NonNeg, t, new_t);
                tval = new_tval;
                t = new_t;
            end
            self.curSeqTime = t;
            self.end_after_parent = true;
            if ~self.latest_seq && (has_other_parent || isa(offset, 'SeqVal') || offset > 0)
                while ~self.latest_seq
                    self.totallen_after_parent = true;
                    self.latest_seq = true;
                    self = self.parent;
                    if isempty(self)
                        break;
                    end
                end
            end
        end

        function self = waitBackground(self)
            %% Wait for background steps that are added directly to this sequence
            % to finish. See also `waitAll`.
            t = self.curSeqTime;
            tval = getVal(t);
            for i = 1:self.nSubSeqs
                sub_seq = self.subSeqs{i};
                step_toffset = sub_seq.tOffset;
                if ~sub_seq.end_after_parent
                    continue;
                end
                if isnan(step_toffset)
                    error('Cannot get offset of floating sequence.');
                end
                if sub_seq.is_step
                    tstep = create(step_toffset, SeqTime.Pos, round(sub_seq.len));
                else
                    tstep = combine(step_toffset, sub_seq.curSeqTime);
                end
                sub_seq.end_after_parent = false;
                new_tval = max(tval, getVal(tstep));
                new_t = create(SeqTime.zero(self), SeqTime.NonNeg, new_tval);
                addOrder(self.root, SeqTime.NonNeg, tstep, new_t);
                addOrder(self.root, SeqTime.NonNeg, t, new_t);
                tval = new_tval;
                t = new_t;
            end
            self.curSeqTime = t;
            self.end_after_parent = true;
        end

        %% Other helper functions.

        function step = add(self, name, pulse)
            %% Convenient shortcut for adding a single pulse in a step.
            if ~isnumeric(pulse) && ~islogical(pulse) && ~isa(pulse, 'SeqVal')
                error('Use addStep to add a ramp pulse.');
            end
            % The time (2 ticks) here is just a placeholder.
            % The exact length doesn't really matter except for total sequence length
            step = addStepReal(self, true, self.curSeqTime, ...
                               2 / self.topLevel.time_scale); % addBackground
            add(step, name, pulse);
            step.end_after_parent = false;
            step.totallen_after_parent = false;
        end

        function subseqs = alignEnd(self, varargin)
            % Make sure that the input sequences end at the same time and the longest
            % one of which started `offset` after the current time of this sequence.
            % (Does not modify current time).
            % Return the input sequences/steps as a cell array.
            if isempty(varargin)
                error('Requires at least one sequence to align');
            end
            if isa(varargin{end}, 'TimeSeq')
                subseqs = varargin;
                offset = 0;
                hasoffset = false;
            elseif length(varargin) == 1
                error('Requires at least one sequence to align');
            else
                subseqs = varargin{1:end - 1};
                offset = round(varargin{end} * self.topLevel.time_scale);
                hasoffset = ~isnumeric(offset) || offset ~= 0;
            end
            nsubseqs = length(subseqs);
            maxlen = [];
            lens = cell(1, nsubseqs);
            maxsign = SeqTime.NonNeg;
            signs = zeros(1, nsubseqs);
            times = cell(1, nsubseqs);
            for i = 1:nsubseqs
                subseq = subseqs{i};
                if ~isnan(subseq.tOffset)
                    error('alignEnd requires floating sequences as inputs.');
                end
                assert(subseq.parent == self);
                if subseq.is_step
                    len = round(subseq.len);
                    sign = SeqTime.Pos;
                    maxsign = SeqTime.Pos;
                else
                    time = subseq.curSeqTime;
                    times{i} = time;
                    len = getVal(time);
                    sign = SeqTime.NonNeg;
                end
                if isempty(maxlen)
                    maxlen = len;
                else
                    maxlen = max(maxlen, len);
                end
                lens{i} = len;
                signs(i) = sign;
            end
            curtime = self.curSeqTime;
            if hasoffset
                curtime = create(curtime, SeqTime.Unknown, offset); % curtime + offset
            end
            endtime = create(curtime, maxsign, maxlen); % curtime + maxlen
            for i = 1:nsubseqs
                subseq = subseqs{i};
                len = lens{i};
                starttime = create(endtime, SeqTime.Unknown, -len); % endtime - len
                subseq.tOffset = starttime;
                if nsubseqs > 1
                    addOrder(self.root, SeqTime.NonNeg, curtime, starttime);
                    time = times{i};
                    if isempty(time)
                        % starttime + len
                        if ~isnumeric(len)
                            addEqual(self.root, endtime, create(starttime, signs(i), len));
                        end
                    else
                        addEqual(self.root, endtime, time);
                    end
                end
            end
        end

        function res = curTime(self)
            res = getVal(self.curSeqTime) / self.topLevel.time_scale;
        end

        function res = totalTime(self)
            res = totalTimeRaw(self) / self.topLevel.time_scale;
        end

        function tdiff = getTimePointOffset(self, time)
            % Compute the offset of a `TimePoint` relative to current sequence.
            % Returns a `SeqTime` that's suitable in the current sequence.
            if ~isa(time, 'TimePoint')
                error('`TimePoint` expected.');
            end
            other = time.seq;
            tdiff = offsetDiff(self, other);
            tdiff = create(tdiff, SeqTime.Unknown, ...
                           round(time.offset * self.topLevel.time_scale));
            if ~isnumeric(time.anchor) || time.anchor ~= 0
                if other.is_step
                    tdiff = create(tdiff, SeqTime.Unknown, round(other.len * time.anchor));
                elseif isnumeric(time.anchor) && time.anchor == 1
                    tdiff = combine(tdiff, other.curSeqTime);
                else
                    tdiff = create(tdiff, SeqTime.Unknown, ...
                                   round(getVal(other.curSeqTime) * time.anchor));
                end
            end
        end
    end

    methods(Access=private)
        function res = checkParent(self, other)
            if isempty(other.parent)
                res = true;
                return;
            end
            self = self.parent;
            while ~isempty(self)
                if self == other
                    res = true;
                    return;
                end
                self = self.parent;
            end
            res = false;
        end

        function res = offsetDiff(self, step)
            %% Compute the offset different starting from the lowest common ancestor
            % This make it possible to support floating sequence in the common ancestor.
            % Return the term differences so that the caller
            % can take advantage of the sturcture of the offset and the signs of the terms.
            res = SeqTime.zero(self);
            self_path = globalPath(self);
            other_path = globalPath(step);
            nself = length(self_path);
            nother = length(other_path);
            has_neg = false;
            for i = 1:max(nself, nother)
                if i <= nself
                    self_ele = self_path{i};
                    if i <= nother
                        other_ele = other_path{i};
                        if self_ele == other_ele
                            continue;
                        end
                        other_offset = other_ele.tOffset;
                        if isnan(other_offset)
                            error('Cannot compute offset different for floating sequence');
                        end
                        res = combine(res, other_offset);
                        self_offset = self_ele.tOffset;
                        if isnan(self_offset)
                            error('Cannot compute offset different for floating sequence');
                        end
                        if ~iszero(self_offset)
                            has_neg = true;
                            res = create(res, SeqTime.Unknown, -getVal(self_offset));
                        end
                    else
                        self_offset = self_ele.tOffset;
                        if isnan(self_offset)
                            error('Cannot compute offset different for floating sequence');
                        end
                        if ~iszero(self_offset)
                            has_neg = true;
                            res = create(res, SeqTime.Unknown, -getVal(self_offset));
                        end
                    end
                else
                    other_ele = other_path{i};
                    other_offset = other_ele.tOffset;
                    if isnan(other_offset)
                        error('Cannot compute offset different for floating sequence');
                    end
                    res = combine(res, other_offset);
                end
            end
            if has_neg
                if isempty(step.tOffset)
                    addEqual(self.root, step.zero_time, res);
                else
                    addEqual(self.root, step.tOffset, res);
                end
            end
        end

        function [res, curtime_only] = totalTimeRaw(self)
            res = getVal(self.curSeqTime);
            curtime_only = true;
            for i = 1:self.nSubSeqs
                sub_seq = self.subSeqs{i};
                if ~sub_seq.totallen_after_parent
                    continue;
                end
                if sub_seq.is_step
                    sub_end = sub_seq.len;
                else
                    [sub_end, sub_curtime_only] = totalTimeRaw(sub_seq);
                    if sub_curtime_only && ~sub_seq.end_after_parent
                        continue;
                    end
                end
                if isnan(sub_seq.tOffset)
                    error('Cannot get total time with floating sub sequence.');
                end
                sub_end = sub_end + getVal(sub_seq.tOffset);
                curtime_only = false;
                res = max(res, sub_end);
            end
        end
    end

    methods(Access=protected)
        function t = waitAllTime(self, setflag)
            %% Returns a time that waits for everything to finish.
            t = self.curSeqTime;
            tval = getVal(t);
            for i = 1:self.nSubSeqs
                sub_seq = self.subSeqs{i};
                if ~sub_seq.totallen_after_parent
                    continue;
                end
                step_toffset = sub_seq.tOffset;
                if isnan(step_toffset)
                    error('Cannot get offset of floating sequence.');
                end
                if sub_seq.is_step
                    tstep = create(step_toffset, SeqTime.Pos, round(sub_seq.len));
                else
                    subt = waitAllTime(sub_seq, false);
                    sub_seq.latest_seq = false;
                    % Handle background subsequence that has already been waited for.
                    % If we know the child's `curSeqTime` doesn't end after us
                    % and the total time is the same as its `curSeqTime`
                    % we can simply ignore it.
                    if ~sub_seq.end_after_parent && subt == sub_seq.curSeqTime
                        if setflag
                            sub_seq.totallen_after_parent = false;
                        end
                        continue;
                    end
                    tstep = combine(step_toffset, subt);
                end
                if setflag
                    sub_seq.totallen_after_parent = false;
                    sub_seq.end_after_parent = false;
                end
                new_tval = max(tval, getVal(tstep));
                new_t = create(SeqTime.zero(self), SeqTime.NonNeg, new_tval);
                addOrder(self.root, SeqTime.NonNeg, tstep, new_t);
                addOrder(self.root, SeqTime.NonNeg, t, new_t);
                tval = new_tval;
                t = new_t;
            end
        end
    end

    methods(Access=private)
        function [step, end_time] = addStepReal(self, allow_offset, curtime, first_arg, varargin)
            %% This is the function that handles the standard arguments
            % for creating time step or subsequence. (See comments above).
            % `curtime` is the reference time point (`nan` for `addFloating`)
            % The step constructed and the end time are returned.
            if ~isnumeric(first_arg) && ~isa(first_arg, 'SeqVal')
                % If first arg is not a value, assume to be a callback for subsequence.
                [step, end_time] = addCustomStep(self, curtime, first_arg, varargin{:});
            elseif isempty(varargin)
                % If we only have one numerical argument it must be a simple time step.
                start_time = curtime;
                len = first_arg * self.topLevel.time_scale;
                if isnan(curtime)
                    curtime = nan;
                else
                    curtime = create(curtime, SeqTime.Pos, round(len));
                end
                step = TimeStep(self, start_time, len);
                end_time = curtime;
            elseif isnumeric(varargin{1}) || isa(varargin{1}, 'SeqVal')
                % If we only have two value argument it must be a simple time step
                % with custom offset.
                if length(varargin) > 1
                    % Only two arguments allowed in this case.
                    error('Too many arguments to create a time step.');
                elseif ~allow_offset
                    if isnan(curtime)
                        error('Floating time step with time offset not allowed.');
                    else
                        error('addStep with time offset not allowed.');
                    end
                end
                offset = varargin{1};
                assert(~isnan(curtime));
                curtime = create(curtime, SeqTime.Unknown, ...
                                 round(offset * self.topLevel.time_scale));
                len = first_arg * self.topLevel.time_scale;
                step = TimeStep(self, curtime, len);
                end_time = create(curtime, SeqTime.Pos, round(len));
            else
                % Number followed by a callback: subsequence with offset.
                if ~allow_offset
                    if isnan(curtime)
                        error('Floating time step with time offset not allowed.');
                    else
                        error('addStep with time offset not allowed.');
                    end
                end
                if ~self.latest_seq
                    self.totallen_after_parent = true;
                    self.latest_seq = true;
                    parent = self.parent
                    while ~parent.latest_seq
                        parent.totallen_after_parent = true;
                        parent.latest_seq = true;
                        parent = parent.parent;
                        if isempty(parent)
                            break;
                        end
                    end
                end
                assert(~isnan(curtime));
                curtime = create(curtime, SeqTime.Unknown, ...
                                 round(first_arg * self.topLevel.time_scale));
                [step, end_time] = addCustomStep(self, curtime, varargin{:});
            end
        end

        function [step, end_time] = addCustomStep(self, start_time, cb, varargin)
            %% Add a subsequence by creating a child `SubSeq` node and populating
            % it using the callback passed in.
            step = SubSeq(self, start_time);
            % Create the step
            cb(step, varargin{:});
            step.latest_seq = false;
            if isnan(start_time)
                end_time = nan;
            else
                assert(start_time.seq == self);
                end_time = combine(start_time, step.curSeqTime);
            end
        end
    end
end
