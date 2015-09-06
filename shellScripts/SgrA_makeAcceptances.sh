#!/bin/bash

bgFile=$GC/runlists/SgrA_background_off_4tel.txt
test $1 && bgFile="$1"
name="acceptance_off_4tel"
test $2 && name="$2"
logFile=$GC/log/acceptanceMaps/SgrA_${name}.txt

cmd="$VEGAS/bin/makeAcceptancePlot -UserDefinedExclusionList=$HOME/config/SgrA_exclusionList.txt -BackgroundFileList=$bgFile -AcceptancePlotFile=$GC/processed/acceptanceMaps/SgrA_${name}.root"

echo "$cmd"

echo "submit job with qsub? Y or n"
read choice

if [ "$choice" == "Y" ]; then
    qsub <<EOF
#PBS -o $logFile
#PBS -l mem=2gb,nodes=1
#PBS -j oe 

$cmd

exitCode=\$?
if [ \$exitCode -ne 0 ]; then 
mv $logFile $GC/rejected/
fi

mv *.gif $GC/plots/acceptancePlots/

EOF
fi

exit 0 # great job
