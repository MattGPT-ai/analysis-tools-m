#!/bin/bash

bgFile=$GC/runlists/SgrA_background_off_4tel.txt
test $1 && bgFile="$1"
name="acceptance_off_4tel"
test $2 && name="$2"

cmd="$VEGAS/bin/makeAcceptancePlot -UserDefinedExclusionList=$HOME/config/SgrA_exclusionList.txt -BackgroundFileList=$GC/runlists/SgrA_background_off_4tel.txt -AcceptancePlotFile=$GC/processed/acceptanceMaps/SgrA_${name}.txt"

echo "$cmd"

echo "submit job with qsub? Y or n"
read choice

if [ "$choice" == "Y" ]; then
    qsub <<EOF
#PBS -o $GC/log/acceptanceMaps/SgrA_${name}.txt
#PBS -l mem=2gb,nodes=1
#PBS -j oe 

$cmd

EOF
fi

exit 0 # great job
