%% Copyright (c) 2016-2016, Yichao Yu <yyc1992@gmail.com>
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

classdef IRFunc < handle
  properties
    % return_type: Float64
    nargs;
    % Assume all variables are Float64
    nvals;
    % Assume there's only one BB
    code;
    byte_code;
    % Assume all constants are also Float64
    consts;
    const_map;

    float_table;
  end

  methods
      %%
    function self=IRFunc(nargs)
      self.nargs = nargs;
      self.nvals = nargs;
      self.code = {};
      self.consts = [];
      self.const_map = containers.Map('KeyType', 'double', ...
                                      'ValueType', 'double');
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
    function data=serialize(self)
      sz = self.serializeSize();
      data = zeros(1, sz, 'int32');
      data(1) = IRNode.TyFloat64;
      data(2) = self.nargs;
      data(3) = self.nvals;
      for i = 1:ceil(self.nvals / 4)
        data(3 + i) = typecast([int8(IRNode.TyFloat64), ...
                                int8(IRNode.TyFloat64), ...
                                int8(IRNode.TyFloat64), ...
                                int8(IRNode.TyFloat64)], 'int32');
      end
      offset = 3 + ceil(self.nvals / 4);
      data(offset + 1) = length(self.consts);
      offset = offset + 1;
      for i = 1:length(self.consts)
        new_offs = offset + (i - 1) * 3;
        data(new_offs + 1) = IRNode.TyFloat64;
        data(new_offs + 2:new_offs + 3) = typecast(self.consts(i), 'int32');
      end
      offset = offset + length(self.consts) * 3;
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

  methods
      %%
    function sz=serializeSize(self)
      sz = 1 + 1 + 1 + ceil(self.nvals / 4); % [ret][nargs][nvals][vals x nvals]
      sz = sz + 1 + length(self.consts) * 3; % [nconsts][consts x nconsts]
      sz = sz + 1 + 1 + length(self.byte_code); % [nbb][nword][code x nword]
      sz = sz + 1 + length(self.float_table) * 2; % [nfloat][float x nfloat]
    end

    %%
    function id=addConst(self, v)
      v = double(v);
      if isKey(self.const_map, v)
        id = self.const_map(v);
      else
        self.consts = [self.consts, v];
        id = length(self.consts);
        self.const_map(v) = id;
      end
    end

    %%
    function id=addVal(self)
      id = self.nvals;
      self.nvals = id + 1;
    end

    %%
    function id=addNode(self, node)
      if isnumeric(node) || islogical(node)
        if ~isscalar(node)
          error('Non scalar constant');
        end
        id = -self.addConst(node) - 2;
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
          error('Argument ID out of range')
        end
        id = argnum - 1;
        return;
      end
      if head == IRNode.HCall
        callee = args{1};
        nargs = length(args) - 1;
        code = zeros(1, nargs + 4, 'int32');
        code(1) = IRNode.OPCall;
        id = self.addVal();
        code(2) = id;
        code(3) = callee;
        code(4) = nargs;
        for i = 1:nargs
          code(4 + i) = self.addNode(args{1 + i});
        end
      elseif head == IRNode.HInterp
        code = zeros(1, 7, 'int32');
        code(1) = IRNode.OPInterp;
        id = self.addVal();
        code(2) = id;
        code(3) = self.addNode(args{1});
        code(4) = self.addNode(args{2});
        code(5) = self.addNode(args{3});
        oldlen = length(self.float_table);
        vals = args{4};
        vlen = length(vals);
        code(6) = oldlen;
        code(7) = vlen;
        self.float_table(oldlen + 1:oldlen + vlen) = vals;
      else
        if head == IRNode.HAdd
          opcode = IRNode.OPAdd;
        elseif head == IRNode.HSub
          opcode = IRNode.OPSub;
        elseif head == IRNode.HMul
          opcode = IRNode.OPMul;
        elseif head == IRNode.HFDiv
          opcode = IRNode.OPFDiv;
        else
          error('Unknown head')
        end
        code = zeros(1, 4, 'int32');
        code(1) = opcode;
        id = self.addVal();
        code(2) = id;
        code(3) = self.addNode(args{1});
        code(4) = self.addNode(args{2});
      end
      self.code = [self.code, {code}];
    end
  end
end
