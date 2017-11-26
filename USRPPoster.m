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
      try
        self.poster.post(data);
        while 1
          res = self.poster.post_reply();
          if res ~= 0
            return
          end
        end
      catch ex
        self.poster.recreate_sock();
        rethrow(ex);
      end
    end

    function wait(self, id)
      try
        self.poster.wait_send(id)
        while ~self.poster.wait_reply()
        end
      catch ex
        self.poster.recreate_sock();
        rethrow(ex);
      end
    end
  end
end
