#!/bin/bash 

[ $1 ] && runMode="$1" || runMode=cat 


for zen in 0-15 35-50 50-62 ; do 

    $runMode <<EOF

#PBS -N accept_${zen}
#PBS -o $CRAB/log/acceptance_z${zen}.txt
#PBS -j oe 
#PBS -l nodes=1,mem=2gb


    cd $VEGAS/resultsExtractor/macros/

    root -l -b "make2DAcceptanceMapWrapper.C(\"/veritas/userspace3/mbuchove/Crab/runlists/Crab_V5_acceptanceTest_z${zen}_soft_stg5list.txt\", \"/veritas/userspace3/mbuchove/Crab/plots/acceptance/Crab_z${zen}_soft_s6params\")" 

EOF

done # end loop over zenith ranges

exit 0 
