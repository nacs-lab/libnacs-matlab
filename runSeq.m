%% Copyright (c) 2014-2021, Yichao Yu <yyc1992@gmail.com>
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

function params = runSeq(func, varargin)
    %% runSeq(func, [options], [{arguments}])
    % Run the sequence constructed by func.
    %    @func: the function or otherwise callable object (or the name of it)
    %        to construct the sequence to run.
    %    @options (optional): parameter to define how the sequences are run.
    %        Currently supported options includes
    %        <number> (default: 1): How many times each sequence will be run.
    %            If the number is equal to 0, run the sequence continiously.
    %        'random': run the sequences in random order
    %        'email:xxx': send an email upon completion.  xxx can be a name
    %            appearing in matlabmail, or an email address.
    %        'pre_cb' <cb>: register a callback that will be called before
    %            the sequence starts. The callback will be called
    %            with the global sequence index (1-based) and
    %            the current parameter list.
    %        'post_cb' <cb>: register a callback that will be called after
    %            the sequence ends. The callback will be called
    %            with the global sequence index (1-based) and
    %            the current parameter list.
    %    @arguments (optional, multiple): cell arrays of the arguments to
    %        construct the sequence. Each argument will be used to construct
    %        a sequence.
    params = {};
    % no need to keep track of a growing array if no one is interested in it.
    has_ret = nargout > 0;
    rep = 1;
    has_rep = false;
    is_random = false;
    return_array = false;
    notify = [];

    seq_map = java.util.Hashtable();
    SeqConfig.cache(1);
    seq_config = SeqConfig.get();

    function runSeqCleanup()
        SeqConfig.reset();
    end

    cleanup = onCleanup(@runSeqCleanup);

    %Set up memory map to share variables between MATLAB instances.
    m = MemoryMap();

    % Current sequence number.  Will be incremented at the end of each sequence
    % execution in ExpSeq.
    m.Data(1).CurrentSeqNum = 0;

    arglist = {{}};

    argidx = 1;
    arglist_set = false;
    is_scangroup = false;
    scangroup = [];

    function res = ary2cell(ary)
        res = {};
        for i = 1:size(ary, 2)
            res{end + 1} = num2cell(ary(:, i)');
        end
    end

    pre_cb = {};
    post_cb = {};
    tstartwait = 0;

    %%
    while argidx < nargin
        arg = varargin{argidx};
        if isnumeric(arg) || islogical(arg)
            if has_rep || length(arg) > 1
                if arglist_set
                    error('Argument list can only be specified once');
                end
                arglist_set = true;
                return_array = true;
                arglist = ary2cell(arg);
            else
                has_rep = true;
                rep = arg;
            end
        elseif ischar(arg)
            if strcmp(arg, 'random')
                is_random = true;
            elseif strcmp(arg, 'pre_cb')
                argidx = argidx + 1;
                pre_cb{end + 1} = varargin{argidx};
            elseif strcmp(arg, 'post_cb')
                argidx = argidx + 1;
                post_cb{end + 1} = varargin{argidx};
            elseif strcmp(arg, 'tstartwait')
                argidx = argidx + 1;
                tstartwait = varargin{argidx};
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
            arglist_set = true;
            break;
        elseif isa(arg, 'ScanGroup')
            if is_scangroup
                error('Multiple ScanGroup specified.');
            end
            scangroup = arg;
            is_scangroup = true;
        else
            error('Invalid argument.');
        end
        argidx = argidx + 1;
    end

    nseq = length(arglist);
    seqlist = cell(1, nseq);
    if is_scangroup
        % Can't use `nseq(scangroup)` since `nseq` is a local variable.
        scan_size = scangroup.nseq();
        % A table of all the index we'll run to keep track of what's left.
        all_scan_index = java.util.Hashtable();
        % For scan group, all arguments must be a inbounds integer
        for i = 1:nseq
            arg = arglist{i};
            if length(arg) ~= 1
                error('Scan group index must be a single number.');
            end
            arg = arg{:};
            if length(arg) ~= 1
                error('Scan group index must be a scalar.');
            elseif arg ~= floor(arg)
                error('Scan group index must be a integer.');
            elseif arg < 1 || arg > scan_size
                error('Scan group index out of bound.');
            end
            put(all_scan_index, arg, true);
        end
        use_scan_tracker = seq_config.warnUnusedScan;
        if use_scan_tracker
            scan_tracker = ScanAccessTracker(scangroup);
        end
    end

    % sequence number printing interval
    if nseq >= 1000
        log_delta = 100;
    elseif nseq >= 500
        log_delta = 50;
    elseif nseq >= 200
        log_delta = 20;
    elseif nseq >= 100
        log_delta = 10;
    else
        log_delta = 5;
    end

    %%
    function prepare_seq(idx)
        if ~isempty(seqlist{idx})
            return;
        elseif length(arglist{idx}) == 1 && isnumeric(arglist{idx}{1})
            arg0 = arglist{idx}{1};
            prev_idx = get(seq_map, arg0);
            if ~isempty(prev_idx)
                seqlist{idx} = seqlist{prev_idx};
                return;
            end
            put(seq_map, arg0, idx);
        end
        disabler = ExpSeq.disable(true);
        if is_scangroup
            s = ExpSeq(getseq(scangroup, arg0));
            remove(all_scan_index, arg0);
            clear_accessed(s.C);
            func(s);
            if use_scan_tracker
                record_access(scan_tracker, arg0, get_accessed(s.C));
                if isEmpty(all_scan_index)
                    force_check(scan_tracker);
                end
            end
            seqlist{idx} = s;
        else
            seqlist{idx} = func(arglist{idx}{:});
        end
        delete(disabler);
        seqlist{idx}.generate();
    end

    function run_cb(cbs, idx)
        if isempty(cbs)
            return;
        end
        arg = arglist{idx};
        for cb = cbs
            cb{:}(length(params), arg);
        end
    end

    %%
    prev_date = '';
    function log_run(idx)
        if mod(m.Data(1).CurrentSeqNum, log_delta) == 0
            fprintf(' %d', m.Data(1).CurrentSeqNum);
        end
        if mod(m.Data(1).CurrentSeqNum, 15 * log_delta) == 0
            t = now();
            date = datestr(t, 'yyyy/mm/dd');
            time = datestr(t, 'HH:MM:SS');
            if ~strcmp(date, prev_date)
                fprintf('\n%s %s', date, time);
                prev_date = date;
            else
                fprintf('\n%s', time);
            end
        end
        if has_ret
            params{end + 1} = arglist{idx};
        end
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
        if tstartwait > 0
            % This wait could be used to workaround bug in the NI DAQ
            % driver causing a timing error in the NI DAQ output.
            pause(tstartwait);
        end
        run_cb(pre_cb, idx);
        cur_seq = seqlist{idx};
        start_t = now() * 86400;
        run_real(cur_seq);
        if next_idx > 0
            prepare_seq(next_idx);
        end
        m.Data(1).CurrentSeqNum = m.Data(1).CurrentSeqNum + 1;
        % We'll wait until this time before returning to the caller
        end_after = start_t + totalTime(cur_seq) - 5e-3;
        waitFinish(cur_seq);
        end_t = now() * 86400;
        if end_t < end_after
            pause(end_after - end_t);
        end
        run_cb(post_cb, idx);
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
