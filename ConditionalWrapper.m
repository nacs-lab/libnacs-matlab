% Copyright (c) 2021-2021, Yichao Yu <yyc1992@gmail.com>
%
% This library is free software; you can redistribute it and/or
% modify it under the terms of the GNU Lesser General Public
% License as published by the Free Software Foundation; either
% version 3.0 of the License, or (at your option) any later version.
% This library is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
% Lesser General Public License for more details.
% You should have received a copy of the GNU Lesser General Public
% License along with this library.

classdef ConditionalWrapper < handle
    properties(Access=private)
        seq;
        cond;
    end
    methods
        function self = ConditionalWrapper(seq, cond)
            if isnumeric(cond)
                cond = cond ~= 0;
            end
            self.seq = seq;
            self.cond = cond;
        end

        % These are wrappers with additional condition added.
        % This allow the user to use the same function name with or without condition.
        function step = addStep(self, varargin)
            [step, end_time] = addStepReal(self.seq, self.cond, false, ...
                                           self.seq.curSeqTime, varargin{:});
            self.seq.curSeqTime = end_time;
            step.end_after_parent = false;
            if step.is_step
                step.totallen_after_parent = false;
            end
            self.seq.end_after_parent = true;
        end

        function step = addBackground(self, varargin)
            step = addStepReal(self.seq, self.cond, true, self.seq.curSeqTime, varargin{:});
        end

        function step = addFloating(self, varargin)
            step = addStepReal(self.seq, self.cond, false, nan, varargin{:});
        end

        function step = addAt(self, tp, varargin)
            step = addStepReal(self.seq, self.cond, true, ...
                               getTimePointOffset(self, tp), varargin{:});
        end

        function self = wait(self, t)
            waitWithCondition(self.seq, self.cond, t);
        end

        function step = add(self, name, pulse)
            step = addStepReal(self.seq, self.cond, true, self.seq.curSeqTime, ...
                               2 / self.seq.topLevel.time_scale); % addBackground
            add(step, name, pulse);
            step.end_after_parent = false;
            step.totallen_after_parent = false;
        end

        function wrapper = conditional(self, cond)
            wrapper = ConditionalWrapper(self.seq, self.cond & cond);
        end

        function wrapper = conditionalOr(self, cond)
            wrapper = ConditionalWrapper(self.seq, self.cond | cond);
        end
    end
end
