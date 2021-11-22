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

classdef (Sealed) TimeStep < TimeSeq
    %% `TimeStep`s are leaf nodes in the experiment sequence (tree/DAG).
    % Since this cannot contain any subsequences or child steps, the only
    % time step specific API provided is adding output to the step.
    % See `TimeSeq` for the general structure of the sequence.

    properties
        % Pulses indexed by the channel ID.
        % Each pulse span the whole time of the time step.
        % Pre-allocated to minimize resizing.
        pulses = {[], [], [], [], [], [], [], []};
        % The length of the step
        len;
        % The length without accounting for the condition
        rawLen;
    end

    methods
        function self = TimeStep(parent, start_time, len, cond)
            % These fields are in `TimeSeq`.
            % However, they are not initialized in `TimeSeq` constructor
            % to isolate the handling of `ExpSeqBase` subclasses
            % and to reduce function call overhead...
            % `len` is in sequence time unit (scaled from user input)
            self.is_step = true;
            self.parent = parent;
            self.tOffset = start_time;
            self.config = parent.config;
            self.topLevel = parent.topLevel;
            self.root = parent.root;
            self.rawLen = len;
            self.cond = cond;
            self.len = ifelse(self.cond, len, 0);
            ns = parent.nSubSeqs + 1;
            parent.nSubSeqs = ns;
            if ns > length(parent.subSeqs)
                parent.subSeqs{round(ns * 1.3) + 8} = [];
            end
            parent.subSeqs{ns} = self;
            while ~parent.latest_seq
                parent.totallen_after_parent = true;
                parent.latest_seq = true;
                parent = parent.parent;
                if isempty(parent)
                    break;
                end
            end
        end

        function self = add(self, cid, pulse)
            %% Add a pulse on a channel to the step.
            % The input channel ID can be provided as a string, which will be
            % translated and converted to the channel ID, or it can be
            % given as the channel ID (number) directly. (See `TimeSeq::translateChannel`)
            % The pulse can be
            %
            % * A value (constant or variable)
            %
            %     Output the value at the beginning of the step.
            %
            % * A subclass of `IRPulse` (deprecated)
            %
            %     The `calcValue` method will be used to compute the output value.
            %
            % * Or an arbitrary callable object/function handle.
            %
            %     The object will be called to compute the output value.
            toplevel = self.topLevel;
            if ~isnumeric(cid)
                % Even if a pulse is disabled, we still want to make sure
                % that the channel is used and so it is initialized.
                % Do not skip based on cond before this point.
                cid = translateChannel(toplevel, cid);
            end
            cond = self.cond;
            if islogical(cond) && ~cond
                % If the pulse is disabled, no need to do anything else.
                return;
            end
            if cid > length(self.pulses)
                % Minimize resizing
                self.pulses{cid + 5} = [];
            end
            ctx = toplevel.seq_ctx;
            if isnumeric(pulse) || islogical(pulse)
                if ~isscalar(pulse)
                    error('Pulse cannot be a non-scalar value.');
                end
                pulse = double(pulse);
            elseif isa(pulse, 'SeqVal')
                % pass through
            elseif isa(pulse, 'IRPulse')
                pulse = calcValue(pulse, ctx.arg0 / toplevel.time_scale, ...
                                  self.rawLen / toplevel.time_scale, ctx.arg1);
            else
                % Treat as function/callable
                narg = nargin(pulse);
                if narg == 1
                    pulse = pulse(ctx.arg0 / toplevel.time_scale);
                elseif narg == 2
                    pulse = pulse(ctx.arg0 / toplevel.time_scale, ...
                                  self.rawLen / toplevel.time_scale);
                else
                    pulse = pulse(ctx.arg0 / toplevel.time_scale, ...
                                  self.rawLen / toplevel.time_scale, ctx.arg1);
                end
            end
            % Inlined implementation of `SeqContext::nextObjID` for hot path
            id = ctx.obj_counter;
            ctx.obj_counter = id + uint32(1);
            if ctx.collect_dbg_info
                ctx.obj_backtrace{id + 1} = dbstack('-completenames', 1);
            end
            self.pulses{cid} = Pulse(id, pulse, cond);
        end

        function self = addConditional(self, cid, pulse, cond)
            % This is very similar to `TimeStep::add` but creating
            % a common function to call adds measureable overhead in MATLAB...
            %% Add a pulse on a channel to the step.
            % The input channel ID can be provided as a string, which will be
            % translated and converted to the channel ID, or it can be
            % given as the channel ID (number) directly. (See `TimeSeq::translateChannel`)
            % The pulse can be
            %
            % * A value (constant or variable)
            %
            %     Output the value at the beginning of the step.
            %
            % * A subclass of `IRPulse` (deprecated)
            %
            %     The `calcValue` method will be used to compute the output value.
            %
            % * Or an arbitrary callable object/function handle.
            %
            %     The object will be called to compute the output value.
            if isnumeric(cond)
                cond = cond ~= 0;
            end
            toplevel = self.topLevel;
            if ~isnumeric(cid)
                cid = translateChannel(toplevel, cid);
            end
            cond = self.cond & cond;
            if islogical(cond) && ~cond
                % If the pulse is disabled, no need to do anything else.
                return;
            end
            if cid > length(self.pulses)
                % Minimize resizing
                self.pulses{cid + 5} = [];
            end
            ctx = toplevel.seq_ctx;
            if isnumeric(pulse) || islogical(pulse)
                if ~isscalar(pulse)
                    error('Pulse cannot be a non-scalar value.');
                end
                pulse = double(pulse);
            elseif isa(pulse, 'SeqVal')
                % pass through
            elseif isa(pulse, 'IRPulse')
                pulse = calcValue(pulse, ctx.arg0 / toplevel.time_scale, ...
                                  self.rawLen / toplevel.time_scale, ctx.arg1);
            else
                % Treat as function/callable
                narg = nargin(pulse);
                if narg == 1
                    pulse = pulse(ctx.arg0 / toplevel.time_scale);
                elseif narg == 2
                    pulse = pulse(ctx.arg0 / toplevel.time_scale, ...
                                  self.rawLen / toplevel.time_scale);
                else
                    pulse = pulse(ctx.arg0 / toplevel.time_scale, ...
                                  self.rawLen / toplevel.time_scale, ctx.arg1);
                end
            end
            % Inlined implementation of `SeqContext::nextObjID` for hot path
            id = ctx.obj_counter;
            ctx.obj_counter = id + uint32(1);
            if ctx.collect_dbg_info
                ctx.obj_backtrace{id + 1} = dbstack('-completenames', 1);
            end
            self.pulses{cid} = Pulse(id, pulse, cond);
        end

        function res = totalTime(self)
            res = self.len / self.topLevel.time_scale;
        end

        function sign = lengthSign(self)
            if islogical(self.cond) && self.cond
                sign = SeqTime.Pos;
            else
                sign = SeqTime.NonNeg;
            end
        end

        function res = toString(self, indent)
            if ~exist('indent', 'var')
                indent = 0;
            end
            prefix = repmat(' ', 1, indent);
            prefix2 = repmat(' ', 1, indent + 2);
            if islogical(self.cond) && self.cond
                res = [prefix 'Step(len=' SeqVal.toString(self.rawLen) ')'];
            else
                res = [prefix 'Step(len=' SeqVal.toString(self.rawLen) ', cond=' ...
                              SeqVal.toString(self.cond) ')'];
            end
            res = [res ' @ ' toString(self.tOffset)];
            pulses = self.pulses;
            for i = 1:length(pulses)
                pulse = pulses{i};
                if isempty(pulse)
                    continue;
                end
                res = [res char(10) prefix2 ...
                           sprintf('chn%d(%s): ', i, channelName(self.topLevel, i)) ...
                           toString(pulse)];
            end
        end
    end
end
