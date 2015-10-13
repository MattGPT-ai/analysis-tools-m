#!/bin/bash 

# VA subscript, for use with larger submission scripts

# environment stuff: pass these over
scratchDir=/scratch/mbuchove/
# source $environment

if [ $3 ]; then
    cmd="$1"
    dataFile=$2
    laserRoot=$3
else
    echo -e "\e[0;31mmust specify stage 1 command, data file, and root filename!\e[0m"
    exit 1 # failure
fi

args=`getopt e: $*` 
set -- $args

for i; do      # loop through options
    case "$i" in 
        -e) source $2
            shift ; shift ;; 
        --) shift; break ;;
    esac # end case $i in options
done # loop over command line arguments 

trashDir=$TRASHDIR
laserDir=$LASERDIR #needs to match process_script.sh
logDir=$laserDir/log
queueDir=$laserDir/queue
rejectDir=$laserDir/rejected

base=${laserRoot##*/}
runName=${base%.root}


if [ -d $logDir ]; then
    logFile=$logDir/${runName}.txt
else
    echo -e "\e[0;31m Log directory does not exist!  \e[0m"
fi

test -f $logFile && mv $logFile $trashDir/

base=${dataFile##*/}
dataNum=${base%.cvbf}
scratchFile=$scratchDir/${dataNum}.cvbf

queueFile=$queueDir/${runName}
cleanUp() {
test -f $scratchFile && rm $scratchFile
rm $queueFile
} # clean up to be done upon exit, regardless of how it exits
trap cleanUp EXIT 
signals="1 2 3 4 5 6 7 8 11 13 15 30"
trap "cleanUp; rm $laserRoot; mv $logFile $rejectDir; exit 130" $signals
# clean up for specific signals 

hostname # ${redirection/>>/>}
root-config --version 
echo $ROOTSYS 
git --git-dir $VEGAS/.git describe --tags

sleep $((RANDOM%10+10));
while [[ "`ps cax`" =~ " bbcp" ]]; do
    sleep $((RANDOM%10+10));
done
bbCmd="bbcp -e -E md5= $dataFile $scratchDir/"
echo "$bbCmd" 
$bbCmd 

Tstart=`date +%s`
$cmd $scratchFile $laserRoot 
completion=$?
Tend=`date +%s`

test -f $queueDir/$runName && rm $queueDir/$runName
echo "Analysis completed in: (hours:minutes:seconds)"
date -d@$((Tend-Tstart)) -u +%H:%M:%S 
echo "$cmd $scratchFile $laserRoot" 

rm $scratchFile

if [ $completion -ne 0 ]; then
    echo -e "\e[0;31m$laserRoot not processed successfully!\e[0m"
    mv $logFile $rejectDir/
    rm $laserRoot 
    exit 1
fi # command unsuccessfully completed

if [ `grep -c unzip $logFile` -gt 0 ]; then
    echo -e "\e[0;31m$rootName_new unzip error!\e[0m" 
    mv $logFile $rejectDir
    rm $laserRoot
    exit 1
fi # unzip error, sigh

cp $logFile $workDir/completed/ 

exit 0 # great success
