from AnalysisClient import AnalysisClient
from enum import Enum
import time
import threading
from collections import deque

class AnalysisUser(object):
    class WorkerRequest(Enum):
        NoRequest = 0
        Stop = 1
        PauseSeq = 2
        AbortSeq = 3
        StartSeq = 4

    class SeqStatus(Enum):
        Stopped = 0
        Running = 1
        Paused = 2
        Unknown = 3

    def __init__(self, url: str):
        # lock
        self.__data_lock = threading.Lock()
        #elf.__user_lock = threading.Lock()
        self.__worker_lock = threading.Lock()

        self.AC = AnalysisClient(url)

        # deque for imgs
        #with self.__user_lock:
        self.user_imgs = [] # deque that is swapped with deque populated by worker
        with self.__data_lock:
            self.seq_status = None
            self.seq_num = None
            self.refresh_rate = 60 # in seconds
            self.imgs = []
            self.config = None
            self.msg = None

        self.last_time = 0

        # worker. Worker will tell AnalysisClient what to do, which is going to going to grab images automatically when sequence is running
        with self.__worker_lock:
            self.__worker_reqs = deque()
        self.__worker = threading.Thread(target = self.__worker_func)
        self.__worker.start()

    def __del__(self):
        self.stop_worker()

    def stop_worker(self):
        if hasattr(self, '__worker'):
            with self.__worker_lock:
                self.__worker_reqs.appendleft(self.WorkerRequest.Stop)
            self.__worker.join()
        else:
            return

    def start_worker(self):
        if hasattr(self, '__worker'):
            if self.__worker.is_active():
                return
        with self.__worker_lock:
            self.__worker_reqs = deque()
        self.__worker = threading.Thread(target = self.__worker_func)
        self.__worker.start()

    def reset_client(self):
        with self.__AC_lock:
            self.AC.recreate_sock()

    def __pop_worker_req(self):
        with self.__worker_lock:
            try:
                res = self.__worker_reqs.pop()
            except:
                res = self.WorkerRequest.NoRequest
        return res

    def __send_worker_req(self, req):
        with self.__worker_lock:
            self.__worker_reqs.appendleft(req)

    def __handle_req(self, req):
        msg = None
        if req == self.WorkerRequest.NoRequest:
            time.sleep(0.1)
        elif req == self.WorkerRequest.PauseSeq:
            msg = self.AC.pause_seq()
            msg = msg[0]
            self.__update()
        elif req == self.WorkerRequest.AbortSeq:
            msg = self.AC.abort_seq()
            msg = msg[0]
            self.__update()
        elif req == self.WorkerRequest.StartSeq:
            msg = self.AC.start_seq()
            msg = msg[0]
            self.__update()
        if msg is not None:
            self.__set_msg(msg)

    def __update_status(self):
        # get status
        status = self.AC.get_status()
        if status[0] == "Sequence is stopped":
            state = self.SeqStatus.Stopped
        elif status[0] == "Sequence is paused":
            state = self.SeqStatus.Paused
        elif status[0] == "Sequence is running":
            state = self.SeqStatus.Running
        else:
            state = self.SeqStatus.Unknown
        self.__set_status(state)
        self.__set_msg(status)
        return state

    def __update(self):
        # this function runs every refresh rate, and can also be called on its own
        # get imgs
        new_imgs = self.AC.get_imgs(10000)
        if new_imgs is not None:
            with self.__data_lock:
                self.imgs.append(new_imgs)
        # get nseq
        nseq = self.AC.get_seq_num()
        if nseq is not None:
            with self.__data_lock:
                self.seq_num = nseq

    def check_status(self):
        with self.__data_lock:
            return self.seq_status

    def __set_status(self, status):
        if status is None:
            return
        with self.__data_lock:
            self.seq_status = status

    def check_msg(self):
        with self.__data_lock:
            return self.msg

    def __set_msg(self, msg):
        with self.__data_lock:
            self.msg = msg

    def __worker_func(self):
        req = self.__pop_worker_req()
        last_state = self.check_status()
        while req != self.WorkerRequest.Stop:
            cur_time = time.time()
            if cur_time - self.last_time >= self.refresh_rate:
                # __update status. Cached status, in principle is good enough, but this is mainly to protect against stopping of the sequence that this thread does not know about
                state = self.__update_status()
                if state == self.SeqStatus.Stopped or state == self.SeqStatus.Paused:
                    if last_state != state:
                        # sequence status has changed
                        self.__update()
                    # TODO, IF SEQUENCE HAS STOPPED
                elif state == self.SeqStatus.Running:
                    # TODO, IF SEQUENCE JUST STARTED RUNNING
                    self.__update()
                #last_state = state
                self.last_time = cur_time
            self.__handle_req(req)
            last_state = self.__update_status()
            req = self.__pop_worker_req()

    def pop_img(self):
        try:
            res = self.user_imgs.pop()
        except:
            res = None
        return res

    #functions for main thread to extract data
    def grab_imgs(self):
        # get cached
        # assumes self.user_imgs is cleared already
        with self.__data_lock:
            self.user_imgs, self.imgs = self.imgs, self.user_imgs
        res = self.user_imgs.copy()
        self.user_imgs.clear()
        return res

    def set_refresh_rate(self, val):
        with self.__data_lock:
            self.refresh_rate = val

    def get_seq_num(self):
        # get cached
        pass

    def get_config(self):
        pass

    def get_status(self):
        with self.__data_lock:
            return self.seq_status.value

    def pause_seq(self):
        self.__send_worker_req(self.WorkerRequest.PauseSeq)

    def abort_seq(self):
        self.__send_worker_req(self.WorkerRequest.AbortSeq)

    def start_seq(self):
        self.__send_worker_req(self.WorkerRequest.StartSeq)
