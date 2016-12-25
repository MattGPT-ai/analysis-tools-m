#!/bin/bash 

# VA subscript, for use with larger submission scripts

# environment stuff:
#scratchDir=/scratch/mbuchove
trashDir=$TRASHDIR
signals="1 2 3 4 5 6 7 8 11 13 15 30"

if [ $3 ]; then
    cmd="$1"
    processRoot=$2 # run being processed
    previousRoot=$3 # run previous to this process
else
    echo -e "\e[0;31mmust specify a command, root name, previous root file \e[0m"
    exit 1 # failure
fi
if [ $4 ]; then
    environment="$4"
    for env in $environment; do 
	source $env
    done
fi
spectrum=$5

workDir=$VEGASWORK
processBaseDir=processed # these should all match parent script
processDir=$workDir/$processBaseDir
rejectDir=$workDir/rejected
queueDir=$workDir/queue

base=${processRoot##*/}
runName=${base%.root}
directory=${processRoot%$base}
subDir=${directory#*$processBaseDir}
subDir=${subDir//\//}
#subDir=${directory#$processDir}
#subDir=${subDir%*/}
logDir=$workDir/log/${subDir}/

base=${previousRoot##*/}
previousName=${base%.root}
directory=${previousRoot%$base}
prevSubDir=${directory#*$processBaseDir}
prevSubDir=${prevSubDir//\//}
queueFile=${queueDir}/${subDir}_${runName}

if [ -d $logDir ]; then
    logFile=$logDir/${runName}.txt
    echo "" > $logFile 
    #test -f $logFile || mv $logFile $trashDir/ 
else
    echo -e "\e[0;31m Log directory $logDir does not exist!  \e[0m"
fi

# cleanup, 
cleanUp() {
test -f $queueFile && rm $queueFile
echo -e "\n$cmd"
}
trap "cleanUp" EXIT
for sig in $signals; do  
    trap "echo \"TRAP! Signal: $sig\"; rm $processRoot; mv $logFile $rejectDir/; exit $sig" $sig
done
sleep $((RANDOM%10))

date
echo -n "hostname: " hostname  
echo -n "ROOT: $ROOTSYS "; root-config --version 
echo -n "VEGAS git hash: "; git --git-dir $VEGAS/.git describe --always
echo "spectrum: $spectrum"
if [[ "$cmd" =~ "-cuts" ]]; then
    afterCuts=${cmd#*-cuts=}
    set -- $afterCuts
    cutsFile=$1
    cat $cutsFile 
fi

while [ -f ${queueDir}/${prevSubDir}_${previousName} ]; do
    sleep $((RANDOM%10+10))
done 
# wait for previous 


if [ -f $previousRoot ]; then

    if [[ ! "$cmd" =~ "-outputFile" ]]; then

	while [[ "`ps cax`" =~ "bbcp" ]]; do
	    sleep $((RANDOM%10+10));
	done
	bbCmd="bbcp -e -E md5= $previousRoot $processRoot"
	echo "$bbCmd" 
	$bbCmd 
    else
	echo "not copying file" 
    fi # copy unless separate output file is specified as in stage 5 sometimes
else
    echo -e "\e[0;31m$previousRoot does not exist, cannot process $processRoot\e[0m"
    test -f $queueFile && rm $queueFile
    mv $logFile $rejectDir/
    exit 1 # no success
fi # previous root file exists 

Tstart=`date +%s`
$cmd 
completion=$?
Tend=`date +%s`

echo "Analysis completed in: (hours:minutes:seconds)"
date -d@$((Tend-Tstart)) -u +%H:%M:%S
echo "$cmd"


if [ $completion -ne 0 ]; then
    echo -e "\e[0;31m$processRoot not processed successfully!\e[0m"
    mv $logFile $rejectDir/
    rm $processRoot
    exit 1
fi # command unsuccessfully completed

if [ `grep -c unzip $logFile` -gt 0 ]; then
    echo -e "\e[0;31m$processRoot unzip error!\e[0m"
    echo "UNZIP ERROR!!!" 
    #if [[ "$cmd" =~ "vaStage4.2" ]]; then
    mv $processRoot $workDir/backup/unzip/
    mv $logFile $rejectDir/unzip_${logFile##*/}
    exit 1
fi # unzip error, sigh

test -f $rejectDir/${logFile##*/} && trash $rejectDir/${logFile##*/}
cp $logFile $workDir/completed/

exit 0 # great success
