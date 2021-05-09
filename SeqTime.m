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

classdef SeqTime < handle
    %% This represents a time offset from the start of the parent sequence
    % as a chain of terms. The sign describes the current term.
    properties(Constant, Hidden)
        Unknown = 0;
        NonNeg = 1;
        Pos = 2;
    end
    properties
        seq;
        id;
        sign;
        parent;
        term;
        % Note that the time ID is basic sequence specific.
        % However, we guarantee each `SeqTime` has a owner sequence
        % which means they have a owner basic sequence and therefore
        % should have only one ID.
        time_id = uint32(0); % Serialization ID
    end
    methods(Static)
        function res = zero(seq)
            res = SeqTime(seq, 0, SeqTime.Unknown, [], 0);
        end
    end
    methods
        function res = iszero(self)
            res = isempty(self.parent) && ...
                  (isnumeric(self.term) || islogical(self.term)) && self.term == 0;
        end
        function res = isnan(self)
            res = false;
        end
        function res = getVal(self)
            % TODO, we currently don't have a way to represent Int64.
            % This limits the max length of a basic sequence to about 2.5 hours
            % rather than about 3.5 months when using 1ps time step.
            res = self.term;
            self = self.parent;
            while ~isempty(self)
                term = self.term;
                self = self.parent;
                if ~isa(term, 'SeqVal')
                    if isa(res, 'SeqVal') && res.head == SeqVal.OPAdd
                        % Merge numerical terms together
                        if isnumeric(res.args{1}) || islogical(res.args{1})
                            res = (res.args{1} + term) + res.args{2};
                            continue;
                        end
                        if isnumeric(res.args{2}) || islogical(res.args{2})
                            res = (res.args{2} + term) + res.args{1};
                            continue;
                        end
                    end
                end
                res = res + term;
            end
        end
        % Combine the terms of time1 and time2, with the base sequence set to seq.
        function res = combine(time1, time2)
            if iszero(time2)
                res = time1;
                return;
            end
            if iszero(time1)
                if time2.seq == time1.seq
                    res = time2;
                else
                    res = resequence(time2, time1.seq);
                end
                return;
            end
            if ~isempty(time2.parent)
                time1 = combine(time1, time2.parent);
            end
            seq = time1.seq;
            if isnumeric(time1.term) || islogical(time1.term)
                if isnumeric(time2.term) || islogical(time2.term)
                    res = SeqTime(seq, time2.id, SeqTime.Unknown, time1.parent, ...
                                  time1.term + time2.term);
                    return;
                end
                % Try to always put numerical term at the end.
                res = SeqTime(seq, time2.id, time2.sign, time1.parent, time2.term);
                res = SeqTime(seq, time1.id, time1.sign, res, time1.term);
                return;
            end
            res = SeqTime(seq, time2.id, time2.sign, time1, time2.term);
        end
        % The caller is in charge of rounding the `term`
        function self = create(self, sign, term)
            seq = self.seq;
            selfterm = self.term;
            if isnumeric(term) || islogical(term)
                if term <= 0
                    if sign == SeqTime.Pos
                        error('Time offset/length must be positive');
                    elseif sign == SeqTime.NonNeg
                        if term < 0
                            error('Time offset/length must not be negative');
                        end
                    end
                    if term == 0
                        return;
                    end
                end
                if isnumeric(selfterm) || islogical(selfterm)
                    % The SeqTime ID is only used for error reporting.
                    % Since we've already checked that there's no need to generate a new one
                    self = SeqTime(seq, 0, SeqTime.Unknown, self.parent, selfterm + term);
                    return;
                end
            elseif isnumeric(selfterm) || islogical(selfterm)
                % Try to always put numerical term at the end.
                oldid = self.id;
                oldsign = self.sign;
                ctx = seq.topLevel.seq_ctx;
                % Inlined implementation of `SeqContext::nextObjID` for hot path
                id = ctx.obj_counter;
                ctx.obj_counter = id + 1;
                if ctx.collect_dbg_info
                    ctx.obj_backtrace{id + 1} = dbstack('-completenames', 1);
                end
                self = SeqTime(seq, id, sign, self.parent, term);
                self = SeqTime(seq, oldid, oldsign, self, selfterm);
                return;
            end
            if iszero(self)
                self = [];
            end
            ctx = seq.topLevel.seq_ctx;
            % Inlined implementation of `SeqContext::nextObjID` for hot path
            id = ctx.obj_counter;
            ctx.obj_counter = id + 1;
            if ctx.collect_dbg_info
                ctx.obj_backtrace{id + 1} = dbstack('-completenames', 1);
            end
            self = SeqTime(seq, id, sign, self, term);
        end
        function res = toString(self, ignore_zero)
            if ~exist('ignore_zero', 'var')
                ignore_zero = false;
            end
            parent = self.parent;
            seq = self.seq;
            term = self.term;
            if ~isempty(parent)
                parentstr = toString(parent, true);
            elseif ~isempty(seq.parent)
                parentstr = toString(seq.tOffset, true);
            else
                parentstr = '';
            end
            if (isnumeric(term) || islogical(term)) && term == 0
                termstr = '';
            else
                termstr = SeqVal.toString(term);
                if self.sign == SeqTime.Pos
                    termstr = [termstr '/p'];
                elseif self.sign == SeqTime.NonNeg
                    termstr = [termstr '/nn'];
                end
            end
            if isempty(parentstr)
                if isempty(termstr)
                    if ignore_zero
                        res = '';
                    else
                        res = '0';
                    end
                else
                    res = termstr;
                end
            else
                if isempty(termstr)
                    res = parentstr;
                else
                    res = [parentstr ' + ' termstr];
                end
            end
        end
    end
    methods(Access=private)
        function res = resequence(self, seq)
            parent = self.parent;
            if ~isempty(parent)
                parent = resequence(parent, seq);
            end
            res = SeqTime(seq, self.id, self.sign, parent, self.term);
        end
        function self = SeqTime(seq, id, sign, parent, term)
            % `term` is pre-incremented with the scaling factor from user input.
            self.seq = seq;
            self.id = id;
            self.sign = sign;
            self.parent = parent;
            if ~isempty(parent)
                assert(parent.seq == seq);
            end
            self.term = term;
        end
    end
end
