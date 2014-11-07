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

classdef nacsLogger < handle
  properties(Hidden, Access=protected)
    fd = -1;
  end

  methods
    function self = nacsLogger(name)
      global nacsLogDir
      nacsConfig();
      log_dir = fullfile(nacsLogDir, datestr(now, 'yyyy-mm-dd'));
      if ~isdir(log_dir)
        mkdir(log_dir);
      end

      if nargin < 1
        name = 'nacs-log';
      end
      timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
      fname = [name, '-', timestamp, '.log'];
      fpath = fullfile(log_dir, fname);

      self.fd = fopen(fpath, 'a');
    end

    function delete(self)
      if self.fd >= 0
        fclose(self.fd);
      end
    end

    function logf(self, fmt, varargin)
      fmt = [fmt, '\n'];
      fprintf(self.fd, fmt, varargin{:});
    end

    function log(self, s)
      self.logf('%s', s);
    end
  end
end
