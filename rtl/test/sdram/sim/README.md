# Using makefile

Use TEST_ID=test_id make

```
Test ids:
1 : sequential read, two lines
2 : sequential read, two lines, two ways for one line
3 : sequential read, two lines, one eviction
4 : cache write
5 : write back
```


# Original non automated instructions

From: https://www.itsembedded.com/dhd/verilator_1/

## create initial code in obj_dir
verilator --trace -cc ../cache.v

## add test bench to makefile
verilator --trace -cc ../cache.v --exe tb_cache.cpp 

## build Vcache
make -C obj_dir -f Vcache.mk Vcache

## run
obj_dir/Vcache

## check results
gtkwave waveform.vcd



