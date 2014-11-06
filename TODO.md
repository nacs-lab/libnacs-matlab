## Pulse Function
1. piecewise linear
2. jump (might better be an object)

## Framework
1. main sequence

    1. name
    2. addStep(len, toffset, [class, args])
       Imaginary toffset for absolute time (-1j for starting time)
       Optional toffset, mandatory len without class
       Optional len and toffset with class. Interpret single number as toffset.
    3. curTime
    4. findDriver

2. config

3. device/channel id translator/loader

## Backend
1. fpgaBackend

    1. enableClockOut(rate)
    2. Generate sequence file
    3. Upload sequence file

2. niDACBackend

    1. Generate data
    2. Connect clock
    3. Start run

## Misc
1. Error code?
