## Pulse Function
1. piecewise linear
2. jump (might better be an object)

## Framework
1. main sequence

    1. name
    2. findDriver

2. config

3. device/channel id translator/loader

4. default/initial value

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
