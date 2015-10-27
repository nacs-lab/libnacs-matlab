%% Copyright (c) 2014-2014, Yichao Yu <yyc1992@gmail.com>
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

classdef URLPoster < handle
  properties
    url_str;
    pyconn;
    pyglob;
  end

  methods
    function self = URLPoster(url_str)
      self.url_str = url_str;
      [path, ~, ~] = fileparts(mfilename('fullpath'));
      self.pyglob = py.dict(pyargs('mat_srcpath', path));
      py.exec('import sys; sys.path.append(mat_srcpath)', self.pyglob);
      py.exec('from URLPoster import URLPoster', self.pyglob);
    end

    function res = post(self, data, files)
      pylocal = py.dict(pyargs('url', self.url_str, ...
                               'data', py.dict(pyargs(data{:})), ...
                               'files', py.dict(pyargs(files{:}))));
      self.pyconn = py.eval('URLPoster(url, data, files)', ...
                            self.pyglob, pylocal);
      res = self.pyconn.post();
    end

    function output = reply(self)
      %% DO NOT REMOVE THE REPLY FUNCTION!!!!!!!!!!!!!!!!!!!!!!!!
      %% YOU HAVE ABSOLUTELY NO IDEA WHAT YOU ARE DOING IF YOU EVER THINK
      %% DOING THIS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      output = char(self.pyconn.reply());
    end
  end
end
