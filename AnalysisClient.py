import zmq
import array

class AnalysisClient(object):
    def recreate_sock(self):
        if self.__sock is not None:
            self.__sock.close()
        self.__sock = self.__ctx.socket(zmq.REQ)
        self.__sock.connect(self.__url)

    def __init__(self, url: str):
        # network
        self.__url = url
        self.__ctx = zmq.Context()
        self.__sock = None
        self.recreate_sock()
        self.timeout = 500

    # decorators for polling
    def poll_recv(func):
        def f(self, timeout=1000, flag=0):
            try:
                func(self)
            except:
                pass
            if self.__sock.poll(timeout) == 0:
                rep = None
            else:
                rep = self.__sock.recv(flag)
            return rep
        return f

    def poll_recv_string(func):
        def f(self, timeout=1000, flag=0): #timeout in milliseconds
            try:
                func(self)
            except:
                pass
            if self.__sock.poll(timeout) == 0:
                rep = None
            else:
                rep = self.__sock.recv_string(flag)
            return [rep]
        return f

    # decorators for poll_recv
    def convert_to_array(func):
        def f(self, *args, **kwargs):
            rep = func(self, *args, **kwargs)
            data = None
            if rep is not None:
                data = array.array('d', rep)
            return data
        return f

    def convert_to_int(func):
        def f(self, *args, **kwargs):
            rep = func(self, *args, **kwargs)
            data = None
            if rep is not None:
                data = int.from_bytes(rep, 'little')
            return data
        return f

    def recv_more_string(func):
        def f(self, *args, **kwargs):
            rep = func(self, *args, **kwargs)
            data = None
            if rep is not None:
                try:
                    new_rep = self.__sock.recv_string(zmq.NOBLOCK)
                except:
                    new_rep = f''
                data = rep + [new_rep]
            return data
        return f

    @poll_recv_string
    def pause_seq(self):
        self.__sock.send_string("pause_seq")

    @poll_recv_string
    def abort_seq(self):
        self.__sock.send_string("abort_seq")

    @poll_recv_string
    def start_seq(self):
        self.__sock.send_string("start_seq")

    @poll_recv_string
    def get_status(self):
        self.__sock.send_string("get_status")

    @convert_to_array
    @poll_recv
    def get_imgs(self):
        self.__sock.send_string("get_imgs")

    @convert_to_int
    @poll_recv
    def get_seq_num(self):
        self.__sock.send_string("get_seq_num")

    @convert_to_int
    @poll_recv
    def get_num_imgs(self):
        self.__sock.send_string("get_num_imgs")

    @recv_more_string
    @poll_recv_string
    def get_config(self):
        self.__sock.send_string("get_config")
