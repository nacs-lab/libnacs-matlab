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
from threading import Thread

class URLPoster(object):
    def __init__(self, url, data=None, files=None):
        self.__url = url
        self.__data = data
        self.__files = files
        self.__except = None

    def __post(self):
        try:
            self.__reply = requests.post(self.__url, data=self.__data,
                                         files=self.__files)
        except Exception as e:
            self.__except = e

    def post(self):
        self.__t = Thread(target=self.__post)
        self.__t.start()

    def reply(self):
        self.__t.join()
        if self.__except is not None:
            raise self.__except
        if self.__reply.status_code != 200:
            # TODO use appropriate error
            raise RuntimeError("HTTP error %d" % self.__reply.status_code)
        return self.__reply.text
