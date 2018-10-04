% Copyright (c) 2014-2018, Yichao Yu <yyc1992@gmail.com>
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

    properties
        % This is length of the current (sub)sequence (not including background sequences)
        % and is also where sub sequences and time steps are added to by default.
        curTime = 0;
    end
    properties(Hidden)
        % Subnodes in the tree. Only non-empty ones matters.
        % The preallocation here makes constructing a normal sequence slightly faster.
        subSeqs = {[], [], [], [], [], []};
        nSubSeqs = 0;
    end
    properties(SetAccess = private, Hidden)
        % This is the nested struct (`DynProp`) that contains global constant
        % and scan parameters. See `ScanGroup` for more detail.
        C; % ::DynProp
    end

    methods
        function self = ExpSeqBase(parent_or_C, toffset)
            if exist('toffset', 'var')
                % As sub sequence: set offset and cache some shared properties
                % from its parent for fast lookup.
                self.parent = parent_or_C;
                self.tOffset = toffset;
                self.config = parent_or_C.config;
                self.topLevel = parent_or_C.topLevel;
                self.C = parent_or_C.C;
                % Add to parent
                ns = parent_or_C.nSubSeqs + 1;
                parent_or_C.nSubSeqs = ns;
                if ns > length(parent_or_C.subSeqs)
                    parent_or_C.subSeqs{round(ns * 1.3) + 8} = [];
                end
                parent_or_C.subSeqs{ns} = self;
                return;
            end
            % As top-level `ExpSeq`.
            self.config = SeqConfig.get(1);
            self.topLevel = self;
            C = struct();
            consts = self.config.consts;
            fields = fieldnames(consts);
            for i = 1:length(fields)
                fn = fields{i};
                C.(fn) = consts.(fn);
            end
            if exist('parent_or_C', 'var')
                % Allow parameters to overwrite consts in config
                fields = fieldnames(parent_or_C);
                for i = 1:length(fields)
                    fn = fields{i};
                    C.(fn) = parent_or_C.(fn);
                end
            end
            self.C = DynProps(C);
        end

        %% API's to add steps and subsequences.

        % These functions creates sub node in the sequence DAG
        % which can be either a step (`TimeStep`) or a subsequence (`ExpSeqBase`).
        % (For simplicity, we may call both of these steps below.)
        %
        % The steps are created relative to a certain reference point,
        % which can be,
        % 1. Unknown (to be fixed later): `addFloating`.
        % 2. Known now. The known time could be,
        %     A. Current time of this (sub)sequence,
        %        in which case one decide whether the current time should be updated.
        %         a. Yes: `addStep`
        %
        %             Note that the restriction that `curTime` cannot be decreased applies
        %             so the end of the step added this way must not be before the
        %             previous `curTime`. An error will be thrown if the time offset
        %             specified is too negative and cause this to happen.
        %             (The state of the sequence is unspecified after the error is thrown.)
        %
        %         b. No: `addBackground`
        %     B. A specific `TimePoint`: `addAt`.
        %
        % All the functions use the same syntax to specify the type of
        % the step to be added (`TimeStep` or `ExpSeqBase`),
        % the parameter to construct the step (length for `TimeStep` or
        % callback with arbitrary arguments for `ExpSeqBase`),
        % and the offset relative to the reference point for each function.
        % (The offset cannot be specified for `addFloating`).
        % This is handled by `addStepReal` and the allowed arguments conbinations are,
        %
        % 1. To construct a subsequence (`ExpSeqBase`), a callback is always required.
        %    (The callback can be a function handle, a class, or any callable,
        %    i.e. indexable non-numerical and non-logical object).
        %    Therefore, to construct a subsequence the arguments are,
        %    `([offset=0, ]callback, extra_arguments_for_callback...)`.
        %    The sub sequence will be constructed at the specified time point
        %    and passed to the `callback` (as first argument) followed by the extra
        %    arguments to populate the subsequence.
        % 2. To construct a `TimeStep`, one need to specify only the length.
        %    Since the offset is rarely used, the arguments to construct a `TimeStep` is,
        %    `(len[, offset=0])`. Since `len` in general must be positive, a special case
        %    is when a single negative number is given. The `len` will then be interpreted
        %    as the offset as well as the negative of the length
        %    (e.g. `(-5)` represent a step of length `5` and offset `-5`).
        %
        % In both cases, the step constructed will be returned.
        function step = addStep(self, first_arg, varargin)
            %% The most basic timing API. Add a step (`TimeStep`) or
            % subsequence (`ExpSeqBase`) and forward the current time based
            % on the length of the added step.
            % The length for this purpose is the length for `TimeStep` and
            % `curTime` for `ExpSeqBase`. Same as the definition for `TimePoint`.
            [step, end_time] = addStepReal(self, self.curTime, first_arg, varargin{:});
            if end_time < self.curTime
                error('Going back in time not allowed.');
            end
            self.curTime = end_time;
        end

        function step = addBackground(self, first_arg, varargin)
            %% Add a background step or subsequence
            % (same as `addStep` without forwarding current time).
            step = addStepReal(self, self.curTime, first_arg, varargin{:});
        end

        function step = addFloating(self, first_arg, varargin)
            %% Add a floating step or subsequence
            % The time is not fixed and will be determined later.
            step = addStepReal(self, nan, first_arg, varargin{:});
        end

        function res = addAt(self, tp, first_arg, varargin)
            %% Add a step or subsequence at a specific time point.
            % The standard arguments for creating the step or subsequence comes after
            % the time point.
            step = addStepReal(self, getTimePointOffset(self, tp), first_arg, varargin{:});
        end

        %% Wait API's
        % Allow waiting for time, background sequences, everything,
        % or specific subsequences or steps.

        function self = wait(self, t)
            %% Forward current time.
            self.curTime = self.curTime + t;
        end

        function self = waitAll(self)
            %% Wait for everything that have been currently added to finish.
            % This is the recursive version of `waitBackground`.
            self.curTime = totalTime(self);
        end

        function self = waitFor(self, steps, offset)
            %% Wait for all the steps or subsequences within `steps` with an offset.
            % It is allowed to wait for steps or subsequences that are not a child
            % of `self`. It is also allowed to wait for floating sequence provided
            % that all the floating part is shared (i.e. only the common parents are floating
            % and the offset between `self` and the step to be waited for is well defined).
            if ~exist('offset', 'var')
                offset = 0;
            end
            t = self.curTime;
            for step = steps
                if iscell(step)
                    % Deal with MATLAB cell array indexing weirdness....
                    real_step = step{:};
                else
                    real_step = step;
                end
                step_toffset = real_step.tOffset;
                if isnan(step_toffset)
                    error('Cannot get offset of floating sequence.');
                elseif isa(real_step, 'TimeStep')
                    tstep = step_toffset + real_step.len + offset;
                else
                    tstep = step_toffset + real_step.curTime + offset;
                end
                if real_step.parent ~= self
                    tstep = tstep + offsetDiff(self, real_step.parent);
                end
                if tstep > t
                    t = tstep;
                end
            end
            self.curTime = t;
        end

        function self = waitBackground(self)
            %% Wait for background steps that are added directly to this sequence
            % to finish. See also `waitAll`.
            function checkBackgroundTime(sub_seq)
                if ~isa(sub_seq, 'ExpSeqBase')
                    len = sub_seq.len;
                else
                    len = sub_seq.curTime;
                end
                sub_cur = sub_seq.tOffset + len;
                if isnan(sub_cur)
                    error('Cannot wait for background with floating sub sequences.');
                end
                if sub_cur > self.curTime
                    self.curTime = sub_cur;
                end
            end
            subSeqForeach(self, @checkBackgroundTime);
        end

        %% Other helper functions.

        function self = add(self, name, pulse, len)
            %% Convenient shortcut for adding a single pulse in a step.
            if isnumeric(pulse) || islogical(pulse)
                % `0` length for setting values.
                if exist('len', 'var')
                    error('Too many arguments for ExpSeq.add');
                end
                % The 10us here is just a placeholder.
                % The exact length doesn't really matter except for total sequence length
                add(addBackground(self, 1e-5), name, pulse);
            else
                add(addStep(self, len), name, pulse);
            end
        end

        function res = alignEnd(self, seq1, seq2, offset)
            %% Make sure that `seq1` and `seq2` ends at the same time and the longer
            % one of which started `offset` after the current time of this sequence.
            % Return the input steps as a cell array.
            if ~exist('offset', 'var')
                offset = 0;
            end
            if ~isnan(seq1.tOffset) || ~isnan(seq2.tOffset)
                error('alignEnd requires two floating sequences as inputs.');
            end
            if ~isa(seq1, 'ExpSeqBase')
                len1 = seq1.len;
            else
                len1 = seq1.curTime;
            end
            if ~isa(seq2, 'ExpSeqBase')
                len2 = seq2.len;
            else
                len2 = seq2.curTime;
            end
            if len1 > len2
                seq1.setTime(endTime(self), 0, offset);
                seq2.setEndTime(endTime(seq1));
            else
                seq2.setTime(endTime(self), 0, offset);
                seq1.setEndTime(endTime(seq2));
            end
            res = {seq1, seq2};
        end

        function res = totalTime(self)
            res = 0;
            for i = 1:self.nSubSeqs
                sub_seq = self.subSeqs{i};
                if isa(sub_seq, 'TimeStep')
                    sub_end = sub_seq.len + sub_seq.tOffset;
                else
                    sub_end = totalTime(sub_seq) + sub_seq.tOffset;
                end
                if sub_end > res
                    res = sub_end;
                end
            end
            if isnan(res)
                error('Cannot get total time with floating sub sequence.');
            end
        end

        function tdiff = getTimePointOffset(self, time)
            % Compute the offset of a `TimePoint` relative to current sequence
            if ~isa(time, 'TimePoint')
                error('`TimePoint` expected.');
            end
            other = time.seq;
            tdiff = offsetDiff(self, other);
            offset = time.offset;
            if time.anchor ~= 0
                if ~isa(other, 'ExpSeqBase')
                    len = other.len;
                else
                    len = other.curTime;
                end
                offset = offset + len * time.anchor;
            end
            tdiff = tdiff + offset;
        end
    end

    methods(Access=protected)
        function subSeqForeach(self, func)
            for i = 1:self.nSubSeqs
                func(self.subSeqs{i});
            end
        end

        function res = appendPulses(self, cid, res, toffset)
            %% Push pulse information (time, length, pulse function) within this subsequence
            % to `res` with a global time offset of `toffset` for the channel `cid`.
            % The information is pushed to `res` as new 3-row columns (see below).
            % `res` is passed in from the caller to minimize allocation.
            % Called by `ExpSeq::getPulse`.
            subSeqs = self.subSeqs;
            for i = 1:self.nSubSeqs
                sub_seq = subSeqs{i};
                if ~sub_seq.chn_mask(cid)
                    % fast path
                    continue;
                end
                seq_toffset = sub_seq.tOffset + toffset;
                % The following code is manually inlined for TimeStep.
                % since function call is super slow...
                if isa(sub_seq, 'TimeStep')
                    res(1:3, end + 1) = {seq_toffset, sub_seq.len, sub_seq.pulses{cid}};
                else
                    res = appendPulses(sub_seq, cid, res, seq_toffset);
                end
            end
        end

        function res = populateChnMask(self, nchn)
            % Make sure `chn_mask` has enough elements (so no bounds checks needed later)
            % and contains the correct mask for whether each channels are used in this
            % subsequence. Called after construction and before generation to speed up
            % the tree traversal during generation.
            res = false(1, nchn);
            subSeqs = self.subSeqs;
            for i = 1:self.nSubSeqs
                sub_seq = subSeqs{i};
                if isnan(sub_seq.tOffset)
                    error('Sub sequence still floating');
                end
                % The following code is manually inlined for TimeStep.
                % since function call is super slow...
                if isa(sub_seq, 'TimeStep')
                    subseq_pulses = sub_seq.pulses;
                    sub_res = false(1, nchn);
                    for j = 1:length(subseq_pulses)
                        if ~isempty(subseq_pulses{j})
                            sub_res(j) = true;
                            res(j) = true;
                        end
                    end
                    sub_seq.chn_mask = sub_res;
                else
                    res = res | populateChnMask(sub_seq, nchn);
                end
            end
            self.chn_mask = res;
        end
    end

    methods(Access=private)
        function [step, end_time] = addStepReal(self, curtime, first_arg, varargin)
            %% This is the function that handles the standard arguments
            % for creating time step or subsequence. (See comments above).
            % `curtime` is the reference time point (`nan` for `addFloating`)
            % The step constructed and the end time are returned.
            if ~isnumeric(first_arg)
                % If first arg is not a number, assume to be a callback for subsequence.
                [step, end_time] = addCustomStep(self, curtime, first_arg, varargin{:});
            elseif isempty(varargin)
                % If we only have one numerical argument it must be a simple time step.
                if first_arg <= 0
                    if isnan(curtime)
                        error('Floating time step with time offset not allowed.');
                    elseif first_arg == 0
                        error('Length of time step must be positive.');
                    end
                    start_time = first_arg + curtime;
                    len = -first_arg;
                else
                    start_time = curtime;
                    len = first_arg;
                    curtime = curtime + len;
                end
                step = TimeStep(self, start_time, len);
                end_time = curtime;
            elseif isnumeric(varargin{1})
                % If we only have two numerical argument it must be a simple time step
                % with custom offset.
                if length(varargin) > 1
                    % Only two arguments allowed in this case.
                    error('Too many arguments to create a time step.');
                elseif isnan(curtime)
                    error('Floating time step with time offset not allowed.');
                end
                offset = varargin{1};
                end_offset = offset + first_arg;
                if first_arg <= 0
                    error('Length of time step must be positive.');
                end
                step = TimeStep(self, offset + curtime, first_arg);
                end_time = end_offset + curtime;
            else
                % Number followed by a callback: subsequence with offset.
                if isnan(curtime)
                    error('Floating time step with time offset not allowed.');
                end
                [step, end_time] = addCustomStep(self, curtime + first_arg, varargin{:});
            end
        end

        function [step, end_time] = addCustomStep(self, start_time, cb, varargin)
            %% Add a subsequence by creating a child `ExpSeqBase` node and populating
            % it using the callback passed in.
            step = ExpSeqBase(self, start_time);
            % Create the step
            cb(step, varargin{:});
            end_time = start_time + step.curTime;
        end
    end
end
