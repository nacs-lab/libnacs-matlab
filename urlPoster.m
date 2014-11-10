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

%% This file incorporates work covered by the following copyright and
%% permission notice:

%%   URLREADWRITE A helper function for URLREAD and URLWRITE.
%%     Matthew J. Simoneau, June 2005
%%     Copyright 1984-2007 The MathWorks, Inc.
%%     $Revision: 1.1.6.3.6.1 $ $Date: 2009/01/30 22:37:42 $

%%   2010-04-07 Dan Ellis dpwe@ee.columbia.edu
%%   Copyright (c) 2010, Dan Ellis
%%   All rights reserved.

%%   Redistribution and use in source and binary forms, with or without
%%   modification, are permitted provided that the following conditions are
%%   met:

%%       * Redistributions of source code must retain the above copyright
%%         notice, this list of conditions and the following disclaimer.
%%       * Redistributions in binary form must reproduce the above copyright
%%         notice, this list of conditions and the following disclaimer in
%%         the documentation and/or other materials provided with the
%%         distribution
%%       * Neither the name of the Columbia University nor the names
%%         of its contributors may be used to endorse or promote products
%            derived from this software without specific prior written
%            permission.

%%   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
%%   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
%%   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
%%   PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
%%   OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
%%   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
%%   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
%%   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
%%   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
%%   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
%%   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

classdef urlPoster < handle
  properties(Access=private)
    conn = [];
    url_str;
  end

  methods(Static, Access=private)
    function setup()
      if ~usejava('jvm')
        error('urlPoster requires Java.');
      end

      %% Be sure the proxy settings are set.
      com.mathworks.mlwidgets.html.HTMLPrefs.setProxySettings();
    end
  end

  methods
    function self = urlPoster(url_str)
      urlPoster.setup();

      self.url_str = url_str;

      %% Determine the protocol (before the ":").
      protocol = url_str(1:min(find(url_str == ':')) - 1);

      %% Try to use the native handler, not the ice.* classes.
      switch protocol
        case 'http'
          try
            handler = sun.net.www.protocol.http.Handler;
          catch
            handler = [];
          end
        case 'https'
          try
            handler = sun.net.www.protocol.https.Handler;
          catch
            handler = [];
          end
        otherwise
          handler = [];
      end

      %% Create the URL object.
      try
        if isempty(handler)
          url = java.net.URL(url_str);
        else
          url = java.net.URL([], url_str, handler);
        end
      catch
        error(['Either this URL could not be parsed or ', ...
               'the protocol is not supported.']);
      end

      %% Get the proxy information using MathWorks facilities for unified proxy
      %% prefence settings.
      import com.mathworks.net.transport.MWTransportClientPropertiesFactory;
      mwtcp = MWTransportClientPropertiesFactory.create();
      proxy = mwtcp.getProxy();

      %% Open a connection to the URL.
      if isempty(proxy)
        self.conn = url.openConnection();
      else
        self.conn = url.openConnection(proxy);
      end
    end

    function post(self, params, fname)
      self.conn.setDoOutput(true);
      boundary = '***********************';
      self.conn.setRequestProperty('Content-Type', ...
                                   ['multipart/form-data; boundary=', ...
                                    boundary]);
      txt_stm = java.io.PrintStream(self.conn.getOutputStream());
      %% also create a binary stream
      data_stm = java.io.DataOutputStream(self.conn.getOutputStream());

      eol = [char(13), char(10)];
      %% TR: added header line, which was not arriving otherwise
      txt_stm.print(['Content-Type: multipart/form-data; boundary=', ...
                     boundary, eol, eol]);

      for i = 1:2:length(params)
        txt_stm.print(['--', boundary, eol]);
        txt_stm.print(['Content-Disposition: form-data; name="', ...
                       params{i}, '"']);
        if ~ischar(params{i + 1})
          %% binary data is uploaded as an octet stream
          %% Echo Nest API demands a filename in this case
          txt_stm.print(['; filename="', fname, '"', eol]);
          txt_stm.print(['Content-Type: application/octet-stream', eol]);
          txt_stm.print([eol]);
          data_stm.write(params{i + 1}, 0, length(params{i + 1}));
          txt_stm.print([eol]);
        else
          txt_stm.print([eol]);
          txt_stm.print([eol]);
          txt_stm.print([params{i + 1}, eol]);
        end
      end
      txt_stm.print(['--', boundary, '--', eol]);
      txt_stm.close();
      data_stm.close();
    end

    function [output, status] = reply(self)
      %% Read the data from the connection.
      import com.mathworks.mlwidgets.io.InterruptibleStreamCopier;
      try
        istm = self.conn.getInputStream();
        ostm = java.io.ByteArrayOutputStream();
        %% This StreamCopier is unsupported and may change at any time.
        isc = InterruptibleStreamCopier.getInterruptibleStreamCopier();
        isc.copyStream(istm, ostm);
        istm.close();
        ostm.close();
        output = native2unicode(typecast(ostm.toByteArray', ...
                                         'uint8'), 'UTF-8');
      catch
        error(['Error downloading URL. Your network connection may be ', ...
               'down or your proxy settings improperly configured.']);
      end
      status = 1;
    end
  end
end
