classdef NIUSBDAQWrapper < handle
    %NIUSBDAQPoster Python wrapper for control of NI USB DAQ
    %Requires nidaqmx python library installed

    properties(Constant, Access=private)
        cache = containers.Map();
    end

    properties(SetAccess = private)
        serialNum;
        pyglob;
    end

    properties
        devNum;
        channelName = "ai0";
        outChannel = "ao0";
        trigChan = "PFI0";
        bTrig = 1;
    end

    methods
        function res = setChannels(self,channelSettings)
            %Set data acquisition and (optionally) triggering properties
            %ChannelSettings, struct with fields:
            %   channelName, string: Name of the channel to read from, e.g. "ai0"
            %   bTrig, bool: 1 to do triggered acquisition, 0 to autostart
            %   trigChan, string: Name of  channel to trigger from

            if isfield(channelSettings, 'channelName')
                self.channelName = channelSettings.channelName;
            end
            if isfield(channelSettings, 'outChannel')
                self.outChannel = channelSettings.outChannel;
            end
            if isfield(channelSettings, 'bTrig')
                self.bTrig = channelSettings.bTrig;
            end
            if isfield(channelSettings, 'trigChan')
                self.trigChan = channelSettings.trigChan;
            end
            res = self;
        end

        function aiData = acquire(self, sampleRate, sampleTime, varargin)
            %Acquire data from NI USB DAQ
            %Arguments:
            %   sampleRate, int: Number of samples per second to acquire
            %   sampleTime, float: Number of seconds for which to sample
            %   optional argument:
            %       channelSettings, struct: channelName, bTrig, trigChan

            %Set optional arguments to overwrite current values
            if ~isempty(varargin)
                channelSettings = varargin{1};
                if isa(channelSettings, 'struct')
                    self = self.setChannels(channelSettings);
                else
                    warning('channelSettings input must be a struct')
                end
            end

            %Acquire data and convert to numeric array
            aiData = cell2mat(cell(py.NIUSBDAQ.acquire(self.devNum,self.channelName,...
                sampleRate, sampleTime,self.bTrig, self.trigChan)));
        end
        
        function res = setV(self,channelName,V)
            %Acquire data from NI USB DAQ
            %Arguments:
            %   channelName, string: Channel name on which to set voltage
            %   V, float: Voltage to set on channel

            %Set voltage on channel
            py.NIUSBDAQ.setV(self.devNum,channelName,V)
            res = self;
        end
    end

    methods(Access = private)
        function self = NIUSBDAQWrapper(devNum,serialNum)
            %NIUSBDAQWrapper Construct an instance of this class
            self.devNum = devNum;
            self.serialNum = serialNum;
        end
    end

    methods(Static)
        function dropAll()%Delete NIUSBDAQWrapper connection from memory
            remove(NIUSBDAQWrapper.cache, keys(NIUSBDAQWrapper.cache));
        end

        function res = get(serialNum, varargin)
            %Create new object or return existing object
            %Arguments:
            %   serialNum, int: Serial number of USB DAQ to connect to
            %   ChannelSettings, struct with fields:
            %       channelName, string: Name of the channel to read from, e.g. "ai0"
            %       bTrig, bool: 1 to do triggered acquisition, 0 to autostart
            %       trigChan, string: Name of  channel to trigger from

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
            devNum = -1;
            for i = 0:(numDevs - 1)
                checkSerial = int64(py.NIUSBDAQ.getSerial(i));
                if checkSerial == serialNum
                    devNum = i;
                    break
                end
            end

            if devNum == -1
                warning('No device found with given serial number. B field comp is not working.')
                res = [];
                return
            end

            %Generate id from serial number
            id = NIUSBDAQWrapper.getID(serialNum);

            %Check if connection to instrument already exists
            if isKey(cache, id)
                res = cache(id);
                if ~isempty(res)
                    res.devNum = devNum; %Reset device number to located device
                    return;
                end
                delete(res);
            end

            %If no connection exists, initialize
            res = NIUSBDAQWrapper(devNum, serialNum);
            cache(id) = res;

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
            res.pyglob = py.dict(pyargs('mat_srcpath', path,'serialNum',serialNum,...
                'trigChan', res.trigChan,'channelName',res.channelName, 'bTrig', res.bTrig));
        end

        function id = getID(serialNum)
            %Generate unique device id from serial number
            id = sprintf('NI-USB-DAQ:serial#%d', serialNum);
        end
    end
end
