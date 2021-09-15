import zmq
from enum import Enum
import threading
from collections import deque
import array
import asyncio
import time

class ExptServer(object):
    class State(Enum):
        Init = 0
        Paused = 1
        Running = 2
    class WorkerRequest(Enum):
        NoRequest = 0
        Stop = 1
    class SeqRequest(Enum):
        NoRequest = 0
        Pause = 1
        Abort = 2
    class Transferer(object):
        class Request(object):
            class ReqType(Enum):
                Stop = 0
                SaveImgs = 1
                SeqEnd = 2
                SetConfig = 3
            def __init__(self, req_type, *args):
                self.type = req_type
                self.args = args
            def __bool__(self):
                return self.type == self.ReqType.Stop

        def __init__(self, parent):
            self.parent = parent
            self.__req_lock = threading.Lock()
            self.__data_lock = threading.Lock()
            self.__worker = threading.Thread(target = self.__worker_func)
            with self.__req_lock:
                self.reqs = deque()
            with self.__data_lock:
                self.imgs = deque()
                self.nseq = 0
                self.dateStamp = ""
                self.timeStamp = ""
                self.nseq_imgs = 0 # number of sequences of images stored
            self.__worker.start()
            self.temp_imgs = []

        def start(self):
            if hasattr(self, '__worker'):
                if self.__worker.is_active():
                    return
            self.__worker = threading.Thread(target = self.__worker_func)
            self.__worker.start()

        def add_req(self, req_type, *args):
            with self.__req_lock:
                self.reqs.appendleft(self.Request(req_type, *args))

        def stop(self):
            if hasattr(self, '__worker'):
                self.add_req(self.Request.ReqType.Stop)
                self.__worker.join()
            else:
                return

        def reset(self):
            self.stop()
            with self.__req_lock:
                self.reqs = deque()
            with self.__data_lock:
                self.imgs = deque()
                self.nseq = 0
                self.dateStamp = ""
                self.timeStamp = ""
                self.nseq_imgs = 0 # number of sequences of images stored
            self.temp_imgs = []
            self.start()

        def send_img_req(self, data):
            self.add_req(self.Request.ReqType.SaveImgs, data)

        def send_end_seq(self):
            self.add_req(self.Request.ReqType.SeqEnd)

        def send_set_config(self, date, time):
            self.add_req(self, Request.ReqType.SetConfig, date, time)

        def __check_worker_req(self) -> bool:
        # return True if need to stop
            with self.__req_lock:
                try:
                    res = self.reqs.pop()
                except:
                    res = None
            return res

        def pop_img(self):
            with self.__data_lock:
                try:
                    res = self.imgs.pop()
                except:
                    res = None
            return res

        def handle_req(self, req):
            if req.type == self.Request.ReqType.SaveImgs:
                self.temp_imgs.append(req.args[0])
            elif req.type == self.Request.ReqType.SeqEnd:
                with self.__data_lock:
                    self.nseq = self.nseq + 1
                    self.nseq_imgs = self.nseq_imgs + 1
                    for data in self.temp_imgs:
                        self.imgs.appendleft(data)
                    self.imgs.appendleft(b'')
                self.temp_imgs.clear()
            elif req_type == self.Request.ReqType.SetConfig:
                with self.__data_lock:
                    self.dateStamp = req.args[0]
                    self.timeStamp = req.args[1]
            else:
                print(f"Unknown request: {req.type}")
            self.__this_worker_req = None

        def __worker_func(self):
            req = self.__check_worker_req()
            while not req:
                if req is not None:
                    self.handle_req(req)
                time.sleep(0.2)
                req = self.__check_worker_req()
        # for other threads to extract information
        def get_seq_num(self) -> int:
            with self.__data_lock:
                return self.nseq
        def get_num_imgs(self) -> int:
            with self.__data_lock:
                return self.nseq_imgs
        def get_config(self):
            with self.__data_lock:
                return self.dateStamp, self.timeStamp

        def get_imgs(self, nseqs=-1):
            # nseqs = -1 gets all images currently stored
            # otherwise, get number of seqs specified by nseq.
            # this function will block, so other network requests may not be handled. Suggested usage, use nseqs=-1, or first get_num_imgs and only request that many
            # returns bytes to be sent across the network
            # intended format: [[shape_x: 4B, shape_y: 4B, nimgs: 4B, data: shape_x * shape_y * nimgs * bytes_per_pixel] x num_transfers_per_seq] [<0>:4B] x nseqs]
            # 0 separates out sequences
            n_transfer = 0
            res = bytearray()
            if nseqs < 0:
                nseqs = self.get_num_imgs()
            while n_transfer < nseqs:
                next_img = self.pop_img()
                while next_img != b'':
                    if next_img is None:
                        # more imgs are requested than actually are saved...
                        break
                    else:
                        res.extend(next_img.tobytes())
                    next_img = self.pop_img()
                res.extend(int.to_bytes(0, 4, 'little'))
                n_transfer = n_transfer + 1
            with self.__data_lock:
                self.nseq_imgs = self.nseq_imgs - n_transfer
            return res

    def recreate_sock(self):
        if self.__sock is not None:
            self.__sock.close()
        self.__sock = self.__ctx.socket(zmq.ROUTER)
        self.__sock.bind(self.__url)

    def __init__(self, url: str):
        # network
        self.__url = url
        self.__ctx = zmq.Context()
        self.__sock = None
        self.recreate_sock()
        self.timeout = 500

        # lock whenever accessing or changing state variables
        self.__data_lock = threading.Lock()
        # lock for worker request
        self.__worker_lock = threading.Lock()
        # lock for seq request
        self.__seq_lock = threading.Lock()
        # lock for expt imgs
        self.__expt_lock = threading.Lock()

        # worker. This worker will handle network requests
        with self.__worker_lock:
            self.__worker_req = self.WorkerRequest.NoRequest
        self.__worker = threading.Thread(target = self.__worker_func)
        self.__worker.start()

        # transferer
        #self.transferer = self.Transferer()
        with self.__expt_lock:
            self.expt_imgs = deque() # this deque is the one the expt thread uses.
        with self.__data_lock:
            self.imgs = deque()
            self.nseq = 0
            self.dateStamp = ""
            self.timeStamp = ""
            self.nseq_imgs = 0 # number of sequences of images stored
        self.temp_imgs = [] # stored mid sequence
        # status of seq
        with self.__seq_lock:
            self.__seq_req = self.SeqRequest.NoRequest
        with self.__data_lock:
            self.seq_status = self.State.Init

    def __del__(self):
        #self.transferer.stop()
        self.stop_worker()
        self.__sock.close()
        self.__ctx.destroy()

    def reset(self):
        #self.transferer.reset()
        self.stop_worker()
        self.recreate_sock()
        with self.__expt_lock:
            self.expt_imgs = deque() # this deque is the one the expt thread uses.
        with self.__data_lock:
            self.imgs = deque()
            self.nseq = 0
            self.dateStamp = ""
            self.timeStamp = ""
            self.nseq_imgs = 0 # number of sequences of images stored
        with self.__seq_lock:
            self.__seq_req = self.SeqRequest.NoRequest
        with self.__data_lock:
            self.seq_status = self.State.Init
        self.start_worker()

    def stop_worker(self):
        if hasattr(self, '__worker'):
            with self.__worker_lock:
                self.__worker_req = self.WorkerRequest.Stop
            self.__worker.join()
        else:
            return

    def start_worker(self):
        if hasattr(self, '__worker'):
            if self.__worker.is_active():
                return
        with self.__worker_lock:
            self.__worker_req = self.WorkerRequest.NoRequest
        self.__worker = threading.Thread(target = self.__worker_func)
        self.__worker.start()

    def handle_msg(self, addr,  msg_str: str) -> bool:
        # Method to handle different requests from external clients
        if msg_str == "pause_seq":
            rep = self.pause_seq()
            self.safe_send_string(addr, rep)
        elif msg_str == "abort_seq":
            rep = self.abort_seq()
            self.safe_send_string(addr, rep)
        elif msg_str == "start_seq":
            rep = self.start_seq_serv()
            self.safe_send_string(addr, rep)
        elif msg_str == "get_status":
            rep = self.get_status()
            self.safe_send_string(addr, rep)
            pass
        elif msg_str == "get_imgs":
            #msg = self.safe_recv()
            #if msg is None:
            #    rep = self.transferer.get_imgs()
            #else:
            #    rep = self.transferer.get_imgs(int.from_bytes(msg, 'little'))
            rep = self.get_imgs()
            self.safe_send(addr, rep)
        elif msg_str == "get_seq_num":
            rep = self.get_seq_num()
            self.safe_send(addr, rep.to_bytes(8, 'little'))
        elif msg_str == "get_num_imgs":
            rep = self.get_num_imgs()
            self.safe_send(addr, rep.to_bytes(8, 'little'))
        elif msg_str == "get_config":
            datestr, timestr = self.get_config()
            self.safe_send_string(addr, datestr, zmq.SNDMORE)
            self.send_string(time_str)
        else:
            #print(f"unknown {msg_str}")
            self.safe_send_string(addr, f'')
            return False
        return True

    def safe_receive(func):
        def f(self):
            try:
                msg = func(self)
            except:
                msg = None
            return  msg
        return f

    @safe_receive
    def safe_recv(self):
        return self.__sock.recv(zmq.NOBLOCK)

    @safe_receive
    def safe_recv_string(self):
        return self.__sock.recv_string(zmq.NOBLOCK)

    def finish_recv(func):
        def f(self, *args, **kwargs):
            # finish receiving messages
            msg = self.safe_recv()
            while msg is not None:
                msg = self.safe_recv()
            func(self, *args, **kwargs)
        return f

    @finish_recv
    def safe_send_string(self, addr, msg_str, flag=0):
        # send reply
        self.__sock.send(addr, zmq.SNDMORE)
        self.__sock.send(b'', zmq.SNDMORE)
        self.__sock.send_string(msg_str, flag)
        #print("Done sending")

    @finish_recv
    def safe_send(self, addr, msg, flag=0):
        # send reply
        self.__sock.send(addr, zmq.SNDMORE)
        self.__sock.send(b'', zmq.SNDMORE)
        self.__sock.send(msg, flag)

    def __check_worker_req(self):
        with self.__worker_lock:
            return self.__worker_req

    def __worker_func(self):
        # worker function
        while self.__check_worker_req != self.WorkerRequest.Stop:
            if self.__sock.poll(self.timeout) == 0: # in milliseconds
                continue
            addr = self.safe_recv()
            delimit = self.safe_recv_string()
            msg_str = self.safe_recv_string()
            if msg_str is None:
                self.safe_send_string(addr, "Send more")
            self.handle_msg(addr, msg_str)
        print("Worker finishing")

    # functions for either thread but mostly for the msg handler
    def pause_seq(self) -> str:
        with self.__data_lock:
            if self.seq_status == self.State.Running:
                self.seq_status = self.State.Paused
                with self.__seq_lock:
                    self.__seq_req = self.SeqRequest.Pause
                res = "Sequence Paused"
            else:
                res = "Sequence is not running"
        return res

    def abort_seq(self) -> str:
        with self.__data_lock:
            if self.seq_status == self.State.Running:
                self.seq_status = self.State.Init
                with self.__seq_lock:
                    self.__seq_req = self.SeqRequest.Abort
                res = "Sequence Aborted"
            else:
                res = "Sequence is not running"
        return res

    def get_status(self) -> str:
        with self.__data_lock:
            if self.seq_status == self.State.Init:
                res = "Sequence has not started"
            elif self.seq_status == self.State.Paused:
                res = "Sequence is paused"
            elif self.seq_status == self.State.Running:
                res = "Sequence is running"
            else:
                res = "Sequence status is unknown"
        return res

    def pop_img(self):
        with self.__data_lock:
            try:
                res = self.imgs.pop()
            except:
                res = None
        return res

    def get_seq_num(self) -> int:
        with self.__data_lock:
            return self.nseq

    def get_num_imgs(self) -> int:
        with self.__data_lock:
            return self.nseq_imgs

    def get_config(self):
        with self.__data_lock:
            return self.dateStamp, self.timeStamp

    def get_imgs(self):
        # returns bytes to be sent across the network
        # intended format: [[shape_x: 4B, shape_y: 4B, nimgs: 4B, data: shape_x * shape_y * nimgs * bytes_per_pixel] x num_transfers_per_seq] [<0>:4B] x nseqs]
        # 0 separates out sequences
        #n_transfer = 0
        res = bytearray()
        #if nseqs < 0:
        nseqs = self.get_num_imgs()
        #swap out. Assume self.imgs has been cleared out already
        with self.__data_lock:
            with self.__expt_lock:
                self.expt_imgs, self.imgs = self.imgs, self.expt_imgs
        while n_transfer < nseqs:
            next_img = self.pop_img()
            while next_img != b'':
                res.extend(next_img.tobytes())
                next_img = self.pop_img()
            res.extend(int.to_bytes(0, 4, 'little'))
            n_transfer = n_transfer + 1
        with self.__data_lock:
            self.nseq_imgs = self.nseq_imgs - n_transfer
        return res

    # this one is only for msg handler
    def start_seq_serv(self) -> str:
        with self.__data_lock:
            if self.seq_status == self.State.Paused:
                with self.__seq_lock:
                    self.__seq_req = self.SeqRequest.NoRequest
                res = "Sequence should now be running"
            else:
                res = "Sequence was not in Paused state. To start a new sequence, use the main MATLAB instance"
        return res

    # functions for the Expt thread
    def check_request(self):
        with self.__seq_lock:
            res = self.__seq_req
        return res

    def start_seq(self):
        with self.__data_lock:
            self.seq_status == self.State.Running

    def store_imgs(self, data):
        # need to make data an array, so tobytes can be called
        #self.transferer.send_img_req(data)
        self.temp_imgs.append(data)

    def seq_finish(self):
        #self.transferer.send_end_seq()
        with self.__data_lock:
            self.nseq = self.nseq + 1
            self.nseq_imgs = self.nseq_imgs + 1
            with self.__expt_lock:
                for data in self.temp_imgs:
                    self.imgs.appendleft(data)
                self.imgs.appendleft(b'')
        self.temp_imgs.clear()

    def set_config(self, date: str, time: str):
        with self.__data_lock:
            self.dateStamp = date
            self.timeStamp = time
