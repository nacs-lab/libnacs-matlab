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

classdef WavemeterServer < handle
  properties
    ctx;
    sock;
    setpoint;
  end
  properties(Constant)
      % Number of seconds before checking if the setpoint
      POLL_INTERV = 60;
  end

  methods
    function self = WavemeterServer(url)
      if ~exist('url', 'var')
          url = 'tcp://127.0.0.1:1026';
      end
      self.setpoint = 0;
      pyglob = py.dict();
      py.exec('import zmq', pyglob);
      self.ctx = py.eval('zmq.Context()', pyglob);
      self.sock = self.ctx.socket(py.eval('zmq.REP', pyglob));
      self.sock.bind(url);
    end

    function ensureSetpoint(self)
        setpoint = self.setpoint;
        fprintf('Setpoint: %f\n', setpoint);
        if rand() < 0.2
            fprintf('Pretend we are doing something: %f\n', setpoint);
            pause(10);
            fprintf('Done!\n');
        end
    end

    function run(self)
        cnt = 0;
        last_set = 0;
        while 1
            cnt = cnt + 1;
            if cnt > last_set + self.POLL_INTERV && self.setpoint ~= 0
                ensureSetpoint(self);
            end
            if ~self.poll()
                continue;
            end
            req = uint8(self.sock.recv());
            head = typecast(req(1:4), 'uint32');
            if head == 0
                if length(req) ~= 12
                    fprintf('Invalid setpoint length: %d\n', length(req));
                    self.sock.send(uint8([0, 0]));
                    continue;
                end
                setpoint = typecast(req(5:12), 'double');
                if setpoint ~= self.setpoint
                    self.setpoint = setpoint;
                    ensureSetpoint(self);
                end
                self.sock.send(uint8([1, 0]));
            else
                % Unknown request:
                fprintf('Unknown request header: %x\n', head);
                self.sock.send(uint8([0, 0]));
                continue;
            end
        end
    end

    function res=poll(self)
        % Wait for requests for 1s.
        res = self.sock.poll(1000) ~= 0;
    end
  end
end
