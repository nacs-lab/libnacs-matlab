classdef XYZBFieldComp < handle
    %Intended to compensate for changing magnetic fields within an
    %experiment.
    properties(Constant)
        defaultXSettings=struct("serialNumRead",32290082,"serialNumWrite",32290082,...
                                "devNumRead",0,"devNumWrite",0,"inputChannel","ai0",...
                                "outputChannel","ao0","triggerChannel","PFI0","bTrigger",0);
        defaultYSettings=struct("serialNumread",32290073,"serialNumWrite",32290073,...
                                "devNumRead",1,"devNumWrite",1,"inputChannel","ai0",...
                                "outputChannel","ao0","triggerChannel","PFI0","bTrigger",0);
        defaultZSettings=struct("serialNumread",32290073,"serialNumWrite",32290073,...
                                "devnumRead",1,"devNumWrite",1,"inputChannel","ai1",...
                                "outputChannel","ao1","triggerChannel","PFI1","bTrigger",0);
    end
    properties
        sampleRate=1000; %1/s
        sampleTime=0.3; %s
        waitTime=5; %s
        lastReadTime=0; %

        serNumX;
        serNumY;
        serNumZ;

        lastVX = 0;
        lastVY = 0;
        lastVZ = 0;

        %linear conversion factors between input and output voltages and
        %the B fields (in mG) they represent. Calibrated.
        inputVoltageToBConversion=1;
        outputVoltageToBConversion=1;

        desiredBX = 0; %mG
        desiredBY = 0;
        desiredBZ = 0;

        MAXIMUM_COMP=30 %mG

        recentlySetUp=0;

        NIDAQX;
        NIDAQY;
        NIDAQZ;
    end

    methods
        function res = readAndCompensate(self)
            if self.recentlySetUp
                recentBXList=self.NIDAQX.getLastVoltages()/self.inputVoltageToBConversion;
                recentBYList=self.NIDAQY.getLastVoltages()/self.inputVoltageToBConversion;
                recentBZList=self.NIDAQZ.getLastVoltages()/self.inputVoltageToBConversion;

                newVX = self.getOptimalOutputVoltage(mean(recentBXList),self.desiredBX,self.lastVX);
                newVY = self.getOptimalOutputVoltage(mean(recentBYList),self.desiredBY,self.lastVY);
                newVZ = self.getOptimalOutputVoltage(mean(recentBZList),self.desiredBZ,self.lastVZ);

                self.lastVX = self.NIDAQX.aoVoltage(newVX);
                self.lastVY = self.NIDAQY.aoVoltage(newVY);
                self.lastVZ = self.NIDAQZ.aoVoltage(newVZ);

                res=self;
            end
        end

        function outputVoltage = getOptimalOutputVoltage(self,CurrentBField,desiredBField,currentVoltage)
            deltaB=desiredBField-CurrentBField;
            if abs(deltaB)>self.MAXIMUM_COMP
                warning("XYZBField is suggesting a change in B field larger than the preset maximum. Resetting compensating voltage to 0")
                outputVoltage=0;
                return
            end
            deltaV = deltaB*self.outputVoltageToBConversion;
            outputVoltage = currentVoltage+deltaV;
            if abs(outputVoltage/self.outputVoltageToBConversion) > self.MAXIMUM_COMP
                warning("XYZBField is suggesting that total compensation exceed the preset maximum. Resetting compensating voltage to 0.")
                outputVoltage=0;
            end
        end

        function res = initializeCompensation(self)
            if self.testRecent()
                self.lastReadTime=now;
                self.recentlySetUp=1;
                self.NIDAQX=self.NIDAQX.asyncAcquire(self.sampleRate,self.sampleTime);
                self.NIDAQY=self.NIDAQY.asyncAcquire(self.sampleRate,self.sampleTime);
                self.NIDAQZ=self.NIDAQZ.asyncAcquire(self.sampleRate,self.sampleTime);
            end
            res = self;
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
                if isfield(settings,"desiredBX")
                    self.desiredBX = settings.desiredBX;
                end
                if isfield(settings,"desiredBY")
                    self.desiredBY = settings.desiredBY;
                end
                if isfield(settings, "desiredBZ")
                    self.desiredBZ = settings.desiredBZ;
                end
                if isfield(settings,"inputVoltageToBConversion")
                    self.inputVoltageToBConversion = settings.inputVoltageToBConversion;
                end
                if isfield(settings, "outputVoltageToBConversion")
                    self.outputVoltageToBConversion = settings.outputVoltageToBConversion;
                end
                if isfield(settings, "xsettings")
                    self.NIDAQX.setChannels(settings.xsettings);
                end
                if isfield(settings, "ysettings")
                    self.NIDAQY.setChannels(settings.ysettings);
                end
                if isfield(settings,"zsettings")
                    self.NIDAQZ.setChannels(settings.zsettings);
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
                if isfield(settings,"desiredBX")
                    self.desiredBX = settings.desiredBX;
                end
                if isfield(settings,"desiredBY")
                    self.desiredBY = settings.desiredBY;
                end
                if isfield(settings, "desiredBZ")
                    self.desiredBZ = settings.desiredBZ;
                end
                if isfield(settings,"inputVoltageToBConversion")
                    self.inputVoltageToBConversion = settings.inputVoltageToBConversion;
                end
                if isfield(settings, "outputVoltageToBConversion")
                    self.outputVoltageToBConversion = settings.outputVoltageToBConversion;
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
            if isfield(settings,"xsettings")
                self.NIDAQX=NIDAQIOHandler.get(self.serNumX,self.serNumX,settings.xsettings);
            else
                self.NIDAQX=NIDAQIOHandler.get(self.serNumX,self.serNumX,self.defaultXSettings);
            end
            if isfield(settings,"ysettings")
                self.NIDAQY=NIDAQIOHandler.get(self.serNumY,self.serNumY,settings.ysettings);
            else
                self.NIDAQY=NIDAQIOHandler.get(self.serNumY,self.serNumY,self.defaultYSettings);
            end
            if isfield(settings,"zsettings")
                self.NIDAQZ=NIDAQIOHandler.get(self.serNumZ,self.serNumZ,settings.zsettings);
            else
                self.NIDAQZ=NIDAQIOHandler.get(self.serNumZ,self.serNumZ,self.defaultZSettings);
            end
        end

    end
    methods(Static)
        function res = get(settings,serNumX,serNumY,serNumZ)
            settings.serNumX=serNumX;
            settings.serNumY=serNumY;
            settings.serNumZ=serNumZ;
            res=XYZBFieldComp(settings);
        end
        function dropAll()%Delete connection from memory
            remove(XYZBFieldComp.cache, keys(XYZBFieldComp.cache));
        end

    end
end
