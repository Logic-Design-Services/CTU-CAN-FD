#!/bin/bash

DUT_CFG=big

ts_sim_coverage.py -o merged_${DUT_CFG}_asic_max_feature sim_tb_rtl_${DUT_CFG}_asic_max_feature__* --clear
ts_sim_coverage.py -o merged_${DUT_CFG}_asic_typ_feature sim_tb_rtl_${DUT_CFG}_asic_typ_feature__* --clear
ts_sim_coverage.py -o merged_${DUT_CFG}_asic_max_compliance sim_tb_rtl_${DUT_CFG}_asic_max_compliance__* --clear
ts_sim_coverage.py -o merged_${DUT_CFG}_asic_typ_compliance sim_tb_rtl_${DUT_CFG}_asic_typ_compliance__* --clear
ts_sim_coverage.py -o merged_${DUT_CFG}_asic_min_compliane sim_tb_rtl_${DUT_CFG}_asic_min_compliance__* --clear
ts_sim_coverage.py -o merged_${DUT_CFG}_asic_sjw0_compliane sim_tb_rtl_${DUT_CFG}_asic_sjw0_compliance__* --clear

rm -rf merged_${DUT_CFG}_asic_max_feature
rm -rf merged_${DUT_CFG}_asic_typ_feature
rm -rf merged_${DUT_CFG}_asic_max_compliance
rm -rf merged_${DUT_CFG}_asic_typ_compliance
rm -rf merged_${DUT_CFG}_asic_min_compliane
rm -rf merged_${DUT_CFG}_asic_sjw0_compliane

mkdir merged_${DUT_CFG}_asic_max_feature
mkdir merged_${DUT_CFG}_asic_typ_feature
mkdir merged_${DUT_CFG}_asic_max_compliance
mkdir merged_${DUT_CFG}_asic_typ_compliance
mkdir merged_${DUT_CFG}_asic_min_compliane
mkdir merged_${DUT_CFG}_asic_sjw0_compliane

mv ../coverage_output/merged_${DUT_CFG}_asic_max_feature.vdb merged_${DUT_CFG}_asic_max_feature/simv.vdb
mv ../coverage_output/merged_${DUT_CFG}_asic_typ_feature.vdb merged_${DUT_CFG}_asic_typ_feature/simv.vdb
mv ../coverage_output/merged_${DUT_CFG}_asic_max_compliance.vdb merged_${DUT_CFG}_asic_max_compliance/simv.vdb
mv ../coverage_output/merged_${DUT_CFG}_asic_typ_compliance.vdb merged_${DUT_CFG}_asic_typ_compliance/simv.vdb
mv ../coverage_output/merged_${DUT_CFG}_asic_min_compliane.vdb merged_${DUT_CFG}_asic_min_compliane/simv.vdb
mv ../coverage_output/merged_${DUT_CFG}_asic_sjw0_compliane.vdb merged_${DUT_CFG}_asic_sjw0_compliane/simv.vdb

ts_sim_coverage.py merged_${DUT_CFG}_asic_max_feature merged_${DUT_CFG}_asic_typ_feature merged_${DUT_CFG}_asic_max_compliance \
                   merged_${DUT_CFG}_asic_typ_compliance merged_${DUT_CFG}_asic_min_compliane merged_${DUT_CFG}_asic_sjw0_compliane \
                   -o merged_${DUT_CFG}_total --clear
