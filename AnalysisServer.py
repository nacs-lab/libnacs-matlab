import zmq
import array

class AnalysisServer(object):
    def recreate_sock(self):
        if self.__sock is not None:
            self.__sock.close()
        self.__sock = self.__ctx.socket(zmq.REP) # Reply socket
        self.__sock.setsockopt(zmq.LINGER, 0) # discards messages when socket is closed
        self.__sock.bind(self.__url)
    def __init__(self, url):
        self.__url = url
        self.__ctx = zmq.Context()
        self.__sock = None
        self.recreate_sock()
    def __del__(self):
        self.__sock.close()
        self.__ctx.destroy()
    def recv_info(self):
        timeout = 1 * 1000 # in milliseconds
        if self.__sock.poll(timeout) == 0:
            return
        return self.__sock.recv_string()
    def recv_imgs(self):
        timeout = 1 * 1000 # in milliseconds
        if self.__sock.poll(timeout) == 0:
            return
        shape = array.array('d', self.__sock.recv())
        imgdata = array.array('d', self.__sock.recv())
        return [shape, imgdata]
    def recv_config(self):
        timeout = 1 * 1000 # in milliseconds
        if self.__sock.poll(timeout) == 0:
            return
        #n_per_group = int.from_bytes(self.__sock.recv(), byteorder = 'little')
        #n_images_per_seq = int.from_bytes(self.__sock.recv(), byteorder = 'little')
        #return [n_per_group, n_images_per_seq]
        dateStamp = self.__sock.recv_string();
        timeStamp = self.__sock.recv_string();
        return [dateStamp, timeStamp]
    def recv_end_seq(self):
        timeout = 1 * 1000 # in milliseconds
        if self.__sock.poll(timeout) == 0:
            return
        return int.from_bytes(self.__sock.recv(), byteorder = 'little')
    def send_go(self):
        return self.__sock.send(int(1).to_bytes(1, byteorder = 'little'))
    def send_stop(self):
        return self.__sock.send(int(0).to_bytes(1, byteorder = 'little'))
