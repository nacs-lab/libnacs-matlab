import nidaqmx
from nidaqmx.constants import AcquisitionType, TaskMode, Signal, Edge
from nidaqmx.stream_writers import AnalogSingleChannelWriter
from nidaqmx import stream_writers as writers
from nidaqmx import stream_readers as readers
import numpy as np
import time
import sys,code,time,scipy,pickle
import matplotlib.pyplot as plt
from concurrent.futures import ThreadPoolExecutor

def doAThing():
    print("Did a thing.")



def saveVariable(variable, fileName,desciption="No Description Given"):
    f=open(fileName,"wb")
    pickle.dump([variable,desciption],f)
    f.close()

def loadVariable(fileName):
    f = open(fileName,"rb")
    output,description=pickle.load(f)
    f.close()
    return output

def initDAQ(devNum = 0):
    #Check NI DAQ device is connected and return device handle
    #Arguments:
    #    devNum: the number of the NI DAQ device to connect to. If only connected
    #        device, devNum = 0, otherwise number in order of connections
    devNum = int(devNum)
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

def dcoutNow(devNum,channelName,voltage,bTrig = 0, trigChan = "PFI0",fileName="MostRecentOutputVoltageOn"):
    bTrig = int(bTrig)
    devNum = int(devNum)
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
        fileName=fileName+str(devNum+1)+channelName+".pkl"
        task.ao_channels.add_ao_voltage_chan(channelAddr)

        task.timing.cfg_samp_clk_timing(rate=2, sample_mode=AcquisitionType.FINITE, samps_per_chan=2)

        if bTrig:
            task.triggers.start_trigger.cfg_dig_edge_start_trig(trigChan, Edge.RISING)

        writer=AnalogSingleChannelWriter(task.out_stream,auto_start=False)
        samples=np.ones(2)*voltage
        writer.write_many_sample(samples)
        task.start()
        if bTrig:
            task.wait_until_done()
        saveVariable(voltage,fileName,"Most Recent Output Voltage on "+channelAddr)
    return 0
def arbitraryoutNow(devNum,channelName,voltagelist,outputRate,outputTime,bTrig = 0, trigChan = "PFI0"):
    devNum=int(devNum)
    outputRate=int(outputRate)
    bTrig=int(bTrig)
    assert len(voltagelist)==int(outputRate*outputTime)

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
        task.ao_channels.add_ao_voltage_chan(channelAddr)
        nsamples=int(outputRate*outputTime)
        task.timing.cfg_samp_clk_timing(rate=outputRate, sample_mode=AcquisitionType.FINITE, samps_per_chan=nsamples)

        if bTrig:
            task.triggers.start_trigger.cfg_dig_edge_start_trig(trigChan, Edge.RISING)

        writer=AnalogSingleChannelWriter(task.out_stream,auto_start=False)
        writer.write_many_sample(voltagelist)
        task.start()
        task.wait_until_done()
def acquireNow(devNum,channelName, sampleRate,sampleTime, bTrig = 0, trigChan = "PFI0",fileName="MostRecentVoltageReading"):
    #Record voltage input on channel ai0 for a fixed time
    #Arguments:
    #    devNum: the number of the NI DAQ device to connect to.
    #   channelName: The name of the channel to read from, e.g. "ai0"
    #   sampleTime: total time for which to acquire signal (in s)
    #   sampleRate: NI DAQ sample rate (in Hz)
    #   bTrig: bool, 1 to use trigger on PFI0, 0 otherwise


    #Check NI DAQ connected and reset
    devNum = int(devNum)
    bTrig = int(bTrig)
    sampleRate = int(sampleRate)
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
        fileName=fileName+str(devNum+1)+channelName+".pkl"
        task.ai_channels.add_ai_voltage_chan(channelAddr)

        #Record a fixed number of samples on ai0 then return
        nSamples = int(sampleTime*sampleRate)
        task.timing.cfg_samp_clk_timing(sampleRate, sample_mode=AcquisitionType.FINITE, samps_per_chan=nSamples)
        if bTrig:
            task.triggers.start_trigger.cfg_dig_edge_start_trig(trigChan, Edge.RISING)

        task.start()
        
        if bTrig:
            task.wait_until_done(timeout=30)
        samples = task.read(number_of_samples_per_channel=nSamples, timeout = 1.5*sampleTime)
    saveVariable(samples,fileName,"Most Recent Voltage Reading on "+channelAddr)
    return samples

