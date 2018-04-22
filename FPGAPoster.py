# Copyright (c) 2018-2018, Yichao Yu <yyc1992@gmail.com>
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

import zmq
import libnacs

class FPGAPoster(object):
    def recreate_sock(self):
        self.__sock = self.__ctx.socket(zmq.REQ)
        self.__sock.connect(self.__url)

    def __init__(self, url):
        self.__url = url
        self.__ctx = zmq.Context()
        self.recreate_sock()

    def __del__(self):
        self.__ctx.destroy()

    def prepare_msg(self, tlen, code):
        bc = int(tlen).to_bytes(8, byteorder='little', signed=False)
        code, mask = libnacs.bin_to_bytecode(code)
        bc += int(mask).to_bytes(4, byteorder='little', signed=False)
        bc += code
        return bc

    def post(self, data):
        self.__sock.send_string("run_seq", zmq.SNDMORE)
        self.__sock.send(b'\1\0\0\0', zmq.SNDMORE) # version
        self.__sock.send(data)

    def post_reply(self):
        if self.__sock.poll(1000) == 0:
            return False
        self.__sock.recv()
        return True
