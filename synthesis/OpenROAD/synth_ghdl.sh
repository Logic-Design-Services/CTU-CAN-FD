#!/bin/bash

rm -rf build
mkdir build
mkdir build/ghdl_work

rm -rf ctu_can_fd_top.v

# Analyze CTU CAN FD source files
for f in $(grep "file:" ../../src/slf_rtl.yml | grep -v "^\s*#" | sed "s/.*file:\s*//"); do
    ghdl -a --work=ctu_can_fd_rtl --workdir=./build/ghdl_work ../../src/$f
done

ghdl --synth \
     --latches \
     -gG_TECHNOLOGY=0 \
     -P./build/ghdl_work \
     --out=verilog ctu_can_fd_rtl.ctu_can_fd_top > build/ctu_can_fd_top.unmapped.v
