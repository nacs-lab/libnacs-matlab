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

classdef BasicSeq < RootSeq
    %% `BasicSeq` is a non top-level root sequence.
    % This is a thin wrapper around `RootSeq` for the constructor.
    methods
        function self = BasicSeq(parent)
            self.config = parent.config;
            self.topLevel = parent;
            self.root = self;
            self.C = parent.C;
            self.zero_time = SeqTime.zero(self);
            self.curSeqTime = self.zero_time;
            % Add to parent
            parent.basic_seqs{end + 1} = self;
            self.bseq_id = length(parent.basic_seqs) + 1;
        end
    end
end
