classdef FacyOnCleanup < handle
    % The class name is presented to you by Logitech
    properties
        cb;
        args;
        enable = 1;
    end
    methods
        function self=FacyOnCleanup(cb, varargin)
            self.cb = cb;
            self.args = varargin;
        end
        function disable(self)
            self.enable = 0;
        end
        function delete(self)
            if self.enable
                self.cb(self.args{:});
            end
        end
    end
end
