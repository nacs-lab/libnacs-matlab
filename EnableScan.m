%% Copyright (c) 2018-2018, Yichao Yu <yyc1992@gmail.com>
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

classdef EnableScan < FacyOnCleanup
    methods
        function self = EnableScan(enable)
            function cb(old)
                EnableScan.set(old);
            end
            self = self@FacyOnCleanup(@cb, EnableScan.check());
            EnableScan.set(enable);
        end
    end
    methods(Static, Access=private)
        % Workaround matlab not allow static non-const properties
        % so we have to use a presistent variable instead.
        function res = setget(val)
            persistent enabled;
            if exist('val', 'var')
                enabled = logical(val);
            elseif isempty(enabled)
                enabled = true;
            end
            res = enabled;
        end
    end
    methods(Static)
        function res = check()
            res = EnableScan.setget();
        end
        % Only for testing, use the scoped version (`EnableScan(val)`) instead.
        function set(enable)
            EnableScan.setget(enable);
        end
    end
end
