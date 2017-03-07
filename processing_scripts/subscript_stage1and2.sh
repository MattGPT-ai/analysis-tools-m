#!/bin/bash 
# VA subscript, for use with larger submission scripts

# environment stuff
scriptDir=${0%/*}
source $scriptDir/common_functions.sh 
source $scriptDir/defaults_source.sh

if [ $8 ]; then
    stage1cmd="$1"
    rootName_1="$2"
    runStage1="$3"
    stage2cmd="$4"
    rootName_2="$5"
    runNum="$6"
    dataFile="$7"
    laserRoot="$8"
    environment="$9"
else
    echoErr "Must specify stage 1 command, stage 2 command, run number, data file, and laser root file! should specify environment file as well"
    exit 1 # failure
fi

#echo "environment: $environment"
for env in $environment; do
    source $env
done

test -n "$workDir" || ( echoErr "\$workDir must be set! Exiting!" ; exit 3 ) 

scratchFile=$scratchDir/$dataFile

processDir=$workDir/processed
logDir=$workDir/log
failDir=$workDir/failed_jobs
queueDir=$workDir/queue
backupDir=$workDir/backup

stage1dir=${rootName_1%\/*}
stage2dir=${rootName_2%\/*}
stage1subDir=${stage1dir##*\/}
stage2subDir=${stage2dir##*\/}

logFile1=$logDir/${stage1subDir}/${runNum}.stage1.txt
logFile2=$logDir/${stage2subDir}/${runNum}.stage2.txt
queue1=$queueDir/${stage1subDir}_${runNum}.stage1
queue2=$queueDir/${stage2subDir}_${runNum}.stage2

laserDir=${laserRoot%\/processed\/*}
laserBase=${laserRoot##*/}
laserName=${laserBase%.root}
queueLaser=$laserDir/queue/$laserName

cleanFiles="$queue1 $queue2" # $scratchFile not deleted 
if [ "$copy_local" ]; then 
    scratchFile=$scratchDir/${dataFile##*/}
    finalRoot=$rootName_2 # use scratch directory as interm
    #rootName_2=$scratchDir/${rootName_2##*/}
    cleanFiles="$cleanFiles $scratchFile " #$rootName_2"
    rsync -v $archiveDataDir/$dataFile $scratchDir/
    test "$?" -eq 0 && test -f "$scratchFile" || exit 1 
fi
cleanUp() {
    for f in $cleanFiles ; do 
	test -f $f && rm $f
    done 
}
trap 'cleanUp' EXIT

if [ "$stage1cmd" ]; then 
    test -f $logFile1 && mv $logFile1 $backupDir/
    failed_job(){
	test -f "$rootName_1" && rm -v $rootName_1
	test -f "$queue2" && rm -v $queue2
	mv $logFile1 $failDir/
    }

    # signals source in defaults 
    for sig in $signals; do 
	trap "echo \"TRAP! Signal: $sig\"; failed_job ; exit $sig" $sig
    done

    logInit > $logFile1 
     
    Tstart=`date +%s`
    $stage1cmd $scratchFile $rootName_1 &>> $logFile1
    completion=$?
    Tend=`date +%s`
    
    echo "Analysis completed in: (hours:minutes:seconds)" >> $logFile1
    date -d@$((Tend-Tstart)) -u +%H:%M:%S >> $logFile1
    
    test -f $queue1 && rm $queue1
    echo "" >> $logFile1
    echo "$stage1cmd $scratchFile $rootName_1" >> $logFile1
    
    if [ $completion -ne 0 ]; then
	echoErr "$rootName_1 not processed successfully!"
	failed_job
	exit 1
    else
	logSucess $logFile1 
    fi # command completed unsuccessfully 
    
    if [ "`grep -c unzip $logFile`" -gt 0 ]; then
	echoErr "$rootName_1 UNZIP ERROR!!!"
	mv $logFile1 $failDir/
    fi
    
fi # stage 1 command isn't null 

if [ "$stage2cmd" ]; then 
    test -f $logFile2 && mv $logFile2 $backupDir/
    failed_job(){
	echoErr "$rootName_2 not processed successfully!"
	rm -v $rootName_2
	mv $logFile2 $failDir/
    }	
    for sig in $signals; do 
	trap "echo \"TRAP! Signal: $sig\"; test -f $rootName_2 && rm $rootName_2; mv $logFile2 $failDir/; exit $sig" $sig
    done

    logInit > $logFile2 
    
    copyCmd="rsync -v $rootName_1 $rootName_2"
    echo "$copyCmd">> $logFile2
    $copyCmd >> $logFile2
    
    while [ -f $queueLaser ]; do
	sleep $((RANDOM%10+20))
    done

    Tstart=`date +%s`
    $stage2cmd $scratchFile $rootName_2 $laserRoot &>> $logFile2 
    completion=$?
    Tend=`date +%s`
    
    echo "Analysis completed in (hours:minutes:seconds)" >> $logFile2
    date -d@$((Tend-Tstart)) -u +%H:%M:%S >> $logFile2
    echo "$stage2cmd $scratchFile $rootName_2 $laserRoot" >> $logFile2
    
    test -f $queue2 && rm $queue2

    if [ $completion -ne 0 ]; then
	exit $completion
    else
	logStatus $logFile2
	test "$runStage1" == true || rm $rootName_1 
	
    fi # command completed unsuccessfully 
    echo "exit code: $completion"

    if [ `grep -c unzip $logFile2` -gt 0 ]; then
	echoErr "$rootName_2 UNZIP ERROR!!!"
	mv $logFile2 $failDir/	
    fi
    
fi # stage 2 command isn't null

exit $completion # done 
