classdef XYZBFieldCompensator < handle
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
        serialNums;
        pyglob;
    end
    
    properties
        devNumX = 0;
        inputChannelX="ai0";
        outputChannelX="ao0";
        triggerChannelX="PFI0";
        bTrigX=1;
        
        devNumY = 0;
        inputChannelY="ai1";
        outputChannelY="ao1";
        triggerChannelY="PFI1";
        bTrigY=1;
        
        devNumZ = 1;
        inputChannelZ="ai0";
        outputChannelZ="ao0";
        triggerChannelZ="PFI0";
        bTrigZ=1;
        
    end
    
    methods
        function res = setChannels(self,channelSettings)
            %Allows for setting DAQ input and output channels. 
            %channelSettings is a struct with the following fields:
            %1) devNums, array, size 3, int: number of device intended to
            %   handle [x,y,z] B fields, respectively. 
            %2) inputChannels, array, size 3, string: name of channels to 
            %   take [x,y,z] inputs from. e.g. ['ai0' 'ai1' 'ai0'], etc.
            %3) outputChannels, array, size 3, string: name of channels
            %   on which to output [x,y,z] voltages to. e.g. ['ao0' 'ao1' 
            %   'ao0]. Generally on different devices.
            %4) triggerChannels, array, size 3, string: name of channels
            %   used to trigger read events on the [x,y,z] device. 
            %   e.g. ['PFI0' 'PFI1' 'PFI1']
            %5) bTrigs, array, size 3, bool: determines whether the [x,y,z]
            %   measurements will be autostarted or started on triger.
            %   0 causes tasks to run as soon as started; 1
            %   corresponds to tasks starting only on trigger signal. 
            
            if isfield(channelSettings, 'devNums')
                self.devNumX = channelSettings.devNums(1);
                self.devNumY = channelSettings.devNums(2);
                self.devNumZ = channelSettings.devNums(3);
            end
            if isfield(channelSettings, 'inputChannels')
                self.inputChannelX = channelSettings.inputChannels(1);
                self.inputChannelY = channelSettings.inputChannels(2);
                self.inputChannelZ = channelSettings.inputChannels(3);
            end
            if isfield(channelSettings, 'outputChannels')
                self.outputChannelX = channelSettings.outputChannels(1);
                self.outputChannelY = channelSettings.outputChannels(2);
                self.outputChannelZ = channelSettings.outputChannels(3);
            end
            if isfield(channelSettings, 'triggerChannels')
                self.triggerChannelX = channelSettings.triggerChannels(1);
                self.triggerChannelY = channelSettings.triggerChannels(2);
                self.triggerChannelZ = channelSettings.triggerChannels(3);
            end
            if isfield(channelSettings, 'bTrigs')
                self.bTrigX = channelSettings.bTrigs(1);
                self.bTrigY = channelSettings.bTrigs(2);
                self.bTrigZ = channelSettings.bTrigs(3);
            end
            res = self;
        end
        
        function setupDelayedRead(self, sampleRate, sampleTime,varargin)
            if ~isempty(varargin)
                channelSettings = varargin{1};
                if isa(channelSettings,'struct')
                    self.setChannels(channelSettings)
                else
                    warning("channelSettings input must be a struct")
                end
            end
            py.NIDAQReadWriteLib.acquireDelayed("xread",self.devNumX,self.inputChannelX,...
                sampleRate,sampleTime,self.bTrigX,self.triggerChannelX);
            py.NIDAQReadWriteLib.acquireDelayed("yread",self.devNumY,self.inputChannelY,...
                sampleRate,sampleTime,self.bTrigY,self.triggerChannelY);
            py.NIDAQReadWriteLib.acquireDelayed("zread",self.devNumZ,self.inputChannelZ,...
                sampleRate,sampleTime,self.bTrigZ,self.triggerChannelZ);
        end
        function xyzAIRead = readDelayed(nSamples)
            xreads = cell2mat(cell(py.NIDAQReadWriteLib.readOutTask("xread",nSamples)));
            yreads = cell2mat(cell(py.NIDAQReadWriteLib.readOutTask("yread",nSamples)));
            zreads = cell2mat(cell(py.NIDAQReadWriteLib.readOutTask("zread",nSamples)));
            
            xyzAIRead = [xreads;yreads;zreads];
        end
        
        function xyzAOVoltage(self,vx,vy,vz)
            py.NIDAQReadWriteLib.dcoutNow(self.devNumX,self.outputChannelX,...
                vx)
            py.NIDAQReadWriteLib.dcoutNow(self.devNumY,self.outputChannelY,...
                vy)    
            py.NIDAQReadWriteLib.dcoutNow(self.devNumZ,self.outputChannelY,...
                vz)
        end
    end
    methods(Access = private)
        function self = XYZBFieldCompensator(devNums,serialNums)
            self.devNumX=devNums(1);
            self.devNumY=devNums(2);
            self.devNumZ=devNums(3);
            self.serialNums=serialNums;
        end
    end
    methods(Static)
        function dropAll() %deletes all connections from memory
            remove(XYZBFieldCompensator.cache,keys(XYZBFieldCompensator.cache));
        end
        function res = get(serialNums,varargin)
            cache=XYZBFieldCompensator.cache;
            
            %Get path of XYZBFieldCompensator.m, which should be the same
            %as path of NIDAQReadWriteLib.py. 
            [path,~,~]=fileparts(mfilename('fullpath'));
            pyglob = py.dict(pyargs('mat_srcpath',path,'serialNums',serialNums));
            
            %loads python library
            
            try
                py.exec('import NIDAQReadWriteLib',pyglob);
            catch
                py.exec('import sys;sys.path.append(mat_srcpath)',pyglob)
                py.exec('import NIDAQReadWriteLib',pyglob);
            end
            
            %asks NIDAQReadWriteLib how many devices are connected
            nDevices = int64(py.NIDAQReadWriteLib.numDevices());
            
            if numDevs==0
                disp("Error: no NI USB DAQ devices detected by nidaqmx")
                res = [];
                return
            end
            
            devNumX=-1;
            devNumY=-1;
            devNumZ=-1;
            for i = 0:(nDevices-1)
                if int64(py.NIDAQReadWriteLib.getSerial(i))==serialNums(1)
                    devNumX=i;
                    break
                end
            end
            for i = 0:(nDevices-1)
                if int64(py.NIDAQReadWriteLib.getSerial(i))==serialNums(2)
                    devNumY=i;
                    break
                end
            end
            for i = 0:(nDevices-1)
                if int64(py.NIDAQReadWriteLib.getSerial(i))==serialNums(3)
                    devNumZ=i;
                    break
                end
            end
            
            if devNumX==-1
                warning("No device found with given serial number for X.")
            end
            if devNumY==-1
                warning("No device found with given serial number for Y.")
            end
            if devNumZ==-1
                warning("No device found with given serial number for Z.")
            end
            if (devNumX==-1) | (devNumY==-1) | (devNumZ==-1)
                res=[];
                return
            end
            
            devNums=[devNumX;devNumY;devNumZ];
            
            res = XYZBFieldCompensator(devNums,serialNums);
            
            if ~isempty(varargin)
                channelSettings=varargin{1};
                if isa(channelSettings,'struct')
                    res=res.setChannels(channelSettings);
                else
                    warning("channelSettings must be a struct. Cannot assign input or output channels")
                end
            end
            
            res.pyglob = py.dict(pyargs("mat_srcpath",path,"serialNums",serialNums,...
                "devNumX",res.devNumX,"devNumY",res.devNumY,"devNumZ",res.devNumZ,...
                "inputChannelX",res.inputChannelX,"inputChannelY",res.inputChannelY,...
                "inputChannelZ",res.inputChannelZ,"outputChannelX",res.outputChannelX,...
                "outputChannelY",res.outputChannelY,"outputChannelZ",res.outputChannelZ,...
                "triggerChannelX",res.triggerChannelX,"triggerChannelY",res.triggerChannelY,...
                "triggerChannelZ",res.triggerChannelZ,"bTrigX",res.bTrigX,...
                "bTrigY",res.bTrigY,"bTrigZ",res.bTrigZ);
        end
            
    end
end

