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

classdef TimeSeq < dynamicprops
  properties
    config;
  end

  properties(Hidden, Access=protected)
    len = 0;
    parent = 0;
  end

  properties(Hidden, Access=private)
    subSeqs;
    tOffset;
  end

  methods
    function self = TimeSeq(parent_or_name, toffset, len)
      self.subSeqs = {};
      if nargin < 1
        self.config = loadConfig();
      elseif nargin < 2
        self.config = loadConfig();
      else
        self.parent = parent_or_name;
        self.tOffset = toffset;

        self.config = parent_or_name.config;
        parent_or_name.addSubSeq(self, toffset);
        if nargin >= 3
          self.len = len;
        end
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
          seq_t = self.subSeqs{i};
          sub_end = seq_t.seq.length() + seq_t.offset;
          if sub_end > res
            res = sub_end;
          end
        end
      end
    end

    function cid = translateChannel(self, name)
      cid = self.parent.translateChannel(name);
    end
  end

  methods(Access=protected)
    function subSeqForeach(self, func)
      nsub = size(self.subSeqs, 2);
      for i = 1:nsub
        func(self.subSeqs{i});
      end
    end

    function addSubSeq(self, sub_seq, toffset)
      len = self.len;
      if len > 0
        sub_len = sub_seq.len;
        if sub_len <= 0
          error(['Cannot add a variable length sequence to' ...
                   'a fixed length sequence']);
        elseif toffset > len
          error('Too big sub-sequence time offset.');
        elseif toffset + sub_len > len
          error('Too long sub-sequence.');
        end
      end
      self.subSeqs{end + 1} = struct('offset', toffset, 'seq', sub_seq);
    end

    function res = getPulsesRaw(self, cid)
      %% TODOPULSE use struct
      res = {};
      nsub = size(self.subSeqs, 2);
      for i = 1:nsub
        seq_t = self.subSeqs{i};
        subseq = seq_t.seq;
        % The following code is manually inlined from TimeStep::getPulseRaw
        % since function call is super slow...
        if isa(subseq, 'TimeStep')
            subseq_pulses = subseq.pulses;
            if size(subseq_pulses, 2) < cid
                continue;
            end
            subseq_pulses2 = subseq_pulses{cid};
            if isempty(subseq_pulses2)
                continue;
            end
        end
        sub_pulses = getPulsesRaw(subseq, cid);

        nsub_pulses = size(sub_pulses, 1);
        res_offset = size(res, 1);
        if nsub_pulses <= 0
            continue;
        end
        res(res_offset + nsub_pulses, 6) = {0};
        for j = 1:nsub_pulses
          sub_tuple = sub_pulses(j, :);
          pulse_toffset = sub_tuple{1};
          pulse_len = sub_tuple{2};
          pulse_func = sub_tuple{3};
          step_toffset = sub_tuple{4};
          step_len = sub_tuple{5};
          res(res_offset + j, 1:6) = {pulse_toffset + seq_t.offset, pulse_len, pulse_func, ...
                                      step_toffset + seq_t.offset, step_len, cid};
        end
      end
    end
  end
end
