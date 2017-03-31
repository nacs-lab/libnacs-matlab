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
