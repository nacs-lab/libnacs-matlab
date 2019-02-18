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

classdef WavemeterParser < handle
    properties
        parser;
    end

    methods
        function self = WavemeterParser(varargin)
            pyglob = py.dict();
            py.exec('from libnacs.wavemeter import WavemeterParser', pyglob);
            wp = py.eval('WavemeterParser', pyglob);
            self.parser = wp(varargin{:});
        end
        function [t, d] = parse(self, name, varargin)
            res = self.parser.parse(name, varargin{:});
            t = double(res{1});
            d = double(res{2});
        end
    end
end
