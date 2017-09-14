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

function params = runSeq(func, varargin)
%% runSeq(func, [options], [{arguments}])
%%    @func: the function or otherwise callable object (or the name of it)
%%        to construct the sequence to run.
%%    @options (optional): parameter to define how the sequences are run.
%%        Currently supported options includes
%%        <number> (default: 1): How many times each sequence will be run.
%%            If the number is equal to 0, run the sequence continiously.
%%        'random': run the sequences in random order
%%        'email:xxx': send an email upon completion.  xxx can be a name
%%            appearing in matlabmail, or an email address.
%%    @arguments (optional, multiple): cell arrays of the arguments to
%%        construct the sequence. Each argument will be used to construct
%%        a sequence.
%%
%%    Run the sequence constructed by func.
params = {};
rep = 1;
has_rep = false;
is_random = false;
return_array = false;
notify = [];

seq_map = containers.Map('KeyType', 'double', 'ValueType', 'double');

%Set up memory map to share variables between MATLAB instances.
m = MemoryMap();

% Current sequence number.  Will be incremented at the end of each sequence
% execution in ExpSeq.
m.Data(1).CurrentSeqNum = 0;

arglist = {{}};

if ischar(func)
    func = str2func(func);
end

argidx = 1;
arglist_set = false;

while argidx < nargin
    arg = varargin{argidx};
    if isnumeric(arg)
        if has_rep || length(arg) > 1
            if arglist_set
                error('Argument list can only be specified once');
            end
            arglist_set = true;
            return_array = true;
            arglist = {};
            for i = 1:size(arg, 2)
                arglist{end + 1} = num2cell(arg(:, i)');
            end
        else
            has_rep = true;
            rep = arg;
        end
    elseif ischar(arg)
        if strcmp(arg, 'random')
            is_random = true;
        elseif strcmp(arg(1:5), 'email')
            notify = arg(7:end);
        else
            error('Invalid option %s.', arg);
        end
    elseif iscell(arg)
        if arglist_set
            error('Argument list can only be specified once');
        end
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
        elseif length(arglist{idx}) == 1 && isnumeric(arglist{idx}{1})
          arg0 = arglist{idx}{1};
          if isKey(seq_map, arg0)
            seqlist{idx} = seqlist{seq_map(arg0)};
            return;
          end
          seq_map(arg0) = idx;
        end
        global nacsTimeSeqDisableRunHack;
        global nacsTimeSeqNameSuffixHack;
        nacsTimeSeqDisableRunHack = 1;
        if is_random
            nacsTimeSeqNameSuffixHack = sprintf('-runRandom_%d-%d', idx, nseq);
        else
            nacsTimeSeqNameSuffixHack = sprintf('-runSeq_%d-%d', idx, nseq);
        end
        seqlist{idx} = func(arglist{idx}{:});
        nacsTimeSeqDisableRunHack = 0;
        nacsTimeSeqNameSuffixHack = [];
        seqlist{idx}.generate();
    end

    function log_run(idx)
        arglist_str = [];
        for j = 1:length(arglist{idx})
            arglist_str = [arglist_str ', ' num2str(arglist{idx}{j})];
        end
        arglist_str(1) = ' ';
        disp(['Preparing to run sequence #' int2str(m.Data(1).CurrentSeqNum)...
            ' with ' int2str(length(arglist{idx})) ' arguments:' arglist_str]);
        params{end + 1} = arglist{idx};
    end

    function abort = run_seq(idx, next_idx)
        if CheckPauseAbort(m)
            disp('AbortRunSeq set to 1.  Stopping gracefully.');
            abort = 1;
            return;
        end
        abort = 0;
        prepare_seq(idx);
        log_run(idx);
        run_async(seqlist{idx});
        if next_idx > 0
            prepare_seq(next_idx);
        end
        m.Data(1).CurrentSeqNum = m.Data(1).CurrentSeqNum + 1;
        waitFinish(seqlist{idx});
        % If we are using NumGroup to run sequences in groups, pause every
        % NumGroup sequences.
        if ~mod(m.Data(1).CurrentSeqNum, m.Data(1).NumPerGroup) && (m.Data(1).NumPerGroup>0)
          m.Data(1).PauseRunSeq = 1;
        end
    end

if rep < 0
    error('Cannot run the sequence by negative times.');
end

if is_random
    if rep == 0
        idx = randi(nseq);
        while true
            idx_new = randi(nseq);
            if run_seq(idx, idx_new)
                break;
            end
            idx = idx_new;
        end
    else
        idxs = repmat(1:nseq, [1, rep]);
        total_len = nseq * rep;
        glob_idxs = randperm(total_len);
        for i = 1:total_len
            cur_idx = idxs(glob_idxs(i));
            if i >= total_len
                next_idx = 0;
            else
                next_idx = idxs(glob_idxs(i + 1));
            end
            if run_seq(cur_idx, next_idx)
                break;
            end
        end
    end
else
    abort = 0;
    for i = 1:nseq
        if i < nseq
            abort = run_seq(i, i + 1);
        else
            abort = run_seq(i, 0);
        end
        if abort
            break;
        end
    end
    if rep == 0
        while ~abort
            for i = 1:nseq
                if run_seq(i, 0)
                    abort = 1;
                    break;
                end
            end
        end
    else
        for i0 = 2:rep
            for i = 1:nseq
                if run_seq(i, 0)
                    abort = 1;
                    break;
                end
            end
            if abort
                break;
            end
        end
    end
end
if return_array
    params_array = [];
    for i = 1:length(params)
        params_array = [params_array; params{i}{:}];
    end
    params = params_array;
end
disp(['Finished running ' int2str(m.Data(1).CurrentSeqNum) ' sequences.'])
beep
m.Data(1).CurrentSeqNum = 0;
m.Data(1).AbortRunSeq = 0;
m.Data(1).PauseRunSeq = 0;
if ~isempty(notify)
    matlabmail(notify, [], ['Molecube: finished sequence at '...
        datestr(datenum(clock),'yyyymmdd') '-' datestr(datenum(clock),'HHMMSS')]);
end
end
