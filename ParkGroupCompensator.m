classdef ParkGroupCompensator < handle
    properties(Constant, Access=private)
        cache = containers.Map()
    end

    properties(SetAccess = private)
        serialNum = Consts().BFieldDAQSerial;
        MagnetURL = Consts().MagnetURL;
        slope = Consts().ParkGroupMagnetSlope; % V/T 
    end

    properties
        m_NIDAQIOHandler;
        outputChannel="ao0";
        b_field_read;
        curr_v;
        m_uri;
        m_options; % options for http request
        m_request;
        t_interval = 0.5;
    end
    methods
%         function res = setOutputChannel(self, out)
%             self.outputChannel = out;
%             res = self;
%         end
%         function newvolts = aoVoltage(self,v)
%             py.NIDAQReadWriteLib.dcoutNow(self.devNumWrite,self.outputChannel,v);
%             self.curr_v = v;
%             newvolts = v;
%         end
    function res = setOutput(self, v)
        res = self.m_NIDAQIOHandler.aoVoltage(v);
        self.curr_v = res;
    end
    function res = readBField(self)
        [response,~,~] = self.m_request.send(self.m_uri, self.m_options);
        datastr = response.Body.Data;
        splitstr = split(datastr, "<");
        res = str2double(splitstr{1});
        self.b_field_read = res;
    end
    function res = compensate(self)
        while(true)
           val = self.readBField();
           v_val = self.setOutput(val * self.slope);
           fprintf("Set DAQ voltage to %f for compensation\n", v_val); 
           pause(0.5)
        end
        res = self;
    end
        
    end
    methods(Access=private)
        function self = ParkGroupCompensator(serialNum)
            %NIDAQIOHandler; Construct an instance of this class
            if nargin == 1
                self.serialNum = serialNum;
            end
            self.m_NIDAQIOHandler = NIDAQIOHandler.get(self.serialNum, self.serialNum);
            self.m_uri = matlab.net.URI(Consts().MagnetURL);
            self.m_options = matlab.net.http.HTTPOptions('ConnectTimeout', 60);
            self.m_request = matlab.net.http.RequestMessage;
        end
    end
    methods(Static)
        function dropAll()%Delete connection from memory
            remove(ParkGroupCompensator.cache, keys(ParkGroupCompensator.cache));
        end

       function res = get(serialNum)
           if nargin < 1
                serialNum = Consts().BFieldDAQSerial;
           end
            cache = ParkGroupCompensator.cache;
            id = serialNum;
            if isKey(cache, id)
                res = cache(id);
                if ~isempty(res)
                    return;
                end
                delete(res);
            end
            res = ParkGroupCompensator(serialNum);
            cache(num2str(id)) = res;
       end
    end

end

