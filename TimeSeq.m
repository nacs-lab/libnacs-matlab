%% Copyright (c) 2014-2018, Yichao Yu <yyc1992@gmail.com>
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

classdef TimeSeq < handle
    % Parent class of TimeStep, ExpSeqBase > ExpSeq.

    properties
        config;     %LoadConfig class. Contains hardware info, channel aliases, etc.
    end

    properties(Hidden)
        len = 0;
        parent = 0;
        tOffset = 0;
        topLevel = 0;
    end

    properties(Hidden)
        subSeqs;
        global_path = {};
    end

    %All Methods:
    % self = TimeSeq(parent_or_name, toffset, len)
    % res = logFile(self)
    % log(self, s)
    % logf(self, varargin)
    % res = length(self)
    % vals = getDefaults(self, cids)
    % vals = getValues(self, dt, varargin)
    % cid = translateChannel(self, name)
    % subSeqForeach(self, func)
    % id = nextPulseId(self)
    % id = nextSeqId(self)
    % val = getDefault(self, ~)
    % addSubSeq(self, sub_seq)


    methods
        function self = TimeSeq(parent, toffset, len)
            self.subSeqs = {};
            if exist('parent', 'var')
                self.parent = parent;
                self.tOffset = toffset;
                self.config = parent.config;
                self.topLevel = parent.topLevel;
                if exist('len', 'var')
                    self.len = len;
                end
            else
                self.config = loadConfig();
                self.topLevel = self;
            end
        end

        function res = length(self)
            if self.len > 0
                res = self.len;
                return;
            else
                res = 0;
                nsub = size(self.subSeqs, 2);
                for i = 1:nsub
                    sub_seq = self.subSeqs{i};
                    sub_end = sub_seq.length() + sub_seq.tOffset;
                    if sub_end > res
                        res = sub_end;
                    end
                end
            end
            if isnan(res)
                error('Cannot get length with floating sub sequence.');
            end
        end

        function res = endof(self)
            toffset = self.tOffset;
            if isnan(toffset)
                error('Cannot get end time of floating sequence.');
            end
            res = toffset + length(self);
        end

        function cid = translateChannel(self, name)
            cid = translateChannel(self.topLevel, name);
        end

        function setTime(self, time, anchor, offset)
            if ~exist('anchor', 'var')
                anchor = 0;
            end
            if ~exist('offset', 'var')
                offset = 0;
            end
            if ~isa(time, 'TimePoint')
                error('Time must be a `TimePoint`.');
            end
            if ~isnan(self.tOffset)
                error('Not a floating sequence.');
            end
            other = time.seq;
            tdiff = offsetDiff(self.parent, other);
            if time.anchor ~= 0
                if ~isa(other, 'ExpSeqBase')
                    len = other.len;
                else
                    len = other.curTime;
                end
                tdiff = tdiff + len * time.anchor;
            end
            tdiff = tdiff + time.offset + offset;
            if anchor ~= 0
                if ~isa(self, 'ExpSeqBase')
                    len = self.len;
                else
                    len = self.curTime;
                end
                tdiff = tdiff - len * anchor;
            end
            self.tOffset = tdiff;
        end

        function setEndTime(self, time, offset)
            if ~exist('offset', 'var')
                offset = 0;
            end
            setTime(self, time, 1, offset);
        end
    end

    methods(Access=protected)
        function p=globalPath(self)
            p = self.global_path;
            if isempty(p)
                self.global_path = globalPath(self.parent);
                self.global_path{end + 1} = self;
                p = self.global_path;
            end
        end

        function res = offsetDiff(self, step)
            %% compute the offset different starting from the lowest common ancestor
            % This reduce rounding error and make it possible to support floating sequence
            % in the common ancestor.
            self_path = globalPath(self);
            other_path = globalPath(step);
            nself = size(self_path, 2);
            nother = size(other_path, 2);
            res = 0;
            for i = 1:max(nself, nother)
                if i <= nself
                    self_ele = self_path{i};
                    if i <= nother
                        other_ele = other_path{i};
                        if self_ele == other_ele
                            continue;
                        end
                        res = res + other_ele.tOffset - self_ele.tOffset;
                    else
                        res = res - self_ele.tOffset;
                    end
                else
                    other_ele = other_path{i};
                    res = res + other_ele.tOffset;
                end
            end
            if isnan(res)
                error('Cannot compute offset different for floating sequence');
            end
        end

        function subSeqForeach(self, func)
            nsub = size(self.subSeqs, 2);
            for i = 1:nsub
                func(self.subSeqs{i});
            end
        end

        function addSubSeq(self, sub_seq)
            %% addSubSeq  puts the TimSeq object 'sub_seq' in the cell array subSeqs.
            if self.len > 0
                error(['Cannot add sub sequence to a fixed length sequence']);
            end
            self.subSeqs{end + 1} = sub_seq;
        end

        function res = appendPulses(self, cid, res, toffset)
            %% Called in getPulse method.
            % TODOPULSE use struct
            subSeqs = self.subSeqs;
            nsub = size(subSeqs, 2);
            for i = 1:nsub
                sub_seq = subSeqs{i};
                seq_toffset = sub_seq.tOffset + toffset;
                if isnan(seq_toffset)
                    error('Cannot get length with floating sub sequence.');
                end
                % The following code is manually inlined for TimeStep.
                % since function call is super slow...
                if isa(sub_seq, 'TimeStep')
                    subseq_pulses = sub_seq.pulses;
                    if size(subseq_pulses, 2) < cid
                        continue;
                    end
                    subseq_pulse = subseq_pulses{cid};
                    if isempty(subseq_pulse)
                        continue;
                    end
                    res(1:3, end + 1) = {seq_toffset, sub_seq.len, subseq_pulse};
                else
                    res = appendPulses(sub_seq, cid, res, seq_toffset);
                end
            end
        end
    end
end
