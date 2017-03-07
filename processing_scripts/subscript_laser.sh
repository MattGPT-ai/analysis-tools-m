#!/bin/bash 

# VA subscript, for use with larger submission scripts

scriptDir=${0%/*}
source $scriptDir/common_functions.sh 

if [ $3 ]; then
    cmd="$1"
    dataFile=$2
    laserRoot=$3
    environment="$4" # optional 
else
    echo -e "\e[0;31m must specify stage 1 command, data file, and root filename!\e[0m"
    exit 1 # failure
fi

echo "environment: $environment"
for env in $environment; do 
    source $env
done


test -n "$laserDir" || ( echoErr "\$laserDir must be set! Exiting!" ; exit 3 )
workDir=$laserDir # not used currently 
logDir=$laserDir/log
failDir=$laserDir/failed_jobs
queueDir=$laserDir/queue
backupDir=$laserDir/backup

base=${laserRoot##*/}
runName=${base%.root}
laserNum=${runName%.laser}

if [ -d $logDir ]; then
    logFile=$logDir/${runName}.txt
else
    echo -e "\e[0;31m Log directory does not exist!  \e[0m"
fi

base=${dataFile##*/}
dataNum=${base%.cvbf}
scratchFile=$scratchDir/$dataFile
#dataFile=$dataDir/${dataNum}.cvbf
queueFile=$queueDir/${runName}

cleanFiles="$queueFile" # $scratchFile not deleted 
if [ "$copy_local" ]; then 
    cleanFiles="$cleanFiles $scratchFile"
    scratchFile=$scratchDir/${dataFile##*/}
    rsync -v $archiveDataDir/$dataFile $scratchDir/
    test "$?" -eq 0 && test -f "$scratchFile" || exit 1 
fi
cleanUp() {
    for f in $cleanFiles ; do 
	test -f $f && rm $f
    done 
} # clean up to be done upon exit, regardless of how it exits
trap 'cleanUp' EXIT 

signals="1 2 3 4 5 6 7 8 11 13 15 30"
for sig in $signals; do 
    trap "echo \"TRAP! Signal: $sig\"; rm $laserRoot; mv $logFile $failDir/; cleanUp; exit $sig" $sig
done 
# clean up for specific signals 

# just print some useful information about the run 
logInit 


Tstart=`date +%s`
$cmd $scratchFile $laserRoot
completion=$?
Tend=`date +%s`

echo "Analysis completed in: (hours:minutes:seconds)"
date -d@$((Tend-Tstart)) -u +%H:%M:%S 
echo "$cmd $scratchFile $laserRoot" 

echo $completion 
if [ "$completion" -ne 0 ]; then
    echo -e "\e[0;31m$laserRoot not processed successfully!\e[0m"
    mv $logFile $failDir/
    rm $laserRoot 
    exit 1
fi # command completed unsuccessfully 

if [ `grep -c unzip $logFile` -gt 0 ]; then
    echo -e "\e[0;31m$rootName_new unzip error!\e[0m" 
    cp $logFile $failDir/
    mv $laserRoot $backupDir/
    exit 1
fi # unzip error, sigh

logStatus $logFile 

exit $completion # great success
