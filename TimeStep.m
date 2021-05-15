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
    end

    methods
        function self = TimeStep(parent, start_time, len)
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
            self.len = len;
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
            % * A subclass of `PulseBase` (deprecated)
            %
            %     The `calcValue` method will be used to compute the output value.
            %
            % * Or an arbitrary callable object/function handle.
            %
            %     The object will be called to compute the output value.
            toplevel = self.topLevel;
            if ~isnumeric(cid)
                cid = translateChannel(toplevel, cid);
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
            elseif isa(pulse, 'PulseBase')
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
            ctx.obj_counter = id + 1;
            if ctx.collect_dbg_info
                ctx.obj_backtrace{id + 1} = dbstack('-completenames', 1);
            end
            self.pulses{cid} = Pulse(id, pulse, true);
        end

        function res = totalTime(self)
            res = self.len / self.topLevel.time_scale;
        end
    end
end
