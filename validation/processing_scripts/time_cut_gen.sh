#!/bin/bash 

loggenFile=$1

while read -r line; do 
    set -- $line
    runNum=$2

    timeCutMask=`mysql -h romulus.ucsc.edu -u readonly -s -N -e "use VOFFLINE; SELECT time_cut_mask FROM tblRun_Analysis_Comments WHERE run_id = ${runNum}"`
    if [ "$timeCutMask" != "NULL" ]; then 
	echo -e "$runNum \t${timeCutMask}"
    fi

done < $loggenFile 

exit 0 # great job 
