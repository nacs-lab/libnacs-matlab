import nidaqmx
from nidaqmx.constants import AcquisitionType, TaskMode, Signal, Edge
from nidaqmx import stream_writers as writers
from nidaqmx import stream_readers as readers
import numpy as np
import time
import sys


def initDAQ(devNum = 0):
    #Check NI DAQ device is connected and return device handle
    #Arguments:
    #    devNum: the number of the NI DAQ device to connect to. If only connected
    #        device, devNum = 0, otherwise number in order of connections

    system = nidaqmx.system.System.local()
    devs = system.devices
    try:
        daq = system.devices[devNum]
        return daq
    except IndexError as err:
        print("No DAQ number ",devNum)
        raise 0
    except Exception as err:
         raise err

def acquire(devNum,channelName, sampleRate,sampleTime, bTrig = 0, trigChan = "PFI0"):
    #Record voltage input on channel ai0 for a fixed time
    #Arguments:
    #    devNum: the number of the NI DAQ device to connect to.
    #   channelName: The name of the channel to read from, e.g. "ai0"
    #   sampleTime: total time for which to acquire signal (in s)
    #   sampleRate: NI DAQ sample rate (in Hz)
    #   bTrig: bool, 1 to use trigger on PFI0, 0 otherwise


    #Check NI DAQ connected and reset
    try:
         daq = initDAQ(devNum)
    except IndexError:
         print("No NI DAQ device connected")
         raise SystemExit
    except Exception:
         print("Unknown Error")
         raise SystemExit
    with nidaqmx.Task() as task:
        channelAddr = "Dev%d/%s" % (devNum+1,channelName)
        task.ai_channels.add_ai_voltage_chan(channelAddr)

        #Record a fixed number of samples on ai0 then return
        nSamples = int(sampleTime*sampleRate)
        task.timing.cfg_samp_clk_timing(sampleRate, sample_mode=AcquisitionType.FINITE, samps_per_chan=nSamples)
        if bTrig:
            task.triggers.start_trigger.cfg_dig_edge_start_trig(trigChan, Edge.RISING)

        task.start()
        samples = task.read(number_of_samples_per_channel=nSamples, timeout = 1.5*sampleTime)

    return samples

def getSerial(devNum):
    #Return the serial number for device number devNum
    daq = initDAQ(devNum)
    if daq == 0:
        return 0
    return daq.dev_serial_num

def numDevices():
    system = nidaqmx.system.System.local()
    devs = system.devices
    return len(devs)
