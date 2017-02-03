#!/bin/bash 

# VA subscript, for use with larger submission scripts

# environment stuff:
scriptDir=${0%/*}
source $scriptDir/common_functions.sh 

signals="1 2 3 4 5 6 7 8 11 13 15 30" # can be set in environment 


if [ $3 ]; then # environment is optional 
    cmd="$1"
    processRoot=$2 # run being processed
    previousRoot=$3 # run previous to this process
else
    echo -e "\e[0;31mmust specify a command, root name, previous root file, and \e[0m"
    exit 1 # failure
fi

environment="$4"
for env in $environment; do 
    source $env
done

processSubDir=processed # these should all match parent script, could put into enviroment so it's consistent 
workingDir=${processRoot%\/${processSubDir}*} # remove everything after and including /processed
processDir=$workingDir/$processSubDir
failDir=$workingDir/failed_jobs
queueDir=$workingDir/queue
backupDir=$workingDir/backup

baseFile=${processRoot##*/} # the filename without path 
runName=${baseFile%.root} # name without extension 
directory=${processRoot%\/$baseFile} # path without filename 
subDir=${directory#*${processSubDir}\/} # find subdirectory 
logDir=$workingDir/log/$subDir # full log directory 
queueFile=$queueDir/${subDir}_${runName} # needs to be consistent with queue name made in parent script 

prevBase=${previousRoot##*/} # do the same for earlier stage file 
prevRunName=${prevBase%.root}
directory=${prevRoot%\/$prevBase}
prevSubDir=${directory#*${processSubDir}\/}
prevQueueFile=$queueDir/${prevSubDir}_${prevRunName} 



test -d "$workingDir" || ( echoErr "Working directory $workingDir must be set and exist! Exiting!" ; exit 3 )


if [ -d $logDir ]; then
    logFile=$logDir/${runName}.txt
else
    echo -e "\e[0;31m Log directory $logDir does not exist!  \e[0m"
fi

# clean up files when job exits 
cleanUp() { 
    test -f $queueFile && rm $queueFile 
    echo -e "\n$cmd" 
} 
trap 'cleanUp' EXIT 

for sig in $signals; do  
    trap "echo \"TRAP! Signal: $sig\"; rm $processRoot; mv $logFile $failDir/; exit $sig" $sig
done

logInit 
sleep $((RANDOM%1))

if [[ "$cmd" =~ "-cuts" ]]; then
    afterCuts=${cmd#*-cuts=}
    set -- $afterCuts
    cutsFile=$1
    cat $cutsFile 
fi

while [ -f $prevQueueFile ]; do
    sleep 15 
done # wait for previous file to complete 


if [ -f $previousRoot ]; then

    if [[ ! "$cmd" =~ "-outputFile" ]]; then
	copyCmd="rsync -v $previousRoot $processRoot"
	echo "$copyCmd" 
	$copyCmd 
    else
	echo "not copying file" 
    fi # copy unless separate output file is specified as in stage 5 sometimes
else
    echo -e "\e[0;31m$previousRoot does not exist, cannot process $processRoot\e[0m"
    test -f $queueFile && rm $queueFile
    mv $logFile $failDir/
    exit 1 # no success
fi # previous root file exists 

Tstart=`date +%s`
$cmd 
completion=$?
Tend=`date +%s`

echo "Analysis completed in: (hours:minutes:seconds)"
date -d@$((Tend-Tstart)) -u +%H:%M:%S

echo "status: $completion" 
if [ "$completion" -ne 0 ]; then
    echo -e "\e[0;31m$processRoot not processed successfully!\e[0m"
    rm -v $processRoot
    mv  $logFile $failDir/
    exit 1
fi # command completed unsuccessfully 

if [ `grep -c unzip $logFile` -gt 0 ]; then
    echo -e "\e[0;31m$processRoot unzip error!\e[0m"
    echo "UNZIP ERROR!!!" 
    if [[ "$cmd" =~ "vaStage4.2" ]]; then
	mv -v $processRoot $backupDir/unzip
	mv  $logFile $failDir/unzip_${logFile##*/}
    else
	cp -v $logFile $failDir/unzip_${logFile##*/}
    fi
    exit 1
fi # unzip error, sigh

logStatus $logFile 

exit $completion # done 
