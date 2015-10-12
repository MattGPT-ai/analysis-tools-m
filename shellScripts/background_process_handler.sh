#!/bin/bash 

#PBS -l nodes=1,mem=100mb
#PBS -n bg_handler 
#PBS -j oe 
#PBS -o $HOME/log/bgSubmission.txt

# this job can be run in the process to slowly submit background jobs to qsub, only using up to nQueue max nodes

bgScriptDir=$HOME/backgroundScripts # directory where all scripts to be submitted are held
nodesToUse=(16)
nodesTotal=(32)

while [ `ls $bgScriptDir | wc -l` -ne 0 ]; do

    sleep 30 

    nodesUsed=$((`qstat | wc -l`-2))
    nodesAvailable=$((nodesToUse - nodesUsed))
    if (( nodesAvailable > 0 ))
	for $file in `ls -ltr $bgScriptDir`; do 
	    chmod u+x $file
	    qsub $file
	    trash $file
	done
    fi # there are less nodes being used than allocated to background processing
    
done # while there are scripts in the script dir 

exit 0 # great job 