def dcoutDelayed(taskName,devNum,channelName,voltage,bTrig = 0, trigChan = "PFI0"):
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
        fileName=fileName+str(devNum+1)+channelName+".pkl"
        task.ao_channels.add_ao_voltage_chan(channelAddr)

        task.timing.cfg_samp_clk_timing(rate=2, sample_mode=AcquisitionType.FINITE, samps_per_chan=2)

        if bTrig:
            task.triggers.start_trigger.cfg_dig_edge_start_trig(trigChan, Edge.RISING)

        writer=AnalogSingleChannelWriter(task.out_stream,auto_start=False)
        samples=np.ones(2)*voltage
        writer.write_many_sample(samples)
        task.start()
        task.save(save_as=taskName,overwrite_existing_task=True)
def arbitraryoutDelayed(taskName,devNum,channelName,voltagelist,outputRate,outputTime,bTrig = 0, trigChan = "PFI0"):
    devNum = int(devNum)
    outputRate = int(outputRate)
    bTrig = int(bTrig)
    
    assert len(voltagelist)==int(outputRate*outputTime)

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
        task.ao_channels.add_ao_voltage_chan(channelAddr)
        nsamples=int(outputRate*outputTime)
        task.timing.cfg_samp_clk_timing(rate=outputRate, sample_mode=AcquisitionType.FINITE, samps_per_chan=nsamples)

        if bTrig:
            task.triggers.start_trigger.cfg_dig_edge_start_trig(trigChan, Edge.RISING)

        writer=AnalogSingleChannelWriter(task.out_stream,auto_start=False)
        writer.write_many_sample(voltagelist)
        task.start()
        task.save(save_as=taskName,overwrite_existing_save=True)
def acquireDelayed(taskName,devNum,channelName, sampleRate,sampleTime, bTrig = 0, trigChan = "PFI0",fileName="MostRecentVoltageReading"):
    #Record voltage input on channel ai0 for a fixed time
    #Arguments:
    #    devNum: the number of the NI DAQ device to connect to.
    #   channelName: The name of the channel to read from, e.g. "ai0"
    #   sampleTime: total time for which to acquire signal (in s)
    #   sampleRate: NI DAQ sample rate (in Hz)
    #   bTrig: bool, 1 to use trigger on PFI0, 0 otherwise


    #Check NI DAQ connected and reset
    devNum = int(devNum)
    sampleRate = int(sampleRate)
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
        fileName=fileName+str(devNum+1)+channelName+".pkl"
        task.ai_channels.add_ai_voltage_chan(channelAddr)

        #Record a fixed number of samples on ai0 then return
        nSamples = int(sampleTime*sampleRate)
        task.timing.cfg_samp_clk_timing(sampleRate, samps_per_chan=nSamples,sample_mode=nidaqmx.constants.AcquisitionType.FINITE)
        if bTrig:
            task.triggers.start_trigger.cfg_dig_edge_start_trig(trigChan, Edge.RISING)
        else:
            task.start()
        #task.save(save_as=taskName,overwrite_existing_task=True)
        return task

def readOutTask(taskName,nSamples):
    nSamples = int(nSamples)
    task=nidaqmx.system.storage.persisted_task.PersistedTask(taskName).load()
    assert task.is_task_done()==True
    samples = task.read(number_of_samples_per_channel=nSamples,timeout=5)
    task.stop()
    task.close()
    return samples

def getSerial(devNum):
    devNum = int(devNum)

    #Return the serial number for device number devNum
    daq = initDAQ(devNum)
    if daq == 0:
        return 0
    return daq.dev_serial_num

def moving_average(a,n=20):
    ret=np.cumsum(a,dtype=float)
    ret[n:]=ret[n:]-ret[:-n]
    return np.append(ret[n-1:]/n,ret[-1]/n*np.ones(n-1))

def numDevices():
    system = nidaqmx.system.System.local()
    devs = system.devices
    return len(devs)

def acquireNowParallel(tpe,devNum,channelName, sampleRate,sampleTime, bTrig = 0, trigChan = "PFI0"):
    print("ok")
    future = tpe.submit(acquireNow,devNum,channelName,sampleRate,sampleTime,bTrig,trigChan)
    return future

#acquireDelayed("ai0ReadingTask",1,"ai0",300,2,True)

#print(getSerial(0))
#print(getSerial(1))

#syst=nidaqmx.system.System.local()

#code.interact(local=locals())

#dcout(devNum,channelName,voltage) sets channelName of device deviceNum to voltage
#acquire(devNum,channelName,sampleRate,sampleTime) records value of channelName of device deviceNum at sampleRate for sampleTime


#dcout(0,"ao0",3)
#a=acquire(1,"ai0",300,2,True)
#dcout(0,"ao0",0)

