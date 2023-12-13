classdef AutoScanner < handle
    properties
        scgrp
        analysis
    end
    methods
        function self = AutoScanner(scgrp, analysis)
            % scangrp: The scan to run. NumPerParamAvg should be set
            % already. In other words, the scan needs to stop at some
            % point. You can also wait for the user to call AbortRunSeq if
            % you prefer.
            % analysis_fn: Function to run after the scan finishes. 
            % varargin: Variable arguments that will be passed to the
            % analysis_fn
            self.scgrp = scgrp;
            self.analysis = analysis;
        end
        function run(self)
            finish = 0;
            while ~finish
                [date, time] = StartScan2(self.scgrp);
                finish = self.analysis.analyze(date, time);
            end
        end
    end
end
