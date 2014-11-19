%% Copyright (c) 2014-2014, Yichao Yu <yyc1992@gmail.com>
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

s = daq.createSession('ni');
s.Rate = 100;
s.addAnalogOutputChannel('Dev2', 0, 'Voltage');
s.addTriggerConnection('External', 'Dev2/PFI1', 'StartTrigger');
s.addClockConnection('External', 'Dev2/PFI0', 'ScanClock');
s.addAnalogOutputChannel('Dev2', 1, 'Voltage');
s.addAnalogOutputChannel('Dev2', 2, 'Voltage');
s.addAnalogOutputChannel('Dev2', 4, 'Voltage');
data = zeros(6, 4);
data(2:4, 4) = 1;
s.queueOutputData(data);
s.startBackground();
disp('Start Pause');
pause(3);
disp('Finish Pause');
s.wait();
