classdef XYZBFieldComp < handle
    %Intended to compensate for changing magnetic fields within an
    %experiment. 
    
    properties
        
        serNumX;
        serNumY;
        serNumZ;
        
        xsettings=struct("serialNumRead",32290082,"serialNumWrite",32290082,"devNum",0,"inputChannel","ai0","outputChannel","ao0","triggerChannel","PFI0",...
            "bTrigger",1);
        ysettings=struct("serialNumRead",32290082,"serialNumWrite",32290082,"devNum",0,"inputChannel","ai1","outputChannel","ao1","triggerChannel","PFI0",...
            "bTrigger",1);
        zsettings=struct("serialNumRead",32290073,"serialNumWrite",32290073,"devNum",1,"inputChannel","ai0","outputChannel","ao0","triggerChannel","PFI0",...
            "bTrigger",1);
        
        sampleRate=1000; %1/s
        sampleTime=0.3; %s
        waitTime=5; %s
        lastReadTime=0; %
        
        lastVX = 0;
        lastVY = 0;
        lastVZ = 0;
        
        %linear conversion factors between input and output voltages and
        %the B fields (in G) they represent. Calibrated.
        inputVoltageToBConversion;
        outputVoltageToBConversion;
        
        desiredBX = 8.8; %G
        desiredBY = 0;
        desiredBZ = 0;
        
        NIDAQX;
        NIDAQY;
        NIDAQZ;
    end
    
    methods
        function readAndCompensate(self,numSamples)
            if testRecent()
                recentBXList=self.NIDAQX.aiRead("xread",numSamples)/self.inputVoltageToBConversion;
                recentBYList=self.NIDAQY.aiRead("yread",numSamples)/self.inputVoltageToBConversion;
                recentBZList=self.NIDAQZ.aiRead("zread",numSamples)/self.inputVoltageToBConversion;
                
                newVX = getOptimalOutputVoltage(mean(recentBXList),self.desiredBX,self.lastVX);
                newVY = getOptimalOutputVoltage(mean(recentBYList),self.desiredBY,self.lastVY);
                newVZ = getOptimalOutputVoltage(mean(recentBZList),self.desiredBZ,self.lastVZ);
                
                self.lastVX = self.NIDAQ.aoVoltage(newVX);
                self.lastVY = self.NIDAQ.aoVoltage(newVY);
                self.lastVZ = self.NIDAQ.aoVoltage(newVZ);
                
            end
        end
        
        function outputVoltage = getOptimalOutputVoltage(CurrentBField,desiredBField,currentVoltage)
            deltaB=CurrentBField-desiredBField;
            deltaV = deltaB*self.outputVoltageToBConversion;
            outputVoltage = currentVoltage+deltaV;
        end
        
        function initializeCompensation(self)
            if testRecent()
                self.NIDAQX.setupDelayedRead("xread",self.sampleRate,self.sampleTime,self.xsettings);
                self.NIDAQY.setupDelayedRead("yread",self.sampleRate,self.sampleTime,self.ysettings);
                self.NIDAQZ.setupDelayedRead("zread",self.sampleRate,self.sampleTime,self.zsettings);
            end 
        end
        function shouldTest = testRecent(self)
            shouldTest= (now-self.lastReadTime)/self.waitTime/86400>1;
        end
        function res = updateSettings(settings)
            if isa(settings,"struct")
                if isfield(settings,"sampleRate")
                    self.sampleRate=settings.sampleRate;
                end
                if isfield(settings,"sampleTime")
                    self.sampleTime=settings.sampleTime;
                end
                if isfield(settings,"waitTime")
                    self.waitTime=settings.waitTime;
                end
                if isfield(settings,"xsettings")
                    self.xsettings=settings.xsettings;
                end
                if isfield(settings,"ysettings")
                    self.ysettings=settings.ysettings;
                end
                if isfield(settings,"zsettings")
                    self.zsettings=settings.zsettings;
                end
            else
                warning("settings must be a struct")
            end
            res = self;
        end
        
        function self = XYZBFieldComp(settings)
            if isa(settings,"struct")
                if isfield(settings,"sampleRate")
                    self.sampleRate=settings.sampleRate;
                end
                if isfield(settings,"sampleTime")
                    self.sampleTime=settings.sampleTime;
                end
                if isfield(settings,"waitTime")
                    self.waitTime=settings.waitTime;
                end
                if isfield(settings,"xsettings")
                    self.xsettings=settings.xsettings;
                end
                if isfield(settings,"ysettings")
                    self.ysettings=settings.ysettings;
                end
                if isfield(settings,"zsettings")
                    self.zsettings=settings.zsettings;
                end
            else
                warning("settings must be a struct")
            end
            if isfield(settings,"serNumX")
                self.serNumX = settings.serNumX;
            else
                warning("Must specify a device serial number for X B field comp.")
                self=[];
                return
            end
            if isfield(settings,"serNumY")
                self.serNumY = settings.serNumY;
            else
                warning("Must specify a device serial number for Y B field comp.")
                self=[];
                return
            end
            if isfield(settings,"serNumZ")
                self.serNumZ = settings.serNumZ;
            else
                warning("Must specify a device serial number for Z B field comp.")
                self=[];
                return
            end
            self.NIDAQX=NIDAQIOHandler.get(self.serNumX,self.serNumX,self.xsettings);
            self.NIDAQY=NIDAQIOHandler.get(self.serNumY,self.serNumY,self.ysettings);
            self.NIDAQZ=NIDAQIOHandler.get(self.serNumZ,self.serNumZ,self.zsettings);
            
        end
        
            
    end
end

