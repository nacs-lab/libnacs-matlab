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

function runSeq(func, varargin)
  %% runSeq(func, [rep], ['random'], [{arguments}])
  rep = 1;
  has_rep = false;
  random = false;

  arglist = {{}};

  if ischar(func)
    func = str2func(func);
  end

  argidx = 1;
  while argidx < nargin
    arg = varargin{argidx};
    if isnumeric(arg)
      if has_rep
        error('Repetition can only be specified once.');
      end
      has_rep = true;
      rep = arg;
    elseif ischar(arg)
      if strcmp(arg, 'random')
        random = true;
      else
        error('Invalid option %s.', arg);
      end
    elseif iscell(arg)
      arglist = {varargin{argidx:end}};
      break;
    else
      error('Invalid argument.');
    end
    argidx = argidx + 1;
  end

  nseq = size(arglist, 2);
  seqlist = cell(1, nseq);

  function prepare_seq(idx)
    if ~isempty(seqlist{idx})
      return;
    end
    seqlist{idx} = func(arglist{idx}{:});
    seqlist{idx}.generate();
  end

  function run_seq(idx, next_idx)
    prepare_seq(idx);
    seqlist{idx}.run_async();
    if next_idx > 0
      prepare_seq(next_idx);
    end
    seqlist{idx}.wait();
  end

  if random
    if rep <= 0
      idx = randi(nseq);
      while true
        idx_new = randi(nseq);
        run_seq(idx, idx_new);
        idx = idx_new;
      end
    else
      idxs = repmat(1:nseq, [1, rep]);
      total_len = nseq * rep;
      glob_idxs = randperm(total_len);
      for i = 1:total_len
        cur_idx = idxs(glob_idxs(i));
        if cur_idx >= total_len
          next_idx = 0;
        else
          next_idx = idxs(glob_idxs(i + 1));
        end
        run_seq(cur_idx, next_idx);
      end
    end
  else
    for i = 1:nseq
      if i < nseq
        run_seq(i, i + 1);
      else
        seqlist{i}.run();
      end
    end
    if rep <= 0
      while true
        for i = 1:nseq
          seqlist{i}.run();
        end
      end
    else
      for j = 2:rep
        for i = 1:nseq
          seqlist{i}.run();
        end
      end
    end
  end
end
