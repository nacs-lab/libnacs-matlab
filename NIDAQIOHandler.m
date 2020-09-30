classdef NIDAQIOHandler
    %Created by Avery Parr in September 2020. Based on NIDAQUSBWrapper.m
    %code.
    
    %Set of Matlab functions to be called before and after sequences to 
    %access a National Instruments USB DAQ, through the nidaqmx Python
    %package. This package must be installed, and the accompanying code
    %NIDAQReadWriteLib.py must also be available. 
    
    properties(Constant, Access=private)
        cache = containers.Map()
    end
    
    properties(SetAccess = private)
        serialNumRead;
        serialNumWrite;
        pyglob;
    end
    
    properties
        devNumRead=0;
        devNumWrite=0;
        inputChannel="ai0";
        outputChannel="ao0";
        triggerChannel="PFI0";
        bTrigger=1;
    end
    methods
        function res = setChannels(self,channelSettings)
            %Allows for setting DAQ input and output channels. 
            %channelSettings is a struct with the following fields:
            %1) devNum, int: number of device on which reading and writing
            %   takes place. If specified, will overwrite devNumRead and
            %   devNumWrite.
            %2) devNumRead, int: number of device on which voltage reading
            %   takes place.
            %3) devNumWrite, int: number of device on which analog out
            %   signals are relayed. 
            %4) inputChannel, string: name of channel on which to read
            %   voltages. E.g. "ai0"
            %5) outputChannel, string: name of channel on which analog
            %   writes occur. E.g. "ao0".
            %6) triggerChannel, string: name of channel
            %   used to trigger read events. E.g. "PFI0".
            %7) bTrigger, bool: determines whether read measurements
            %   will be autostarted or started on triger.
            %   0 causes tasks to run as soon as started; 1
            %   corresponds to tasks starting only on trigger signal. 
            if isfield(channelSettings,"devNumRead")
                self.devNumRead=channelSettings.devNumRead;
            end
            if isfield(channelSettings,"devNumWrite")
                self.devNumWrite=channelSettings.devNumWrite;
            end
            if isfield(channelSettings,"devNum")
                self.devNumWrite=channelSettings.devNum;
                self.devNumRead=channelSettings.devNum;
            end
            if isfield(channelSettings,"inputChannel")
                self.inputChannel=channelSettings.inputChannel;
            end
            if isfield(channelSettings,"outputChannel")
                self.outputChannel=channelSettings.outputChannel;
            end
            if isfield(channelSettings,"triggerChannel")
                self.triggerChannel=channelSettings.triggerChannel;
            end
            if isfield(channelSettings,"bTrigger")
                self.bTrigger=channelSettings.bTrigger;
            end
            res=self;
        end
        
        function taskname = setupDelayedRead(self,readname,sampleRate,sampleTime,varargin)
            if ~isempty(varargin)
                channelSettings = varargin{1};
                if isa(channelSettings,'struct')
                    self.setChannels(channelSettings)
                else
                    warning("channelSettings input must be a struct")
                end
            end
            py.NIDAQReadWriteLib.acquireDelayed(readname,self.devNumRead,...
                self.inputChannel,sampleRate,sampleTime,self.bTrig,...
                self.triggerChannel)
            taskname = readname;
        end
        function res = aiRead(taskName,nSamples)
            reads=cell2mat(cell(py.NIDAQReadWriteLib.readOutTask(taskName,nSamples)));
            res = reads;
        end
        function newvolts = aoVoltage(self,v,varargin)
            if ~isempty(varargin)
                channelSettings = varargin{1};
                if isa(channelSettings,'struct')
                    self.setChannels(channelSettings)
                else
                    warning("channelSettings input must be a struct")
                end
            end
            py.NIDAQReadWriteLib.dcoutNow(self.devNumWrite,self.outputChannel,v);
            newvolts = v;
        end   
    end
    methods(Access = private)
        function self = NIUSBDAQWrapper(devNum,serialNumRead,serialNumWrite)
            %NIUSBDAQWrapper Construct an instance of this class
            self.devNum = devNum;
            self.serialNumRead = serialNumRead;
            self.serialNumWrite = serialNumWrite;
        end
    end
    methods(Static)
        function dropAll()%Delete NIUSBDAQWrapper connection from memory
            remove(NIUSBDAQWrapper.cache, keys(NIUSBDAQWrapper.cache));
        end

        function res = get(serialNumRead,serialNumWrite, varargin)
            %Create new object or return existing object
            %Arguments:
            %   serialNumRead, int: Serial number of USB DAQ to connect to
            %   for analog inputs
            %   serialNumWrite, int: Serial number of USB DAQ to connect to
            %   for analog outputs
            %   
            %   channelSettings is a struct with the following fields:
            %       1) devNum, int: number of device on which reading and writing
            %           takes place. If specified, will overwrite devNumRead and
            %           devNumWrite.
            %       2) devNumRead, int: number of device on which voltage reading
            %           takes place.
            %       3) devNumWrite, int: number of device on which analog out
            %           signals are relayed. 
            %       4) inputChannel, string: name of channel on which to read
            %           voltages. E.g. "ai0"
            %       5) outputChannel, string: name of channel on which analog
            %           writes occur. E.g. "ao0".
            %       6) triggerChannel, string: name of channel
            %           used to trigger read events. E.g. "PFI0".
            %       7) bTrigger, bool: determines whether read measurements
            %           will be autostarted or started on triger.
            %           0 causes tasks to run as soon as started; 1
            %           corresponds to tasks starting only on trigger signal. 

            cache = NIUSBDAQWrapper.cache;

            %Get path of class definition, which should be in same place as
            %Python library
            [path, ~, ~] = fileparts(mfilename('fullpath'));
            pyglob = py.dict(pyargs('mat_srcpath', path,'serialNum',serialNum));

            %Load python library
            try
                py.exec('import NIUSBDAQ', pyglob);
            catch
                py.exec('import sys; sys.path.append(mat_srcpath)', pyglob);
                py.exec('import NIUSBDAQ', pyglob);
            end

            %Get number of devices connected
            numDevs = int64(py.NIUSBDAQ.numDevices());

            if numDevs == 0
                disp('Error: No NI USB DAQ devices connected.')
                res = [];
                return
            end

            %Search for device with given serial number
            devNumRead = -1;
            for i = 0:(numDevs - 1)
                if int64(py.NIUSBDAQ.getSerial(i)) == serialNumRead
                    devNumRead = i;
                    break
                end
            end

            if devNumRead == -1
                warning('No device found with given serial number for analog inputs. B field comp is not working.')
                res = [];
                return
            end
            
            %Search for device with given serial number
            devNumWrite = -1;
            for i = 0:(numDevs - 1)
                if int64(py.NIUSBDAQ.getSerial(i)) == serialNumWrite
                    devNumWrite = i;
                    break
                end
            end

            if devNumWrite == -1
                warning('No device found with given serial number for analog outputs. B field comp is not working.')
                res = [];
                return
            end

            %Generate id from serial number
            idRead = NIDAQIOHandler.getID(serialNumRead);
            idWrite = NIDAQIOHandler.getID(serialNumWrite);

            %Check if connection to instrument already exists
            if isKey(cache, idRead)
                res = cache(idRead);
                if ~isempty(res)
                    res.devNumRead = devNumRead; %Reset device number to located device
                    return;
                end
                delete(res);
            end
            if isKey(cache, idWrite)
                res = cache(idWrite);
                if ~isempty(res)
                    res.devNumRead = devNumWrite; %Reset device number to located device
                    return;
                end
                delete(res);
            end

            %If no connection exists, initialize
            res = NIDAQIOHandle(devNum, serialNumRead,serialNumWrite);

            %Set optional arguments to overwrite current values
            if ~isempty(varargin)
                channelSettings = varargin{1};
                if isa(channelSettings, 'struct')
                    res = res.setChannels(channelSettings);
                else
                    warning('channelSettings input must be a struct')
                end
            end

            %Updated global python environment
            res.pyglob = py.dict(pyargs('mat_srcpath', path,'serialNumRead',serialNumRead,...
                'serialNumWrite',serialNumWrite,'devNumRead',devNumRead,...
                'devNumWrite',devNumWrite,'inputChannel',inputChannel,'outputChannel',...
                outputChannel,'triggerChannel',triggerChannel,...
                'bTrigger',bTrigger));
        end

        function id = getID(serialNum)
            %Generate unique device id from serial number
            id = sprintf('NI-USB-DAQ:serial#%d', serialNum);
        end
    end

end

