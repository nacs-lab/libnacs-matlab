%% Copyright (c) 2016-2016, Yichao Yu <yyc1992@gmail.com>
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

classdef IRFunc < handle
    properties
        % return_type
        ret_type;
        % number of arguments
        nargs;
        % number of slots
        nvals;
        % slot types
        valtypes = int8([]);
        % Assume there's only one BB
        code;
        byte_code;
        consts;
        const_f64_map;
        const_i32_map;
        node_map;

        float_table;
    end

    methods
        %%
        function self = IRFunc(ret_type, argtypes)
            self.ret_type = ret_type;
            nargs = length(argtypes);
            self.nargs = nargs;
            self.nvals = nargs;
            self.valtypes(1:nargs) = argtypes;
            self.code = {};
            self.consts = int32([]);
            self.const_f64_map = containers.Map('KeyType', 'double', ...
                                                'ValueType', 'double');
            self.const_i32_map = containers.Map('KeyType', 'int32', ...
                                                'ValueType', 'double');
            self.node_map = containers.Map('KeyType', 'int32', ...
                                           'ValueType', 'any');
            self.float_table = [];
        end

        %%
        function setCode(self, node)
            res_id = addNode(self, node);
            ret_code = zeros(1, 2, 'int32');
            ret_code(1) = IRNode.OPRet;
            ret_code(2) = res_id;
            self.byte_code = [self.code{:}, ret_code];
        end

        %%
        function data = serialize(self)
            sz = serializeSize(self);
            data = zeros(1, sz, 'int32');
            data(1) = self.ret_type;
            data(2) = self.nargs;
            data(3) = self.nvals;
            if mod(self.nvals, 4) ~= 0
                % Pad the valtypes array to be convertable to a `int32` array.
                self.valtypes(ceil(self.nvals / 4) * 4) = 0;
            end
            offset = 3 + ceil(self.nvals / 4);
            data(4:offset) = typecast(self.valtypes, 'int32');
            data(offset + 1) = length(self.consts) / 3;
            offset = offset + 1;
            data(offset + 1:offset + length(self.consts)) = self.consts;
            offset = offset + length(self.consts);
            data(offset + 1) = 1;
            data(offset + 2) = length(self.byte_code);
            offset = offset + 2;
            new_offset = offset + length(self.byte_code);
            data(offset + 1:new_offset) = self.byte_code;
            offset = new_offset;
            data(offset + 1) = length(self.float_table);
            offset = offset + 1;
            data(offset + 1:offset + length(self.float_table) * 2) = typecast(self.float_table, ...
                                                                              'int32');
        end
    end

    methods(Access=private)
        function sz = serializeSize(self)
            %% Size (in 4bytes) of the serialized data to minimize the reallocation
            % in serialization.
            sz = 1 + 1 + 1 + ceil(self.nvals / 4); % [ret][nargs][nvals][vals x nvals]
            sz = sz + 1 + length(self.consts); % [nconsts][consts x nconsts]
            sz = sz + 1 + 1 + length(self.byte_code); % [nbb][nword][code x nword]
            sz = sz + 1 + length(self.float_table) * 2; % [nfloat][float x nfloat]
        end

        function [id, typ] = addConst(self, v)
            %% Add a constant to the constant table.
            % use a cache to avoid duplicate.
            if isinteger(v)
                typ = IRNode.TyInt32;
                v = int32(v);
                map = self.const_i32_map;
            else
                typ = IRNode.TyFloat64;
                v = double(v);
                map = self.const_f64_map;
            end
            if isKey(map, v)
                id = map(v);
            else
                if typ == IRNode.TyFloat64
                    self.consts(end + 2:end + 3) = typecast(v, 'int32');
                else
                    self.consts(end + 3) = 0;
                    self.consts(end - 1) = v;
                end
                self.consts(end - 2) = typ;
                id = length(self.consts) / 3;
                map(v) = id;
            end
        end

        function id = addVal(self, typ)
            %% Create a slot of type `typ`
            id = self.nvals;
            self.nvals = id + 1;
            self.valtypes(id + 1) = typ;
        end

        function [id, typ] = addNode(self, node)
            %% Add an value (either an `IRNode` or a constant)
            % and return the ID
            if islogical(node)
                typ = IRNode.TyBool;
                if ~isscalar(node)
                    error('Non scalar constant');
                end
                if node
                    id = IRNode.ConstTrue;
                else
                    id = IRNode.ConstFalse;
                end
                return;
            elseif isnumeric(node)
                if ~isscalar(node)
                    error('Non scalar constant');
                end
                [id, typ] = addConst(self, node);
                id = -id - 2;
                return;
            end
            if ~isa(node, 'IRNode')
                error('Unknown node type');
            end
            head = node.head;
            args = node.args;
            if head == IRNode.HArg
                argnum = args{1};
                if argnum > self.nargs || argnum < 1
                    error('Argument ID out of range');
                end
                id = argnum - 1;
                typ = self.valtypes(argnum);
                return;
            end
            if isKey(self.node_map, node.id)
                cached = self.node_map(node.id);
                id = cached.id;
                typ = cached.typ;
                return;
            end
            if head == IRNode.OPCall
                callee = args{1};
                nargs = length(args) - 1;
                code = zeros(1, nargs + 4, 'int32');
                code(1) = IRNode.OPCall;
                code(3) = callee;
                code(4) = nargs;
                for i = 1:nargs
                    code(4 + i) = addNode(self, args{1 + i});
                end
                id = addVal(self, IRNode.TyFloat64);
                code(2) = id;
                typ = IRNode.TyFloat64;
            elseif head == IRNode.OPInterp
                code = zeros(1, 7, 'int32');
                code(1) = IRNode.OPInterp;
                code(3) = addNode(self, args{1});
                code(4) = addNode(self, args{2});
                code(5) = addNode(self, args{3});
                oldlen = length(self.float_table);
                vals = args{4};
                vlen = length(vals);
                code(6) = oldlen;
                code(7) = vlen;
                self.float_table(oldlen + 1:oldlen + vlen) = vals;
                id = addVal(self, IRNode.TyFloat64);
                code(2) = id;
                typ = IRNode.TyFloat64;
            elseif head == IRNode.OPSelect
                code = zeros(1, 5, 'int32');
                code(1) = IRNode.OPSelect;
                code(3) = addNode(self, args{1});
                [code(4), ty1] = addNode(self, args{2});
                [code(5), ty2] = addNode(self, args{3});
                typ = max(ty1, ty2);
                id = addVal(self, typ);
                code(2) = id;
            elseif head == IRNode.OPCmp
                code = zeros(1, 5, 'int32');
                code(1) = IRNode.OPCmp;
                code(3) = args{1};
                code(4) = addNode(self, args{2});
                code(5) = addNode(self, args{3});
                id = addVal(self, IRNode.TyBool);
                code(2) = id;
                typ = IRNode.TyBool;
            elseif head == IRNode.OPAnd
                code = zeros(1, 4, 'int32');
                code(1) = IRNode.OPAnd;
                code(3) = addNode(self, args{1});
                code(4) = addNode(self, args{2});
                id = addVal(self, IRNode.TyBool);
                code(2) = id;
                typ = IRNode.TyBool;
            elseif head == IRNode.OPOr
                code = zeros(1, 4, 'int32');
                code(1) = IRNode.OPOr;
                code(3) = addNode(self, args{1});
                code(4) = addNode(self, args{2});
                id = addVal(self, IRNode.TyBool);
                code(2) = id;
                typ = IRNode.TyBool;
            elseif head == IRNode.OPXor
                code = zeros(1, 4, 'int32');
                code(1) = IRNode.OPXor;
                code(3) = addNode(self, args{1});
                code(4) = addNode(self, args{2});
                id = addVal(self, IRNode.TyBool);
                code(2) = id;
                typ = IRNode.TyBool;
            elseif head == IRNode.OPNot
                code = zeros(1, 3, 'int32');
                code(1) = IRNode.OPNot;
                code(3) = addNode(self, args{1});
                id = addVal(self, IRNode.TyBool);
                code(2) = id;
                typ = IRNode.TyBool;
            else
                if head == IRNode.OPAdd
                    opcode = IRNode.OPAdd;
                elseif head == IRNode.OPSub
                    opcode = IRNode.OPSub;
                elseif head == IRNode.OPMul
                    opcode = IRNode.OPMul;
                elseif head == IRNode.OPFDiv
                    opcode = IRNode.OPFDiv;
                else
                    error('Unknown head');
                end
                code = zeros(1, 4, 'int32');
                code(1) = opcode;
                [code(3), ty1] = addNode(self, args{1});
                [code(4), ty2] = addNode(self, args{2});
                if head == IRNode.OPFDiv
                    typ = IRNode.TyFloat64;
                else
                    typ = max(ty1, ty2);
                    typ = max(typ, IRNode.TyInt32);
                end
                id = addVal(self, typ);
                code(2) = id;
            end
            self.node_map(node.id) = struct('id', id, 'typ', typ);
            self.code = [self.code, {code}];
        end
    end
end
