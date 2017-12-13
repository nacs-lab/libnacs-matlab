# Copyright (c) 2014-2014, Yichao Yu <yyc1992@gmail.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 3.0 of the License, or (at your option) any later version.
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
# You should have received a copy of the GNU Lesser General Public
# License along with this library.

import requests
from http import client as http_client

try:
    import urlparse
except ImportError:
    import urllib.parse as urlparse

class URLPoster(object):
    def __init__(self, url, data=None, files=None):
        self.__url = url
        o = urlparse.urlparse(url)
        if o.scheme == 'https':
            self.__conn = http_client.HTTPSConnection(o.netloc)
        else:
            self.__conn = http_client.HTTPConnection(o.netloc)

    def post(self, data, files):
        req = requests.Request('POST', self.__url, data=data,
                               files=files).prepare()
        self.__conn.request('POST', self.__url, body=req.body,
                            headers=req.headers)

    def reply(self):
        res = self.__conn.getresponse()
        if res.status != 200:
            # TODO use appropriate error
            raise RuntimeError("HTTP error %d" % res.status)
        return res.read().decode('utf-8', 'ignore')
