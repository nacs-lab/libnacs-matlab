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

classdef TimeSeq < handle
    %TimeSeq is the parent class of TimeStep, ExpSeqBase > ExpSeq.
        %

  properties
    config;     %LoadConfig class. Contains hardware info, channel aliases, etc.
  end

  properties(Hidden)
    len = 0;
    parent = 0;
    tOffset = 0;
  end

  properties(Hidden)
    subSeqs;
    global_toffset = [];
  end

  %All Methods:
        % self = TimeSeq(parent_or_name, toffset, len)
        % res = logFile(self)
        % log(self, s)
        % logf(self, varargin)
        % res = length(self)
        % vals = getDefaults(self, cids)
        % res = getPulseTimes(self, cids)
        % vals = getValues(self, dt, varargin)
        % cid = translateChannel(self, name)
        % subSeqForeach(self, func)
        % id = nextPulseId(self)
        % id = nextSeqId(self)
        % val = getDefault(self, ~)
        % addSubSeq(self, sub_seq, toffset)
        % res = getPulses(self, cid)
        % res = getPulsesRaw(self, cid)


  methods
    function self = TimeSeq(parent, toffset, len)
      self.subSeqs = {};
      if exist('parent', 'var')
        self.parent = parent;
        self.tOffset = toffset;
        self.config = parent.config;
        parent.addSubSeq(self, toffset);
        if exist('len', 'var')
          self.len = len;
        end
      else
        self.config = loadConfig();
      end
    end

    function res = length(self)
        %?
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

    function res = endof(self)
        res = self.tOffset + length(self);
    end

    function cid = translateChannel(self, name)
      cid = self.parent.translateChannel(name);
    end
  end

  methods(Access=protected)
    function t=globalOffset(self)
      t = self.global_toffset;
      if isempty(t)
        self.global_toffset = [globalOffset(self.parent), self.tOffset];
        t = self.global_toffset;
      end
    end

    function subSeqForeach(self, func)
      nsub = size(self.subSeqs, 2);
      for i = 1:nsub
        func(self.subSeqs{i});
      end
    end

    function addSubSeq(self, sub_seq, toffset)
        %addSubSeq  puts the TimSeq object 'sub_seq' with 'toffset' (number) into a structure and puts it
            %in the cell aray SubSeqs, which is a property of the parent TimeSeq object 'self'.
            %toffset (number) is the offset time ?


      len = self.len;

      %Makes sure length of the sub-sequence fits in the parent sequence
      %'self'. If len !=0 for both parent and subseq, then makes sure
      %1) toffset > parent length   2) toffset + sub-seq length < parent seq length
      %len=0 means a variables length sequence, and if the parent is len=0, then the sub-seq must be as well.
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

    %%
    function res = getPulsesRaw(self, cid)
        %Called in getPulse method.
      % TODOPULSE use struct
      res = {};
      subSeqs = self.subSeqs;
      nsub = size(subSeqs, 2);
      for i = 1:nsub
        seq_t = subSeqs{i};
        subseq = seq_t.seq;
        % The following code is manually inlined from TimeStep::getPulsesRaw
        % since function call is super slow...
        if isa(subseq, 'TimeStep')
            subseq_pulses = subseq.pulses;
            if size(subseq_pulses, 2) < cid
                continue;
            end
            subseq_pulse = subseq_pulses{cid};
            if isempty(subseq_pulse)
                continue;
            end
            seq_toffset = seq_t.offset;
            res(1:3, end + 1) = {seq_toffset, subseq.len, subseq_pulse};
            continue;
        else
            sub_pulses = getPulsesRaw(subseq, cid);
        end

        nsub_pulses = size(sub_pulses, 2);
        res_offset = size(res, 2);
        if nsub_pulses <= 0
            continue;
        end
        seq_toffset = seq_t.offset;
        res(3, res_offset + nsub_pulses) = {0};
        for j = 1:nsub_pulses
          sub_tuple = sub_pulses(:, j);
          pulse_toffset = sub_tuple{1};
          pulse_len = sub_tuple{2};
          pulse_func = sub_tuple{3};
          res(1:3, res_offset + j) = {pulse_toffset + seq_toffset, pulse_len, pulse_func};
        end
      end
    end
  end
end
