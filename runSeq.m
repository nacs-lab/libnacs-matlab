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
      arglist = varargin{argidx:end};
      break;
    else
      error('Invalid argument.');
    end
    argidx = argidx + 1;
  end

  nseq = size(arglist, 2);
  seqlist = cell(1, nseq);

  %% TODO generate next sequence while the last one is running.
  for i = 1:nseq
    seqlist{i} = func(arglist{i}{:});
    seqlist{i}.generate();
  end

  if random
    if rep <= 0
      while true
        idx = randi(nseq);
        seqlist{idx}.run();
      end
    else
      idxs = repmat(1:nseq, [1, rep]);
      glob_idxs = randperm(nseq * rep);
      for i = 1:(nseq * rep)
        seqlist{idxs(glob_idxs(i))}.run();
      end
    end
  else
    if rep <= 0
      while true
        for i = 1:nseq
          seqlist{i}.run();
        end
      end
    else
      for j = 1:rep
        for i = 1:nseq
          seqlist{i}.run();
        end
      end
    end
  end
end
