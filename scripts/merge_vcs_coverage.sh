#!/bin/bash

ts_sim_coverage.py -o merged_medium_asic_max_feature sim_tb_rtl_medium_asic_max_feature_* --clear
ts_sim_coverage.py -o merged_medium_asic_typ_feature sim_tb_rtl_medium_asic_typ_feature_* --clear
ts_sim_coverage.py -o merged_medium_asic_max_compliance sim_tb_rtl_medium_asic_max_compliance_* --clear
ts_sim_coverage.py -o merged_medium_asic_typ_compliance sim_tb_rtl_medium_asic_typ_compliance_* --clear
ts_sim_coverage.py -o merged_medium_asic_min_compliane sim_tb_rtl_medium_asic_min_compliance_* --clear
ts_sim_coverage.py -o merged_medium_asic_sjw0_compliane sim_tb_rtl_medium_asic_sjw0_compliance_* --clear

rm -rf merged_medium_asic_max_feature
rm -rf merged_medium_asic_typ_feature
rm -rf merged_medium_asic_max_compliance
rm -rf merged_medium_asic_typ_compliance
rm -rf merged_medium_asic_min_compliane
rm -rf merged_medium_asic_sjw0_compliane

mkdir merged_medium_asic_max_feature
mkdir merged_medium_asic_typ_feature
mkdir merged_medium_asic_max_compliance
mkdir merged_medium_asic_typ_compliance
mkdir merged_medium_asic_min_compliane
mkdir merged_medium_asic_sjw0_compliane

mv ../coverage_output/merged_medium_asic_max_feature.vdb merged_medium_asic_max_feature/simv.vdb
mv ../coverage_output/merged_medium_asic_typ_feature.vdb merged_medium_asic_typ_feature/simv.vdb
mv ../coverage_output/merged_medium_asic_max_compliance.vdb merged_medium_asic_max_compliance/simv.vdb
mv ../coverage_output/merged_medium_asic_typ_compliance.vdb merged_medium_asic_typ_compliance/simv.vdb
mv ../coverage_output/merged_medium_asic_min_compliane.vdb merged_medium_asic_min_compliane/simv.vdb
mv ../coverage_output/merged_medium_asic_sjw0_compliane.vdb merged_medium_asic_sjw0_compliane/simv.vdb

ts_sim_coverage.py merged_medium_asic_max_feature merged_medium_asic_typ_feature merged_medium_asic_max_compliance \
                   merged_medium_asic_typ_compliance merged_medium_asic_min_compliane merged_medium_asic_sjw0_compliane \
                   -o merged_total --clear
