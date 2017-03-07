#!/bin/bash

cmd="$1"
smallTableFile="$2"
environment=""

# clean up files upon exit, make sure this executes when other trap is triggered 
cleanUp() { 
    test -f $queueFile && rm $queueFile
    echo -e "\n$cmd"
}
trap cleanUp EXIT # called upon any exit 
rejectTable() {
    echo "exit code: \$exitCode"
    test -f $smallTableFile && mv $smallTableFile $tableWork/backup/
    mv $logFile $tableWork/failed_jobs/
    #exit 15 
}

for sig in $signals; do 
    trap "echo \"TRAP! Signal: \${sig} - Exiting..\"; rejectTable; exit \$sig" \$sig
done 

hostname

module load shifter 

# execute command
timeStart=\`date +%s\`
$cmd
exitCode=\$?
timeEnd=\`date +%s\`
echo "Table made in:"
date -d @\$((timeEnd-timeStart)) -u +%H:%M:%S

if [ "\$exitCode" -ne 0 ]; then 
    rejectTable
    exit \$exitCode
fi 

# validate table 
if [ "$table" == "ea" ]; then 
    cd $VEGAS/resultsExtractor/macros/
    root -l -b -q 'validate2.C("$smallTableFile")'
    sumFile=${smallTableFile/.root/.summary.csv}
    if [ -f \$sumFile ]; then
        test \`cat $sumFile | wc -l\` -gt 1 && badDiag=true || rm \$sumFile
    else
        echo "no sumfile!"
    fi 
else
    cd $VEGAS/showerReconstruction2/macros/
    root -l -b -q 'validate.C("$smallTableFile")'
fi
# ea files have an additional summary csv file that should not have more than one line 
diagFile=${smallTableFile/.root/.diag}
if [ -s \$diagFile ] || [ ! -f \$diagFile ]; then 
    echo "SOME MIGHT FAIL!! check .diag files"
    badDiag=true
else
    rm \$diagFile
fi # diag file contains bad tables or wasn't created

if [ "\$badDiag" != "true" ]; then
    logStatus $logFile 
fi

echo "Exiting.. $exitCode"

exit $exitCode 
