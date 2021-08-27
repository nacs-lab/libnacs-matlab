% Copyright (c) 2021-2021, Yichao Yu <yyc1992@gmail.com>
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

classdef RootSeq < ExpSeqBase
    %% `RootSeq` is the object representing part of an experimental sequence
    % without control flow (root node).
    % This may be a top level sequence or a basic sequence.
    properties(Access=protected)
        bseq_id;
        assigns = struct('val', {}, 'id', {});
        norders = 0;
        orders = {};
        default_target = [];
        branches = struct('cond', {}, 'target', {}, 'id', {});

        time_serialized = {};

        %% Basic sequence callbacks
        before_bseq_cbs = {};
        after_bseq_cbs = {};
        after_branch_cbs = {};
    end
    properties(Hidden)
        zero_time;
        measures = struct('time', {}, 'chn', {}, 'id', {});
    end

    methods
        function assignGlobal(self, g, val)
            assert(isa(g, 'SeqVal') && g.head == SeqVal.HGlobal);
            id = nextObjID(self.topLevel.seq_ctx);
            self.assigns(g.args{1} + 1) = struct('val', val, 'id', id);
        end

        function condBranch(self, cond, target)
            checkBranchTarget(self, target);
            id = nextObjID(self.topLevel.seq_ctx);
            self.branches(end + 1) = struct('cond', cond, 'target', target, 'id', id);
        end

        function defaultBranch(self, target)
            checkBranchTarget(self, target);
            self.default_target = target;
        end

        function time_id = getTimeID(self, time)
            time_id = time.time_id;
            if time_id ~= 0
                return;
            end
            parent = time.parent;
            if ~isempty(parent)
                prev_id = getTimeID(self, parent);
            else
                seq = time.seq;
                if ~isempty(seq.parent)
                    prev_id = getTimeID(self, seq.tOffset);
                else
                    prev_id = uint32(0);
                end
            end
            time_id = uint32(length(self.time_serialized) + 1);
            time.time_id = time_id;
            term_id = uint32(getValID(self.topLevel.seq_ctx, time.term));
            % [sign: 1B][id: 4B][delta_node: 4B][prev_id: 4B]
            self.time_serialized{time_id} = [int8(time.sign), ...
                                             typecast(uint32(time.id), 'int8'), ...
                                             typecast(term_id, 'int8'), ...
                                             typecast(prev_id, 'int8')];
        end

        function res = toString(self, indent)
            if ~exist('indent', 'var')
                indent = 0;
            end
            prefix = repmat(' ', 1, indent);
            res = [prefix sprintf('BS%d:\n', self.bseq_id)];
            if ~isempty(self.assigns)
                res = [res prefix '  Assigns:' char(10)];
                for i = 1:length(self.assigns)
                    assign = self.assigns(i).val;
                    if isempty(assign)
                        continue;
                    end
                    res = [res prefix sprintf('    g(%d) = ', i) ...
                               SeqVal.toString(assign) char(10)];
                end
            end
            if self.norders ~= 0
                res = [res prefix '  Time orders:' char(10)];
                for i = 1:self.norders
                    order = self.orders{i};
                    if order{2} == SeqTime.Pos
                        op = ' < ';
                    else
                        op = ' <= ';
                    end
                    res = [res prefix '    ' toString(order{3}) op ...
                               toString(order{4}) char(10)];
                end
            end
            res = [res prefix '  Branches:' char(10)];
            for i = 1:length(self.branches)
                br = self.branches(i);
                if isempty(br.target)
                    target = 'end';
                else
                    target = sprintf('BS%d', br.target.bseq_id);
                end
                res = [res prefix '    ' SeqVal.toString(br.cond) ': ' target char(10)];
            end
            if isempty(self.default_target)
                target = 'end';
            else
                target = sprintf('BS%d', self.default_target.bseq_id);
            end
            res = [res prefix '    default: ' target char(10)];
            res = [res toString@ExpSeqBase(self, indent + 2)];
        end

        function self = regBeforeBSeq(self, cb)
            %% Register a callback function that will be executed before
            % the basic sequence runs.
            % The callbacks will be called in the order they are registerred
            % with the sequence as the argument.
            self.before_bseq_cbs{end + 1} = cb;
        end

        function self = regAfterBSeq(self, cb)
            %% Register a callback function that will be executed after
            % the basic sequence ends.
            % The callbacks will be called in the order they are registerred
            % with the sequence as the argument.
            self.after_bseq_cbs{end + 1} = cb;
        end

        function self = regAfterBranch(self, cb)
            %% Register a callback function that will be executed after
            % the branch target (including termination) has been determined.
            % This will run right before the before basic sequence callback
            % of the next sequence or the global after end callbacks
            % if the whole sequence is finished.
            % The callbacks will be called in the order they are registerred
            % with the sequence as the argument.
            self.after_branch_cbs{end + 1} = cb;
        end
    end

    methods(Access=protected)
        function checkBranchTarget(self, target)
            if ~isempty(target)
                if ~isa(target, 'RootSeq')
                    error('Only the toplevel sequence (`ExpSeq`) or other basic sequences (return values of `newBasicSeq`) are valid branch target');
                end
                if self.topLevel ~= target.topLevel
                    error('Only basic sequences in the same top level sequence are valid branch target. You should create new basic sequence with `newBasicSeq()` instead of `ExpSeq()`');
                end
            end
        end

        function t = globalPath(self)
            t = {};
        end

        function res = timeSerialized(self)
            % [ntimes: 4B][[sign: 1B][id: 4B][delta_node: 4B][prev_id: 4B] x ntimes]
            res = [typecast(uint32(length(self.time_serialized)), 'int8'), ...
                   self.time_serialized{:}];
        end

        function res = serializeBSeq(self)
            % [nendtimes: 4B][[time_id: 4B] x nendtimes]
            endtimes = collectEndTime(self, {});
            nendtimes = uint32(length(endtimes));
            endtimes_serialized = [typecast(nendtimes, 'int8'), endtimes{:}];

            % [ntimeorders: 4B][[sign: 1B][id: 4B][before_id: 4B][after_id: 4B] x ntimeorders]
            orders = self.orders;
            norders = self.norders;
            orders_serialized = cell(1, norders);
            for i = 1:norders
                order = orders{i};
                orders_serialized{i} = [int8(order{2}), typecast(uint32(order{1}), 'int8'), ...
                                        typecast(getTimeID(self, order{3}), 'int8'), ...
                                        typecast(getTimeID(self, order{4}), 'int8')];
            end
            orders_serialized = [typecast(uint32(norders), 'int8'), orders_serialized{:}];

            % [noutputs: 4B]
            % [[id: 4B][time_id: 4B][len: 4B][val: 4B][cond: 4B][chn: 4B] x noutputs]
            pulses = collectSerializedPulses(self, {});
            npulses = uint32(length(pulses));
            pulses_serialized = [typecast(npulses, 'int8'), pulses{:}];

            % [nmeasures: 4B][[id: 4B][time_id: 4B][chn: 4B] x nmeasures]
            measures = self.measures;
            nmeasures = length(measures);
            measures_serialized = cell(1, nmeasures);
            cid_map = self.topLevel.cid_map;
            for i = 1:nmeasures
                measure = measures(i);
                cid = cid_map(measure.chn);
                if cid == 0
                    continue;
                end
                measures_serialized{i} = [typecast(uint32(measure.id), 'int8'), ...
                                          typecast(getTimeID(self, measure.time), 'int8'), ...
                                          typecast(cid, 'int8')];
            end
            measures_serialized = [typecast(uint32(nmeasures), 'int8'), ...
                                   measures_serialized{:}];

            seq_ctx = self.topLevel.seq_ctx;
            % [nassigns: 4B][[assign_id: 4B][global_id: 4B][val: 4B] x nassigns]
            assigns = self.assigns;
            assigns_serialized = {};
            for i = 1:length(assigns)
                assign = assigns(i);
                val = assign.val;
                if isempty(val)
                    continue;
                end
                assigns_serialized{i} = [typecast(uint32(assign.id), 'int8'), ...
                                         typecast(uint32(getValID(seq_ctx, val)), 'int8'), ...
                                         typecast(uint32(assign.chn), 'int8')];
            end
            assigns_serialized = [typecast(uint32(length(assigns_serialized)), 'int8'), ...
                                  assigns_serialized{:}];

            % [nbranches: 4B][[branch_id: 4B][target_id: 4B][cond: 4B] x nbranches]
            % [default_target: 4B]
            branches = self.branches;
            nbranches = length(branches);
            branches_serialized = cell(1, nbranches);
            for i = 1:nbranches
                branch = branches{i};
                target = branch.target;
                if isempty(target)
                    target_id = uint32(0);
                else
                    target_id = uint32(target.bseq_id);
                end
                cond_id = getValID(seq_ctx, branch.cond);
                branches_serialized{i} = [typecast(uint32(branch.id), 'int8'), ...
                                          typecast(target_id, 'int8'), ...
                                          typecast(uint32(cond_id), 'int8')];
            end
            default_target = self.default_target;
            if isempty(default_target)
                default_target_id = uint32(0);
            else
                default_target_id = uint32(default_target.bseq_id);
            end
            branches_serialized = [typecast(uint32(nbranches), 'int8'), ...
                                   branches_serialized{:}, ...
                                   typecast(default_target_id, 'int8')];

            % [ntimes: 4B][[sign: 1B][id: 4B][delta_node: 4B][prev_id: 4B] x ntimes]
            % [nendtimes: 4B][[time_id: 4B] x nendtimes]
            % [ntimeorders: 4B][[sign: 1B][id: 4B][before_id: 4B][after_id: 4B] x ntimeorders]
            % [noutputs: 4B]
            % [[id: 4B][time_id: 4B][len: 4B][val: 4B][cond: 4B][chn: 4B] x noutputs]
            % [nmeasures: 4B][[id: 4B][time_id: 4B][chn: 4B] x nmeasures]
            % [nassigns: 4B][[assign_id: 4B][global_id: 4B][val: 4B] x nassigns]
            % [nbranches: 4B][[branch_id: 4B][target_id: 4B][cond: 4B] x nbranches]
            % [default_target: 4B]
            res = [timeSerialized(self), endtimes_serialized, orders_serialized, ...
                   pulses_serialized, measures_serialized, assigns_serialized, ...
                   branches_serialized];
        end

        function releaseGeneration(self)
            releaseGeneration@ExpSeqBase(self);
            self.assigns = [];
            self.orders = [];
            self.branches = [];
            self.time_serialized = [];
            self.measures = [];
        end
    end

    methods(Access=?TimeSeq)
        function addOrder(self, sign, before, after)
            norders = self.norders + 1;
            self.norders = norders;
            if norders > length(self.orders)
                self.orders{round(norders * 1.3) + 8} = [];
            end
            id = nextObjID(self.topLevel.seq_ctx);
            order = {id, sign, before, after};
            self.orders{norders} = order;
        end
        function addEqual(self, time1, time2)
            addOrder(self, SeqTime.NonNeg, time1, time2);
            addOrder(self, SeqTime.NonNeg, time2, time1);
        end
    end
end
