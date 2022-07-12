# clc88
CLC-88 Micro Computer emulator

Code to experiment with a new retro-computer design.

More info at:
http://catrinlabs.cl/clc-88-compy-the-8-bit-computer/

## Pre-requisites for building

You need some Linux dev tools plus the mads assember
If you are using ubuntu, this command should be enough:

```sh
sudo apt-get build-essential libsdl2-dev
```
 
Mads can be found at http://mads.atari8.info/

## Building

To build the emulator, samples and test programs:
 
 ```sh
 cd src
 make
 ```

## Run

The emulator itself will do nothing and will stop when trying to run an app
After building the emulator, several samples and tests will be built

The general command to run the emulator is:

```sh
 ./clc88 PROGRAM [-m|-M] [-storage PATH]
```
 
Example

```sh
 ./clc88 ../bin/asm/6502/test/mode_0
```

The flags are:

- -m : enter the monitor just before starting the loaded app
- -M : enter the monitor just after RESET, before anything is ran
- -storage : folder to use as the emulated storage
 
Here is another example running the RMT player demo
```sh
 ./clc88 ../bin/asm/6502/demos/rmtplayer/player -storage ../asm/6502/demos/rmt/songs
```

## Credits:

- Z80 and 6502 Emulator by Juergen Buchmueller
- Pokey emulator from the MAME project
- Emulation interfaces from the MAME project
