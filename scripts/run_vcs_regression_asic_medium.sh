#!/bin/bash

# First run for clean-up
ts_sim_run.py --recompile --no-sim-out --clear --clear-logs tb_rtl_medium_asic_max_feature \*
ts_sim_run.py --recompile --no-sim-out tb_rtl_medium_asic_typ_feature \*

ts_sim_run.py --recompile --no-sim-out tb_rtl_medium_asic_max_compliance \*
ts_sim_run.py --recompile --no-sim-out tb_rtl_medium_asic_typ_compliance \*
ts_sim_run.py --recompile --no-sim-out tb_rtl_medium_asic_min_compliance \*
