%% Copyright (c) 2014-2018, Yichao Yu <yyc1992@gmail.com>
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
% This is the base class of `TimeStep` and `ExpSeqBase`,
% which form a sequence in a directed acyclic graph (DAG).
% All the non-leaf nodes are `ExpSeqBase`, which represents a sub-sequence that
% host an arbitrary number of steps or sub-sequences.
% All outputs (pulses) are stored in the leaf nodes `TimeStep`.
%
% All the timing info is stored in the DAG. See `ExpSeqBase` for the timing APIs.
% The pulse (output) info is stored in the step (leaf node).
% See `TimeStep` for the APIs that operate on the output.
%
% This class stores information that's needed for both sub-sequences and steps,
% e.g. global config, parent, timing information, etc.
%
% The main differences between the two immediate subclasses are,
% * `ExpSeqBase` may have childs but will not have a fixed length.
% * `TimeStep` will have a fixed length but cannot have childs.
%   Instead, `TimeStep` can only contain pulses, which describe the
%   output to be done on certain channels.
%
% The separation of the time and output info/API allows one to be changed/understood
% without changing/understanding the other.
% For example, the timing of the sequence can be inferred without looking at any
% pulses and the output on a channel can be found and understood without
% looking at the timing (one still need both to understand the whole sequence of course).
% More importantly, pulses can be added and removed without **any** effect on the timing,
% which is really important when debugging/tweaking an actual experiemental sequence.
classdef TimeSeq < handle
    properties(Hidden)
        % This is a `SeqConfig` that contains global config loaded from `expConfig`.
        config;
        % Points to parent node, or `0` for root node.
        parent = 0;
        % The time offset of this node within the parent node.
        % After the whole sequence is constructed, all of the time offsets must be finite.
        % A `nan` time offset is allowed during the construction representing a
        % floating step/subsequence that can be positioned later.
        tOffset = 0;
        % The root node (the toplevel sequence).
        topLevel;
        % This is the path from the root node, including self and not including the root.
        % This is computed lazily (see `TimeSeq::globalPath`) and is used to find the
        % closest common ancestor of two nodes (see `TimeSeq::offsetDiff`).
        global_path = {};
        % This is a boolean array storing whether the sequence contain pulses for
        % each channel. The array is indexed by the channel ID.
        % The field is computed and cached before generation starts (see `ExpSeq::generate`).
        chn_mask;
    end

    methods
        %%
        % Translate from channel name to channel ID.
        % This is just a wrapper for `ExpSeq::translateChannel`.
        % All internal users should use `translateChannel(self.topLevel, name)` due to
        % the slowness of function call and this is provided for convinience of the user.
        % For example, the user could pre-lookup the channel ID and
        % use that instead of the channel name in the sequence if it is known that
        % the channel will be used many times later.
        function cid = translateChannel(self, name)
            cid = translateChannel(self.topLevel, name);
        end

        %%
        % Position a currently floating step/sub sequence (`self`)
        % The `anchor` percentage point of the current `TimeSeq` will be positioned
        % `offset` after the time point. The length of the current sequence
        % is the current time for sub sequences (`ExpSeqBase`)
        % and length for steps (`TimeStep`), consistent with the logic in `TimePoint`.
        %
        % NOTE: The choice of the definition for `TimeStep` is obvious and the choice for
        %   `ExpSeqBase` is because current time is what's more visible to the user
        %   than the total length of the subsquence including all background sequence.
        %   In fact, total length of the sequence is rarely useful/reliable
        %   since sub-sequences within the current sequence could have late background steps
        %   that are very hard to discover.
        function setTime(self, time, anchor, offset)
            if ~exist('anchor', 'var')
                anchor = 0;
            end
            if ~exist('offset', 'var')
                offset = 0;
            end
            if ~isnan(self.tOffset)
                error('Not a floating sequence.');
            end
            tdiff = getTimePointOffset(self.parent, time) + offset;
            if anchor ~= 0
                if ~isa(self, 'ExpSeqBase')
                    len = self.len;
                else
                    len = self.curTime;
                end
                tdiff = tdiff - len * anchor;
            end
            if tdiff < 0
                error('Negative time offset not allowed.');
            end
            self.tOffset = tdiff;
        end

        %%
        % Wrapper of `TimeSeq::setTime` to set the time based on end time.
        % See `TimeSeq::setTime`.
        function setEndTime(self, time, offset)
            if ~exist('offset', 'var')
                offset = 0;
            end
            setTime(self, time, 1, offset);
        end
    end

    methods(Access=protected)
        function p = globalPath(self)
            %% See `global_path` above.
            p = self.global_path;
            if isempty(p)
                self.global_path = globalPath(self.parent);
                self.global_path{end + 1} = self;
                p = self.global_path;
            end
        end

        function res = offsetDiff(self, step)
            %% Compute the offset different starting from the lowest common ancestor
            % This reduce rounding error and make it possible to support floating sequence
            % in the common ancestor.
            self_path = globalPath(self);
            other_path = globalPath(step);
            nself = length(self_path);
            nother = length(other_path);
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
    end
end
