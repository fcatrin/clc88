# create initial code in obj_dir
verilator --trace -cc ../cache.v

# add test bench to makefile
verilator --trace -cc ../cache.v --exe tb_cache.cpp 

# build Vcache
make -C obj_dir -f Vcache.mk Vcache

# run
obj_dir/Vcache

# check results
gtkwave waveform.vcd


Tutorial from: https://www.itsembedded.com/dhd/verilator_1/

