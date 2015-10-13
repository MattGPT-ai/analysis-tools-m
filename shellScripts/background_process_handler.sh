#!/bin/bash 

#PBS -l nodes=1,mem=100mb
#PBS -N bg_handler 
#PBS -j oe 
#PBS -o $HOME/log/bgSubmission.txt

# this job can be run in the process to slowly submit background jobs to qsub, only using up to nQueue max nodes

bgScriptDir=$HOME/bgScripts # directory where all scripts to be submitted are held
nodesToUse=(16)
nodesTotal=(32)

while [ `ls $bgScriptDir | wc -l` -ne 0 ]; do

    nodesUsed=$((`qstat | wc -l`-2))
    nodesAvailable=$((nodesToUse - nodesUsed))
    if (( nodesAvailable > 0 )); then 
	for file in `ls -tr $bgScriptDir/*`; do 
	    chmod u+x $file
	    qsub $file
	    trash $file
	    break
	done
    fi # there are less nodes being used than allocated to background processing
    
    sleep 30 

done # while there are scripts in the script dir 

exit 0 # great job 
