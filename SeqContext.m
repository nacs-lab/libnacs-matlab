%% Copyright (c) 2019-2021, Yichao Yu <yyc1992@gmail.com>
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

classdef SeqContext < handle
    % NodeArg:
    %   Node ID:
    %     1-based index into the node array. (for use in sequence) use `-1` for invalid ID.
    %   Global slot ID: 0-based index into the slot types array.
    %   Measure ID: globally unique ID
    %   Arg: 0-based index of argument
    % Data ID: 0-based index into the data array
    % Channel ID: 1-based index into the channel name array
    % Time ID: 1-based index into the time array
    % Basic Sequence ID: 1-based index into the bseq array. 0 means end of sequence.

    % Format:
    %   [version <0>: 1B]
    %   [nnodes: 4B]
    %   [[[OpCode: 1B][[ArgType: 1B][NodeArg: 1-8B] x narg] /
    %     [OpCode <Interp>: 1B][[ArgType: 1B][NodeArg: 1-8B] x 3][data_id: 4B]] x nnodes]
    %   [nchns: 4B][[chnname: non-empty NUL-terminated string] x nchns]
    %   [ndefvals: 4B][[chnid: 4B][Type: 1B][value: 1-8B] x ndefvals]
    %   [nslots: 4B][[Type: 1B] x nslots]
    %   [nnoramp: 4B][[chnid: 4B] x nnoramp]
    %   [nbasicseqs: 4B][[Basic Sequence] x nbasicseqs]
    %   [ndatas: 4B][[ndouble: 4B][data: 8B x ndouble] x ndatas]
    %   [nbackenddatas: 4B][[device_name: NUL-terminated string]
    %                       [size: 4B][data: size B] x nbackenddatas]
    %
    % Basic Sequence format:
    %   [ntimes: 4B][[sign: 1B][id: 4B][delta_node: 4B][prev_id: 4B] x ntimes]
    %   [nendtimes: 4B][[time_id: 4B] x nendtimes]
    %   [ntimeorders: 4B][[sign: 1B][id: 4B][before_id: 4B][after_id: 4B] x ntimeorders]
    %   [noutputs: 4B][[id: 4B][time_id: 4B][len: 4B][val: 4B][cond: 4B][chn: 4B] x noutputs]
    %   [nmeasures: 4B][[id: 4B][time_id: 4B][chn: 4B] x nmeasures]
    %   [nassigns: 4B][[assign_id: 4B][global_id: 4B][val: 4B] x nassigns]
    %   [nbranches: 4B][[branch_id: 4B][target_id: 4B][cond: 4B] x nbranches]
    %   [default_target: 4B]

    properties(Access=private)
        % For creating/managing `SeqVal`s
        arg_vals = SeqVal.empty();
        global_types = int8([]);

        % For node (i.e. `SeqVal` serialization)
        node_serialized = {};
        datas = {};
        data_ids;
        const_b_ids = uint32([0, 0]);
        const_f64_ids;
        const_i32_ids;
    end

    properties(Hidden)
        % For sorting sequence objects
        obj_counter = uint32(0);

        collect_dbg_info = false;
        obj_backtrace = {};
        arg0;
        arg1;
    end

    properties(Constant, Access=private)
        arg_prefix = [SeqVal.OPIdentity, SeqVal.ArgArg];
        measure_prefix = [SeqVal.OPIdentity, SeqVal.ArgMeasure];
        global_prefix = [SeqVal.OPIdentity, SeqVal.ArgGlobal];
        const_b_prefix = [SeqVal.OPIdentity, SeqVal.ArgConstBool];
        const_i32_prefix = [SeqVal.OPIdentity, SeqVal.ArgConstInt32];
        const_f64_prefix = [SeqVal.OPIdentity, SeqVal.ArgConstFloat64];
    end

    methods(Access=?SeqVal)
        function id = getDataID(self, data)
            data = double(data);
            data_key = num2hex(data);
            data_key = reshape(data_key, 1, numel(data_key));
            if isKey(self.data_ids, data_key)
                id = self.data_ids(data_key);
                return;
            end
            id = uint32(length(self.datas));
            self.datas{id + 1} = data;
            self.data_ids(data_key) = id;
        end
        function res = serializeArg(self, res, arg)
            if isfloat(arg)
                assert(isscalar(arg));
                res = [res, SeqVal.ArgConstFloat64, typecast(double(arg), 'int8')];
            elseif isa(arg, 'SeqVal')
                head = arg.head;
                if head == SeqVal.HArg
                    res = [res, SeqVal.ArgArg, typecast(uint32(arg.args{1}), 'int8')];
                    return;
                elseif head == SeqVal.HMeasure
                    res = [res, SeqVal.ArgMeasure, typecast(arg.args{1}, 'int8')];
                    return;
                elseif head == SeqVal.HGlobal
                    res = [res, SeqVal.ArgGlobal, typecast(uint32(arg.args{1}), 'int8')];
                    return;
                end
                node_id = arg.node_id;
                if node_id == 0
                    ensureSerialize(self, arg);
                    node_id = arg.node_id;
                end
                res = [res, SeqVal.ArgNode, typecast(node_id, 'int8')];
            elseif islogical(arg)
                assert(isscalar(arg));
                res = [res, SeqVal.ArgConstBool, int8(arg)];
            elseif isinteger(arg)
                assert(isscalar(arg));
                res = [res, SeqVal.ArgConstInt32, typecast(int32(arg), 'int8')];
            else
                error('Argument with unknown type.');
            end
        end
        function ensureSerialize(self, val)
            % Assume node ID wasn't assigned.
            head = val.head;
            if head == SeqVal.HArg
                argi = val.args{1};
                node_id = length(self.node_serialized) + 1;
                val.node_id = uint32(node_id);
                serial = [SeqContext.arg_prefix, typecast(uint32(argi), 'int8')];
                self.node_serialized{node_id} = serial;
            elseif head == SeqVal.HMeasure
                measure_id = val.args{1};
                node_id = length(self.node_serialized) + 1;
                val.node_id = uint32(node_id);
                serial = [SeqContext.measure_prefix, typecast(measure_id, 'int8')];
                self.node_serialized{node_id} = serial;
            elseif head == SeqVal.HGlobal
                global_id = val.args{1};
                node_id = length(self.node_serialized) + 1;
                val.node_id = uint32(node_id);
                serial = [SeqContext.global_prefix, typecast(uint32(global_id), 'int8')];
                self.node_serialized{node_id} = serial;
            elseif head == SeqVal.OPInterp
                serial = head;
                for i = 1:3
                    arg = val.args{i};
                    serial = serializeArg(self, serial, arg);
                end
                serial = [serial, typecast(getDataID(self, val.args{4}), 'int8')];
                node_id = length(self.node_serialized) + 1;
                val.node_id = uint32(node_id);
                self.node_serialized{node_id} = serial;
            else
                serial = head;
                for arg = val.args
                    serial = serializeArg(self, serial, arg{:});
                end
                node_id = length(self.node_serialized) + 1;
                val.node_id = uint32(node_id);
                self.node_serialized{node_id} = serial;
            end
        end
    end
    methods
        function self = SeqContext()
            self.data_ids = containers.Map('KeyType', 'char', 'ValueType', 'uint32');
            self.const_f64_ids = java.util.Hashtable();
            self.const_i32_ids = java.util.Hashtable();
            % Optimized for usage in the sequence
            self.arg0 = getArg(self, 0);
            self.arg1 = getArg(self, 1);
        end
        function res = nextObjID(self)
            res = self.obj_counter;
            self.obj_counter = res + uint32(1);
            if self.collect_dbg_info
                self.obj_backtrace{res + 1} = dbstack('-completenames', 1);
            end
        end
        function res = getArg(self, i)
            % 0-based input
            fillArgs(self, i + 1);
            res = self.arg_vals(i + 1);
        end
        function [res, id] = newMeasure(self)
            id = nextObjID(self);
            res = SeqVal(SeqVal.HMeasure, {id}, self);
        end
        function [res, id] = newGlobal(self, type)
            assert(type == SeqVal.TypeBool || type == SeqVal.TypeInt32 || ...
                   type == SeqVal.TypeFloat64);
            % 0-based ID
            id = length(self.global_types);
            res = SeqVal(SeqVal.HGlobal, {id}, self);
            self.global_types(id + 1) = type;
        end
        function res = nodeSerialized(self)
            res = cat(2, typecast(uint32(length(self.node_serialized)), 'int8'), ...
                      self.node_serialized{:});
        end
        function res = globalSerialized(self)
            res = [typecast(uint32(length(self.global_types)), 'int8'), self.global_types];
        end
        function res = dataSerialized(self)
            ndata = length(self.datas);
            res = typecast(uint32(ndata), 'int8');
            for i = 1:ndata
                data = self.datas{i};
                res = [res, typecast(uint32(length(data)), 'int8'), typecast(data, 'int8')];
            end
        end
        function res = getValID(self, val)
            if isfloat(val)
                assert(isscalar(val));
                val = double(val);
                const_f64_ids = self.const_f64_ids;
                val_id = get(const_f64_ids, val);
                if isempty(val_id)
                    val_id = length(self.node_serialized) + 1;
                    put(const_f64_ids, val, val_id);
                    serial = [SeqContext.const_f64_prefix, typecast(val, 'int8')];
                    self.node_serialized{val_id} = serial;
                end
                res = uint32(val_id);
            elseif isa(val, 'SeqVal')
                if val.node_id == 0
                    ensureSerialize(self, val);
                end
                res = val.node_id;
            elseif islogical(val)
                assert(isscalar(val));
                val = int8(val);
                res = self.const_b_ids(val);
                if res ~= 0
                    return;
                end
                val_id = length(self.node_serialized) + 1;
                self.const_b_ids(val) = val_id;
                serial = [SeqContext.const_b_prefix, val];
                self.node_serialized{val_id} = serial;
                res = uint32(val_id);
            elseif isinteger(val)
                assert(isscalar(val));
                val = int32(val);
                const_i32_ids = self.const_i32_ids;
                val_id = get(const_i32_ids, val);
                if isempty(val_id)
                    val_id = length(self.node_serialized) + 1;
                    put(const_i32_ids, val, val_id);
                    serial = [SeqContext.const_i32_prefix, typecast(val, 'int8')];
                    self.node_serialized{val_id} = serial;
                end
                res = uint32(val_id);
            else
                error('Value with unknown type.');
            end
        end
    end
    methods(Access=private)
        function fillArgs(self, nargs)
            old_nargs = length(self.arg_vals);
            if nargs <= old_nargs
                return;
            end
            % Resizing to final value cause matlab to try to construct SeqVal
            % without argument and will error in the constructor.
            for i = (old_nargs + 1):nargs
                self.arg_vals(i) = SeqVal(SeqVal.HArg, {i - 1}, self);
            end
        end
    end
end
