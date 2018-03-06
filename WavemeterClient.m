%% Copyright (c) 2018-2018, Yichao Yu <yyc1992@gmail.com>
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

classdef WavemeterClient < handle
  properties
    ctx;
    sock;
    url;
    zmqREQ;
  end

  methods
    function self = WavemeterClient(url)
      if ~exist('url', 'var')
          url = 'tcp://127.0.0.1:1026';
      end
      self.url = url;
      pyglob = py.dict();
      py.exec('import zmq', pyglob);
      self.ctx = py.eval('zmq.Context()', pyglob);
      self.zmqREQ = py.eval('zmq.REQ', pyglob);
      createSocket(self);
    end

    function createSocket(self)
      self.sock = self.ctx.socket(self.zmqREQ);
      self.sock.connect(self.url);
    end

    function set(self, val)
        val = double(val);
        if ~isscalar(val)
            error('Setpoint must be a number');
        elseif val <= 0
            error('Setpoint must be positive');
        end
        req = [typecast(uint32(0), 'uint8'), typecast(val, 'uint8')];
        try
            self.sock.send(req);
            while ~self.poll()
            end
            rep = uint8(self.sock.recv());
        catch ex
            createSocket(self)
            rethrow(ex)
        end
        if length(rep) ~= 2 || rep(1) ~= 1
            error('Setpoint failed.');
        end 
    end

    function res=poll(self)
        % Wait for requests for 1s.
        res = self.sock.poll(1000) ~= 0;
    end
  end
end
