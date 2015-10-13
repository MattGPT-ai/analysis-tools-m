#!/bin/bash 

# VA subscript, for use with larger submission scripts

# environment stuff:
scratchDir=/scratch/mbuchove
trashDir=$TRASHDIR
stage1subDir=stg1 #needs to match process_script.sh
stage2subDir=stg2 #also must match

if [ $5 ]; then
    stage1cmd="$1"
    stage2cmd="$2"
    runNum=$3
    dataFile=$4
    laserRoot=$5
    shift 5
else
    echo -e "\e[0;31mmust specify stage 1 command, stage 2 command, run number, data file, and laser root file!\e[0m"
    exit 1 # failure
fi

args=`getopt e: $*` #s:
set -- $args

for i; do                      # loop through options
    case "$i" in 
#       -s) subDir=$2
#           shift ; shift ;;
        -e) source $2
            shift ; shift ;; 
        --) shift; break ;;
    esac # end case $i in options
done # loop over command line arguments 

workDir=$VEGASWORK
processDir=$workDir/processed/
laserDir=$LASERDIR
logDir=$workDir/log/
rejectDir=$workDir/rejected/
queueDir=$workDir/queue/

rootName_1=$processDir/${stage1subDir}/${runNum}.stage1.root
rootName_2=$processDir/${stage2subDir}/${runNum}.stage2.root
logFile1=$logDir/${stage1subDir}/${runNum}.stage1.txt
logFile2=$logDir/${stage2subDir}/${runNum}.stage2.txt
base=${laserRoot##*/}
laserName=${base%.root}
queue1=$queueDir/${stage1subDir}_${runNum}.stage1
queue2=$queueDir/${stage2subDir}_${runNum}.stage2
queueLaser=$laserDir/queue/$laserName

scratchFile=$scratchDir/${runNum}.cvbf
cleanUp() {
    for f in $scratchFile $queue1 $queue2; do 
	test -f $f && rm $f
    done 
}
signals="1 2 3 4 5 6 7 8 11 13 15 30"
#trap '' ERR # set -e 
trap cleanUp EXIT

sleep $((RANDOM%10+5))

while [[ "`ps cax`" =~ "bbcp" ]]; do
    sleep $((RANDOM%10+10));
done
bbCmd="bbcp -e -E md5= -V $dataFile $scratchFile"

if [ "$stage1cmd" != "NULL" ]; then
    test -f $logFile1 && mv $logFile1 $trashDir/
    echo "$bbCmd" >> $logFile1
    $bbCmd >> $logFile1
    scratchFileCopied=true
fi # stage 1 not passed as null
if [ "$stage2cmd" != "NULL" ]; then
    test -f $logFile2 && mv $logFile2 $trashDir/
    echo "$bbCmd" >> $logFile2
    test ! -f $scratchFile || -z "$scratchFileCopied" && $bbCmd >> $logFile2
fi # stage 2 not passed as null
    
if [ "$stage1cmd" != "NULL" ]; then 
    trap "echo TRAP; test -f $rootName_1 && rm $rootName_1; mv $logFile1 $refectDir/; exit 130" $signals
    date > $logFile1
    hostname >> $logFile1 
    root-config --version >> $logFile1
    echo $ROOTSYS >> $logFile1
    git --git-dir $VEGAS/.git describe --tags >> $logFile1
    
    Tstart=`date +%s`
    $stage1cmd $scratchFile $rootName_1 >> $logFile1
    completion=$?
    Tend=`date +%s`

    echo "Analysis completed in: (hours:minutes:seconds)" >> $logFile1
    date -d@$((Tend-Tstart)) -u +%H:%M:%S >> $logFile1
       
    test -f $queue1 && rm $queue1
    echo "" >> $logFile1
    echo "$stage1cmd $dataFile $rootName_1" >> $logFile1
    
    if [ $completion -ne 0 ]; then
	echo -e "\e[0;31m$rootName_1 not processed successfully!\e[0m"
	mv $logFile1 $rejectDir/
	rm $rootName_1
	rm $queue2
	rm $scratchFile
	exit 1
    else
	cp $logFile1 $workDir/completed/	
    fi # command unsuccessfully completed
                                          
    if [ `grep -c unzip $logFile` -gt 0 ]; then
	echo -e "\e[0;31m$rootName_1 UNZIP ERROR!!!\e[0m"
	mv $logFile1 $rejectDir/
    fi

fi # stage 1 command isn't null 

if [ "$stage2cmd" != "NULL" ]; then 
    trap "echo TRAP; test -f $rootName_2 && rm $rootName_2; mv $logFile2 $rejectDir/; exit 130" $signals

    date > $logFile2
    hostname >> $logFile2
    root-config --version >> $logFile2
    echo $ROOTSYS >> $logFile2
    git --git-dir $VEGAS/.git describe --tags >> $logFile2
    
    while [[ "`ps cax`" =~ "bbcp" ]]; do 
	sleep $((RANDOM%10+10)); 
    done
    bbCmd="bbcp -e -E md5= $rootName_1 $rootName_2"
    echo "$bbCmd">> $logFile2
    $bbCmd >> $logFile2
    
    while [ -f $queueLaser ]; do
	sleep $((RANDOM%10+20))
    done

    Tstart=`date +%s`
    $stage2cmd $scratchFile $rootName_2 $laserRoot &>> $logFile2 
    completion=$?
    Tend=`date +%s`
    
    echo "Analysis completed in (hours:minutes:seconds)" >> $logFile2
    date -d@$((Tend-Tstart)) -u +%H:%M:%S >> $logFile2
    echo "$stage2cmd $dataFile $rootName_2 $laserRoot" >> $logFile2
    
    test -f $queue2 && rm $queue2
    rm $scratchFile 

    if [ $completion -ne 0 ]; then
	echo -e "\e[0;31m$rootName_2 not processed successfully!\e[0m"
	mv $logFile2 $rejectDir/
	rm $rootName_2
	exit 1
    else
	rm $rootName_1
	cp $logFile2 $workDir/completed/ 	
    fi # command unsuccessfully completed

    if [ `grep -c unzip $logFile` -gt 0 ]; then
	echo -e "\e[0;31m$rootName_2 UNZIP ERROR!!!\e[0m"
	mv $logFile2 $rejectDir/	
    fi

fi # stage 2 command isn't null

exit 0 # great success
