%% Copyright (c) 2017-2017, Yichao Yu <yyc1992@gmail.com>
%%
%% This library is free software; you can redistribute it and/or
%% modify it under the terms of the GNU Lesser General Public
%% License as published by the Free Software Foundation; either
%% version 3.0 of the License, or (at your option) any later version.
%% This library is distributed in the hope that it will be useful,
%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
%% Lesser General Public License for more details.
%% You should have received a copy of the GNU Lesser General Public
%% License along with this library.

classdef USRPPoster < handle
  properties
    pyglob;
    poster;
  end

  methods
    function self = USRPPoster(url)
      [path, ~, ~] = fileparts(mfilename('fullpath'));
      self.pyglob = py.dict(pyargs('mat_srcpath', path, ...
                                   'usrp_url', url));
      py.exec('import sys; sys.path.append(mat_srcpath)', self.pyglob);
      py.exec('from USRPPoster import USRPPoster', self.pyglob);
      self.poster = py.eval('USRPPoster(usrp_url)', self.pyglob);
    end

    function res = post(self, data)
      res = self.poster.post(data);
    end

    function wait(self, id)
      while ~self.poster.wait(id)
      end
    end
  end
end
