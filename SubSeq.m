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

classdef SubSeq < ExpSeqBase
    % Sub sequence of another sequence
    % This is a thin wrapper around `ExpSeqBase` to implement the constructor.
    methods
        function self = SubSeq(parent, toffset)
            % Set offset and cache some shared properties
            % from its parent for fast lookup.
            self.parent = parent;
            self.tOffset = toffset;
            self.config = parent.config;
            self.topLevel = parent.topLevel;
            self.C = parent.C;
            self.G = parent.G;
            % Add to parent
            ns = parent.nSubSeqs + 1;
            parent.nSubSeqs = ns;
            if ns > length(parent.subSeqs)
                parent.subSeqs{round(ns * 1.3) + 8} = [];
            end
            parent.subSeqs{ns} = self;
        end
    end
end
