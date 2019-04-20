%% Copyright (c) 2017-2017, Yichao Yu <yyc1992@gmail.com>
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

classdef USRPBackend < PulseBackend
    properties(Hidden)
        url = '';
        poster = [];
        type_cache = [];
        num_cache = [];
        code = '';
        seq_id = 0;
    end

    properties(Constant, Hidden)
        CH_AMP = 0;
        CH_FREQ = 1;
        CH_PHASE = 2;
    end

    methods
        function self = USRPBackend(seq)
            self = self@PulseBackend(seq);
            %% Hard coded for now
            self.url = seq.config.usrpUrls('USRP1');
        end

        function initDev(self, did)
            %% Hard coded for now
            if ~strcmp('USRP1', did)
                error('Unknown USRP device "%s".', did);
            end
        end

        function initChannel(self, cid)
            if length(self.type_cache) >= cid && self.type_cache(cid) > 0
                return;
            end
            name = channelName(self.seq, cid);
            if ~strncmp('USRP1/', name, 5)
                error('Unknown channel name "%s"', name);
            end
            name = name(7:end);
            [chn_type, chn_num] = parseCId(self, name);
            self.type_cache(cid) = chn_type;
            self.num_cache(cid) = chn_num;
        end

        function val = getPriority(~)
            val = 1;
        end

        function prepare(self, ~)
            %% This should enable the FPGA backend and therefore the start trigger
            findDriver(self.seq, 'FPGABackend');
        end

        function generate(self, cids)
            %% [n_pulses: 4B]
            %% [[[chn_type: 4B][chn_id: 4B][t_start: 8B][t_len: 8B]
            %%  [[0: 4B][val: 8B] / [code_len: 4B][code: code_len x 4B]]] x n_pulses]

            ir_ctx = self.seq.ir_ctx;

            CH_AMP = self.CH_AMP;
            CH_PHASE = self.CH_PHASE;

            ircache = IRCache.get();

            type_cache = self.type_cache;
            num_cache = self.num_cache;
            nchn = length(cids);
            default_values = zeros(1, nchn);

            n_pulses = 0;

            for i = 1:nchn
                cid = cids(i);
                pulses = getPulses(self.seq, cid);
                all_pulses{i} = pulses;
                np = size(pulses, 1);
                if np == 0
                    continue;
                end
                default_values(i) = getDefault(self.seq, cid);
                if type_cache(cid) == CH_AMP && default_values(i) ~= 0
                    %% We do this for two reasons:
                    %% 1. The semantics of default value would be kind of surprising since we
                    %%    do turn the channel off when it's not used in the sequence.
                    %% 2. I forgot to implement it on the other side and
                    %%    am currently too lazy to do so... ;-p.
                    %%    Fortunately it doesn't offer anything that can't be done with setting the value
                    %%    directly in the sequence.
                    error('Non-zero default amplitude not supported for USRP channels');
                end
            end

            code = int32([1, 0]);

            targ = IRNode.getArg(1, ir_ctx);
            oldarg = IRNode.getArg(2, ir_ctx);
            for i = 1:nchn
                cid = cids(i);
                chn_type = type_cache(cid);
                chn_num = num_cache(cid);
                pulses = all_pulses{i};
                for j = 1:size(pulses, 1)
                    pulse_obj = pulses{j, 3};
                    t_start = pulses{j, 1};
                    if isnumeric(pulse_obj)
                        val = pulse_obj;
                        n_pulses = n_pulses + 1;
                        code = [code, chn_type, chn_num, ...
                                typecast(double(t_start), 'int32'), ...
                                0, 0, 0, typecast(double(val), 'int32')];
                        continue;
                    end
                    if chn_type == CH_PHASE
                        error('Phase ramp not allowed.');
                    end
                    step_len = pulses{j, 2};
                    n_pulses = n_pulses + 1;
                    code = [code, chn_type, chn_num, ...
                            typecast(double(t_start), 'int32'), ...
                            typecast(double(step_len), 'int32')];
                    isir = 0;
                    if isa(pulse_obj, 'IRPulse')
                        irpulse_id = sprintf('%s::%d', pulse_obj.id, ...
                                             typecast(double(step_len), 'int64'));
                        ir = getindex(ircache, irpulse_id);
                        if ~isempty(ir)
                            code = [code, ir];
                            continue;
                        end
                        isir = 1;
                    end
                    val = calcValue(pulse_obj, targ, step_len, oldarg);
                    if isnumeric(val) || islogical(val)
                        code = [code, 0, typecast(double(val), 'int32')];
                    else
                        func = IRFunc(IRNode.TyFloat64, [IRNode.TyFloat64, IRNode.TyFloat64]);
                        func.setCode(val);
                        ser = func.serialize();
                        ir = [length(ser), ser];
                        code = [code, ir];
                        if isir
                            setindex(ircache, ir, irpulse_id);
                        end
                    end
                end
            end
            code(2) = n_pulses;
            self.code = py.bytes(typecast(code, 'int8'));
            self.poster = USRPPoster.get(self.url);
        end

        function res = getCode(self)
            res = self.code;
        end

        function run(self)
            self.seq_id = self.poster.post(self.code);
            if self.seq_id == 0
                error('USRP run failed');
            end
        end

        function wait(self)
            self.poster.wait(self.seq_id);
        end
    end

    methods(Hidden)
        function [chn_type, chn_num] = parseCId(self, cid)
            cpath = strsplit(cid, '/');
            if strncmp(cpath{1}, 'CH', 2)
                if size(cpath, 2) ~= 2
                    error('Invalid USRP channel id "%s".', cid);
                end
                matches = regexp(cpath{1}, '^CH([1-9]\d*|0)$', 'tokens');
                if isempty(matches)
                    error('No USRP channel number');
                end
                chn_num = str2double(matches{1}{1});
                if strcmp(cpath{2}, 'FREQ')
                    chn_type = self.CH_FREQ;
                elseif strcmp(cpath{2}, 'AMP')
                    chn_type = self.CH_AMP;
                elseif strcmp(cpath{2}, 'PHASE')
                    chn_type = self.CH_PHASE;
                else
                    error('Invalid USRP parameter name "%s".', cpath{2});
                end
            else
                error('Unknown channel type "%s"', cpath{1});
            end
        end
    end
end
