#!/bin/bash

rm -rf build
mkdir build
mkdir build/ghdl_work

rm -rf ctu_can_fd_top.v

# Analyze CTU CAN FD source files
for f in $(grep "file:" ../../src/slf_rtl.yml | grep -v "^\s*#" | sed "s/.*file:\s*//"); do
    ghdl -a --work=ctu_can_fd_rtl --workdir=./build/ghdl_work ../../src/$f
done

# Elaborate with YOSYS and convert to plain unmapped verilog (like g-tech)
yosys -m ghdl << 'EOF' &2>1
    ghdl --latches -gG_TECHNOLOGY=0 -P./build/ghdl_work ctu_can_fd_rtl.ctu_can_fd_top
    write_verilog build/ctu_can_fd_top.unmapped.v
EOF
