%% Copyright (c) 2014-2014, Yichao Yu <yyc1992@gmail.com>
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

tseq = timeSeq();
subseq1 = timeSeq(tseq, 0);
subseq2 = timeSeq(tseq, 2);
tseq.globChannelAvailable('', 2)
tseq.globChannelAvailable('', 1)
tseq.globChannelAvailable('', 0)

subseq1.globChannelAvailable('', 2)
subseq1.globChannelAvailable('', 1)
subseq1.globChannelAvailable('', 0)

subseq2.globChannelAvailable('', 2)
subseq2.globChannelAvailable('', 1)
subseq2.globChannelAvailable('', 0)
