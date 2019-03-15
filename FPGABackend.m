%% Copyright (c) 2014-2018, Yichao Yu <yyc1992@gmail.com>
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

classdef FPGABackend < PulseBackend
    % Contains everything related to the FPGA.
    properties(Hidden)
        % PulseBackend properties: seq
        clock_div = 0;
        poster; % ::FPGAPoster
        req = [];
        type_cache = [];
        num_cache = [];
        clock_period_tik = [];
    end

    properties(Constant, Hidden, Access=private)
        TTL_CHN = 1;
        DDS_FREQ = 2;
        DDS_AMP = 3;
        DAC_CHN = 4;

        START_TRIGGER_TTL = 0;

        % The delay is needed for the software radio.
        SEQ_DELAY = 10e-3;
    end

    methods
        function self = FPGABackend(seq)
            self = self@PulseBackend(seq);
            % The FPGA poster is stateless so it is shared between all `FPGABackend`s
            self.poster = FPGAPoster.get(seq.config.fpgaUrls('FPGA1'));
        end

        function initDev(self, did)
            if ~strcmp('FPGA1', did)
                error('Unknown FPGA device "%s".', did);
            end
        end

        function initChannel(self, cid)
            if length(self.type_cache) >= cid && self.type_cache(cid) > 0
                return;
            end
            name = channelName(self.seq, cid);
            if ~strncmp('FPGA1/', name, 5)
                error('Unknown channel name "%s"', name);
            end
            name = name(7:end);
            [chn_type, chn_num] = parseCId(self, name);
            self.type_cache(cid) = chn_type;
            self.num_cache(cid) = chn_num;
        end

        function enableClockOut(self, div, clock_period_tik)
            if div < 0 || div > 254
                error('Clock divider out of range.');
            end
            self.clock_div = div;
            self.clock_period_tik = clock_period_tik;
        end

        %%
        % Generate data for the FPGA. Called by `ExpSeq::generate` method.
        % We currently do this by first serializing the sequence (see format below)
        % including the timing info and serialized ramp functions using `IRFunc`.
        % The sequence is then scheduled by `libnacs-seq` (called through python)
        % to the bytecode that we execute on the FPGA directly.
        % We want to do as much processing as possible in this function so we convert
        % the sequence all the way to the ZMQ request that we'll send to the FPGA board
        % and cache it in `req`.
        function generate(self, cids)
            %% Sequence serialization format.
            % [TTL default: 4B]
            % [n_non_ttl: 4B]
            % [[[chn_type: 4B][chn_id: 4B][defaults: 8B]] x n_non_ttl]
            % [n_pulses: 4B]
            % [[[chn_type: 4B][chn_id: 4B][t_start: 8B][t_len: 8B]
            %  [[0: 4B][val: 8B] / [code_len: 4B][code: code_len x 4B]]] x n_pulses]
            % Optional:
            % [[n_clocks: 4B][[[t_start_ns: 8B][t_len_ns: 8B][clock_div: 4B]] x n_clocks]]
            ir_ctx = self.seq.ir_ctx;

            TTL_CHN = self.TTL_CHN;
            SEQ_DELAY = self.SEQ_DELAY;
            ircache = IRCache.get();

            type_cache = self.type_cache;
            num_cache = self.num_cache;
            nchn = length(cids);
            ttl_values = uint32(0);
            for i = 1:nchn
                cid = cids(i);
                if type_cache(cid) ~= self.TTL_CHN
                    continue;
                end
                ttl_values = bitset(ttl_values, num_cache(cid) + 1, getDefault(self.seq, cid));
            end

            n_non_ttl = 0;
            n_pulses = 0;

            % Channel count
            for i = 1:nchn
                cid = cids(i);
                pulses = getPulses(self.seq, cid);
                all_pulses{i} = pulses;
                np = size(pulses, 1);
                if np == 0
                    continue;
                end
                chn_type = type_cache(cid);
                if chn_type ~= TTL_CHN
                    n_non_ttl = n_non_ttl + 1;
                end
            end

            code = [int32(ttl_values), int32(n_non_ttl)];

            % Default values
            for i = 1:nchn
                cid = cids(i);
                chn_type = type_cache(cid);
                if chn_type == TTL_CHN
                    continue;
                end
                pulses = all_pulses{i};
                if size(pulses, 1) == 0
                    continue;
                end
                chn_num = num_cache(cid);
                code = [code, chn_type, chn_num, ...
                        typecast(double(getDefault(self.seq, cid)), 'int32')];
            end
            code = [code, 0];
            n_pulses_idx = length(code);
            targ = IRNode.getArg(1, ir_ctx);
            oldarg = IRNode.getArg(2, ir_ctx);

            % Serialize all pulses
            for i = 1:nchn
                cid = cids(i);
                chn_type = type_cache(cid);
                chn_num = num_cache(cid);
                pulses = all_pulses{i};

                for j = 1:size(pulses, 1)
                    pulse_obj = pulses{j, 3};
                    t_start = pulses{j, 1} + SEQ_DELAY;
                    nc = length(code);
                    if isnumeric(pulse_obj) || islogical(pulse_obj)
                        val = pulse_obj;
                        n_pulses = n_pulses + 1;
                        code(nc + 8:nc + 9) = typecast(double(val), 'int32');
                        code(nc + 1) = chn_type;
                        code(nc + 2) = chn_num;
                        code(nc + 3:nc + 4) = typecast(double(t_start), 'int32');
                        continue;
                    end
                    step_len = pulses{j, 2};
                    if chn_type == TTL_CHN
                        error('Function pulse not allowed on TTL channel');
                    end
                    n_pulses = n_pulses + 1;
                    code(nc + 5:nc + 6) = typecast(double(step_len), 'int32');
                    code(nc + 1) = chn_type;
                    code(nc + 2) = chn_num;
                    code(nc + 3:nc + 4) = typecast(double(t_start), 'int32');
                    isir = 0;
                    if isa(pulse_obj, 'IRPulse')
                        irpulse_id = sprintf('%s::%d', pulse_obj.id, ...
                                             typecast(double(step_len), 'int64'));
                        ir = getindex(ircache, irpulse_id);
                        if ~isempty(ir)
                            code(end + 1:end + length(ir)) = ir;
                            continue;
                        end
                        isir = 1;
                    end
                    val = calcValue(pulse_obj, targ, step_len, oldarg);
                    if isnumeric(val) || islogical(val)
                        code = [code, 0, typecast(double(val), 'int32')];
                    else
                        if chn_type == TTL_CHN
                            error('Function pulse not allowed on TTL channel');
                        end
                        func = IRFunc(IRNode.TyFloat64, [IRNode.TyFloat64, IRNode.TyFloat64]);
                        func.setCode(val);
                        ser = func.serialize();
                        ir = [length(ser), ser];
                        code(end + 1:end + length(ir)) = ir;
                        if isir
                            setindex(ircache, ir, irpulse_id);
                        end
                    end
                end
            end
            % Serialize clock
            clock_offset_ns = int64(SEQ_DELAY / 1e-9);
            clock_period_tik = self.clock_period_tik;
            clock_ns = self.clock_div * 20;
            clock_div = int32(self.clock_div);
            nclocks = size(clock_period_tik, 2);
            code = [code, int32(nclocks)];
            for clock_i = 1:nclocks
                tik_start = clock_period_tik(1, clock_i);
                tik_end = clock_period_tik(2, clock_i);
                t_start_ns = int64(tik_start) * clock_ns + clock_offset_ns;
                t_len_ns = int64((tik_end - tik_start)) * clock_ns;
                code = [code, typecast(t_start_ns, 'int32'), ...
                        typecast(t_len_ns, 'int32'), clock_div];
            end
            code(n_pulses_idx) = n_pulses;
            self.req = prepare_msg(self.poster, totalTime(self.seq) * 1e9, code);
        end

        function run(self)
            post(self.poster, self.req);
        end

        function wait(self)
            wait(self.poster);
        end
    end

    methods(Access=private)
        function [chn_type, chn_num] = parseCId(self, cid)
            %% Parse the channel name (`/` separated names)
            % to channel type and channel number.
            cpath = strsplit(cid, '/');
            if strncmp(cpath{1}, 'TTL', 3)
                chn_type = self.TTL_CHN;
                if size(cpath, 2) ~= 1
                    error('Invalid TTL channel id "%s".', cid);
                end
                matches = regexp(cpath{1}, '^TTL([1-9]\d*|0)$', 'tokens');
                if isempty(matches)
                    error('No TTL channel number');
                end
                chn_num = str2double(matches{1}{1});
                if ~isfinite(chn_num) || chn_num < 0 || chn_num > 28 || ...
                   mod(chn_num, 4) == 0
                    error('Unconnected TTL channel %d.', chn_num);
                elseif chn_num == self.START_TRIGGER_TTL
                    error('Channel conflict with start trigger');
                end
            elseif strncmp(cpath{1}, 'DAC', 3)
                chn_type = self.DAC_CHN;
                if size(cpath, 2) ~= 1
                    error('Invalid DAC channel id "%s".', cid);
                end
                matches = regexp(cpath{1}, '^DAC([1-9]\d*|0)$', 'tokens');
                if isempty(matches)
                    error('No DAC channel number');
                end
                chn_num = str2double(matches{1}{1});
                if ~isfinite(chn_num) || chn_num < 0 || chn_num >= 4
                    error('Unconnected DAC channel %d.', chn_num);
                end
            elseif strncmp(cpath{1}, 'DDS', 3)
                if size(cpath, 2) ~= 2
                    error('Invalid DDS channel id "%s".', cid);
                end
                matches = regexp(cpath{1}, '^DDS([1-9]\d*|0)$', 'tokens');
                if isempty(matches)
                    error('No DDS channel number');
                end
                chn_num = str2double(matches{1}{1});
                if ~isfinite(chn_num) || chn_num < 0 || chn_num > 22
                    error('DDS channel number %d out of range.', chn_num);
                end
                if strcmp(cpath{2}, 'FREQ')
                    chn_type = self.DDS_FREQ;
                elseif strcmp(cpath{2}, 'AMP')
                    chn_type = self.DDS_AMP;
                else
                    error('Invalid DDS parameter name "%s".', cpath{2});
                end
            else
                error('Unknown channel type "%s"', cpath{1});
            end
        end
    end
end
