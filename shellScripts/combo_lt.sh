#!/bin/bash

atm=22
array=ua
finalTable=lt_Oct2012_${array}_ATM${atm}_7samples_vegas254_allOffsets_LZA.root

qsub <<EOF

#PBS -l nodes=1,mem=4gb,walltime=5:00:00
#PBS -j oe
#PBS -o $GC/log/tables/combine_lt_${array}_ATM${atm}_allOffsets_LZA.txt
#PBS -N combine_lt_${array}_ATM${atm}_allOffsets_LZA

while read -r firstTable; do break; done < /veritas/userspace2/mbuchove/SgrA/config/tableList_lt_${array}_ATM${atm}.txt

cp \$firstTable \${firstTable}.backup

buildCmd="buildLTTree -TelID=0,1,2,3 -Azimuth=0,45,90,135,180,225,270,315 -Zenith=00,20,30,35,40,45,50,55,60,65 -AbsoluteOffset=0.00,0.50,0.75,0.25,1.00,1.25,1.50,1.75,2.00 -Noise=4.24,5.21,6,6.68,7.27,7.82,8.33,9.20,10.19,11.17,12.17 \$firstTable"

cd $VEGAS/showerReconstruction2/macros/
root -l -b -q "combo.C(\"$GC/config/tableList_lt_${array}_ATM${atm}.txt\", \"\$buildCmd\")"

\$buildCmd

mv \$firstTable $GC/processed/tables/${finalTable}
mv \${firstTable}.backup \$firstTable

root -l -b -q "validate.C(\"$GC/processed/tables/${finalTable})"

rsync \$firstTable $TABLEDIR/${finalTable}

EOF

exit 0 
