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

%Set up memory map to share variables between MATLAB instances.
m = MemoryMap;

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
        %         m = MemoryMap;
        arglist_str = [];
        for j = 1:length(arglist{idx})
            arglist_str = [arglist_str ', ' num2str(arglist{idx}{j})];
        end
        arglist_str(1) = ' ';
        disp(['Preparing to run sequence #' int2str(m.Data(1).CurrentSeqNum)...
            ' with ' int2str(length(arglist{idx})) ' arguments:' arglist_str]);
        params{end + 1} = arglist{idx};
    end

    function run_seq(idx, next_idx)
        prepare_seq(idx);
        log_run(idx);
        seqlist{idx}.run_async();
        if next_idx > 0
            prepare_seq(next_idx);
        end
        seqlist{idx}.waitFinish();
    end

if rep < 0
    error('Cannot run the sequence by negative times.');
end

if is_random
    if rep == 0
        idx = randi(nseq);
        while true
            % If another instance has asked runSeq to abort, exit gracefully
            if m.Data(1).AbortRunSeq == 1
                disp('AbortRunSeq set to 1.  Stopping gracefully.')
                %                 m.Data(1).AbortRunSeq = 0;
                break
            end
            idx_new = randi(nseq);
            run_seq(idx, idx_new);
            idx = idx_new;
        end
    else
        idxs = repmat(1:nseq, [1, rep]);
        total_len = nseq * rep;
        glob_idxs = randperm(total_len);
        for i = 1:total_len
            % If another instance has asked runSeq to abort, exit gracefully
            if m.Data(1).AbortRunSeq == 1
                disp('AbortRunSeq set to 1.  Stopping gracefully.')
                %                 m.Data(1).AbortRunSeq = 0;
                break
            end
            cur_idx = idxs(glob_idxs(i));
            if i >= total_len
                next_idx = 0;
            else
                next_idx = idxs(glob_idxs(i + 1));
            end
            run_seq(cur_idx, next_idx);
            
        end
    end
else
    for i = 1:nseq
        % If another instance has asked runSeq to abort, exit gracefully
        if m.Data(1).AbortRunSeq == 1
            disp('AbortRunSeq set to 1.  Stopping gracefully.')
            %                 m.Data(1).AbortRunSeq = 0;
            break
        end
        if i < nseq
            run_seq(i, i + 1);
        else
            run_seq(i, 0);
        end
    end
    if rep == 0
        while true
            % If another instance has asked runSeq to abort, exit gracefully
            if m.Data(1).AbortRunSeq == 1
                disp('AbortRunSeq set to 1.  Stopping gracefully.')
                %                     m.Data(1).AbortRunSeq = 0;
                break
            end
            for i = 1:nseq
                % If another instance has asked runSeq to abort, exit gracefully
                if m.Data(1).AbortRunSeq == 1
                    disp('AbortRunSeq set to 1.  Stopping gracefully.')
                    %                     m.Data(1).AbortRunSeq = 0;
                    break
                end
                log_run(i);
                seqlist{i}.run();
            end
        end
    else
        for j = 2:rep
            % If another instance has asked runSeq to abort, exit gracefully
            if m.Data(1).AbortRunSeq == 1
                disp('AbortRunSeq set to 1.  Stopping gracefully.')
                %                 m.Data(1).AbortRunSeq = 0;
                break
            end
            for i = 1:nseq
                % If another instance has asked runSeq to abort, exit gracefully
                if m.Data(1).AbortRunSeq == 1
                    disp('AbortRunSeq set to 1.  Stopping gracefully.')
                    %                     m.Data(1).AbortRunSeq = 0;
                    break
                end
                log_run(i);
                seqlist{i}.run();
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
m.Data(1).CurrentSeqNum = 0;
m.Data(1).AbortRunSeq = 0;
m.Data(1).PauseRunSeq = 0;
end

