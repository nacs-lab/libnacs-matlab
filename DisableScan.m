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

classdef DisableScan < FacyOnCleanup
    methods
        function self=DisableScan()
            function cb(old)
                DisableScan.set(old);
            end
            self = self@FacyOnCleanup(@cb, DisableScan.check());
            DisableScan.set(1);
        end
    end
    methods(Static)
        function res=check()
            global nacsDisableScan;
            if isempty(nacsDisableScan)
                res = 0;
            else
                res = nacsDisableScan;
            end
        end
        function set(disable)
            global nacsDisableScan;
            nacsDisableScan = disable;
        end
    end
end
