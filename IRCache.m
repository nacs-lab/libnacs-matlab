%% Copyright (c) 2017-2018, Yichao Yu <yyc1992@gmail.com>
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

classdef (Sealed) IRCache < handle
    properties
        dict
    end
    methods(Access = private)
        function self = IRCache()
            self.dict = containers.Map();
        end
    end
    methods
        function clear(self)
            self.dict = containers.Map();
        end
        function ir = getindex(self, id)
            dict = self.dict;
            if isKey(dict, id)
                ir = dict(id);
            else
                ir = int32([]);
            end
        end
        function ir = setindex(self, ir, id)
            self.dict(id) = ir;
        end
    end
    methods(Static)
        function self = get()
            global nacsIRCache
            if isempty(nacsIRCache)
                delete(nacsIRCache);
                nacsIRCache = IRCache();
            end
            self = nacsIRCache;
        end
    end
end
