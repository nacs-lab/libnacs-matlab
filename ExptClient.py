import zmq
import array

class ExptClient(object):
    def recreate_sock(self):
        if self.__sock is not None:
            self.__sock.close()
        self.__sock = self.__ctx.socket(zmq.REQ) # Request socket
        self.__sock.setsockopt(zmq.LINGER, 0) # discards messages when socket is closed
        self.__sock.connect(self.__url)
    def __init__(self, url):
        self.__url = url
        self.__ctx = zmq.Context()
        self.__sock = None
        self.recreate_sock()
    def __del__(self):
        self.__sock.close()
        self.__ctx.destroy()
    def send_imgs(self, imgdata, shape):
        shape_to_send = shape.tobytes()
        data_to_send = imgdata.tobytes()
        self.__sock.send_string("images", zmq.SNDMORE)
        self.__sock.send(shape_to_send, zmq.SNDMORE)
        return self.__sock.send(data_to_send)
    def recv_reply(self):
        timeout = 1 * 1000 # in milliseconds
        if self.__sock.poll(timeout) == 0:
            return
        return int.from_bytes(self.__sock.recv(), byteorder = 'little')
    def send_end_seq(self):
        return self.__sock.send_string("end_seq")
    def send_config(self, n_per_group, n_images_per_seq):
        self.__sock.send_string("config", zmq.SNDMORE)
        self.__sock.send(n_per_group.to_bytes(4, byteorder='little'), zmq.SNDMORE)
        self.__sock.send(n_images_per_seq.to_bytes(4, byteorder='little'))
    def wait_reply(self):
        timeout = 1 * 1000
        if self.__sock.poll(timeout) == 0:
            return False
        self.__sock.recv()
        return True
