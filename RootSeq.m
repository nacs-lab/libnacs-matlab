% Copyright (c) 2021-2021, Yichao Yu <yyc1992@gmail.com>
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

classdef RootSeq < ExpSeqBase
    %% `RootSeq` is the object representing part of an experimental sequence
    % without control flow (root node).
    % This may be a top level sequence or a basic sequence.
    properties(Access=protected)
        bseq_id;
        norders = 0;
        orders = {};
        default_target = [];
        branches = struct('cond', {}, 'target', {}, 'id', {});
    end
    properties(Hidden)
        zero_time;
    end

    methods
        function condBranch(self, cond, target)
            assert(isempty(target) || isa(target, 'RootSeq'));
            id = nextObjID(self.topLevel.seq_ctx);
            self.branches(end + 1) = struct('cond', cond, 'target', target, 'id', id);
        end

        function defaultBranch(self, target)
            assert(isempty(target) || isa(target, 'RootSeq'));
            self.default_target = target;
        end
    end

    methods(Access=protected)
        function t = globalPath(self)
            t = {};
        end
    end

    methods(Access=?TimeSeq)
        function addOrder(self, sign, before, after)
            norders = self.norders + 1;
            self.norders = norders;
            if norders > length(self.orders)
                self.orders{round(norders * 1.3) + 8} = [];
            end
            id = nextObjID(self.topLevel.seq_ctx);
            order = {id, sign, before, after};
            self.orders{norders} = order;
        end
        function addEqual(self, time1, time2)
            addOrder(self, SeqTime.NonNeg, time1, time2);
            addOrder(self, SeqTime.NonNeg, time2, time1);
        end
    end
end
