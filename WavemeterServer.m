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
      POLL_INTERV = 30;
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
        fset = self.setpoint;
        % fset = 698.63 - 0*0.298; % Set frequency
        % the wavemeter and adjust piezo/picomoter mirror.
        fprintf('Setpoint: %f\n', fset);

        fres = 0.02; % GHz, max deviation from setpoint for success
        wmLogFile = '20180419_1.csv'; %wavemeter log file
        duration = 20; % s, how long to average wavemeter
        foffset = 288000; %GHz, subtracted from wavemeter freqs
        VPAslope = 0.25*10; % approximate V to freq slope.
        Vcenter = 8.1; % voltage to have innolume current = 0
        numInBound = 1; % number of sucesses before aborting
        Vmax = 9;
        Vmin = 7;

        kyhdl = Keithley.get();
        wm = Wavemeter.get(wmLogFile);

        flist = [];
        ferr = [];
        Vlist = [];
        figure(10); clf;
        i=1;
        numInBoundIdx = 1;
        while 1
            % Read wavemeter
            if i > 1
                pause(duration + 5);
            end
            try
                [times, freqs] = wm.ReadWavemeterNow(duration);
            catch err
                continue;
            end
            fMeasured = mean(freqs) - foffset;
            disp(['Measured frequency: ' num2str(fMeasured)]);
            deltaf = fMeasured - fset;
            deltaV = -(deltaf)/VPAslope;
            if abs(deltaf) < fres
                if numInBoundIdx >= numInBound
                    disp('Frequency locked.');
                    break;
                else
                    disp(['Within window ' num2str(numInBoundIdx) '/' num2str(numInBound)]);
                    numInBoundIdx = numInBoundIdx + 1;
                end
            end

            % Set voltage
            Vcurr = kyhdl.getVoltage();
            Vnew = Vcurr + deltaV;
            if Vnew > Vmax || Vnew < Vmin
                error('Voltage outside of range. Aborting...');
            end

            kyhdl.setVoltage(Vnew);
            %SetVInnolume((Vnew - Vcenter) * 10 + 5); % Cannot use NIDAQ while experiment running
            disp(['Set new voltage: ' num2str(Vnew)]);

            % Save to lists
            flist(i) = fMeasured;
            ferr(i) = std(freqs)/sqrt(1);
            Vlist(i) = Vnew;

            % Plot
            subplot(1,2,1);
            %errorbar( 1:length(flist), flist, ferr, '.-');
            plot( 1:length(flist), flist, '.-');
            xlabel('Iteration');
            ylabel('Freq (288XXX GHz)');
            subplot(1,2,2);
            plot(Vlist, '.-');
            xlabel('Iteration');
            ylabel('VPATemp (V)');
            subplot(1,2,2);

            i=i+1;
        end


    end

    function run(self)
        last_set = now() * 86400;
        while 1
            cur = now() * 86400;
            if cur > last_set + self.POLL_INTERV && self.setpoint ~= 0
                last_set = cur;
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
                if setpoint ~= self.setpoint || ...
                        cur > last_set + self.POLL_INTERV * 0.75
                    % Check again if we're getting close to the next
                    % timeout
                    last_set = cur;
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
