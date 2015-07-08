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

trap "rm $scratchFile $queue1 $queue2 $rootName_1 $rootName2; echo TRAP > $rejectDir/${runNum}.stages12.txt; exit 130" 1 2 3 4 5 6

sleep $((RANDOM%10+5))


while [[ "`ps cax`" =~ "bbcp" ]]; do
    sleep $((RANDOM%10+10));
done
bbCmd="bbcp -e -E md5= $dataFile $scratchDir/"

if [ "$stage1cmd" != "NULL" ]; then
    if [ -f $logFile1 ]; then
	mv $logFile1 $trashDir/
    fi
    echo "$bbCmd" >> $logFile1
    $bbCmd &>> $logFile1
fi # stage 1 not passed as null
if [ "$stage2cmd" != "NULL" ]; then
    if [ -f $logFile2 ]; then
	mv $logFile2 $trashDir/
    fi
    echo "$bbCmd" >> $logFile2
    $bbCmd &>> $logFile2
fi # stage 2 not passed as null
    
if [ "$stage1cmd" != "NULL" ]; then
    date > $logFile1
    hostname >> $logFile1 
    root-config --version >> $logFile1
    echo $ROOTSYS >> $logFile1
    git --git-dir $VEGAS/.git describe --tags
    
    $stage1cmd $scratchDir/${runNum}.cvbf $rootName_1 &>> $logFile1
    completion=$?
    
    test -f $queue1 && rm $queue1
    echo "" >> $logFile1
    echo "$stage1cmd $dataFile $rootName_1" >> $logFile1
    
    if [ $completion -ne 0 ]; then
	echo -e "\e[0;31m$rootName_1 not processed successfully!\e[0m"
	mv $logFile1 $rejectDir/
	rm $rootName_1
	rm $queue2
	rm $scratchDir/${runNum}.cvbf
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

    date > $logFile2
    hostname >> $logFile2
    root-config --version >> $logFile2
    echo $ROOTSYS >> $logFile2
    git --git-dir $VEGAS/.git describe --tags
    
    while [[ "`ps cax`" =~ "bbcp" ]]; do 
	sleep $((RANDOM%10+10)); 
    done
    echo "bbcp -e -E md5= $rootName_1 $rootName_2" >> $logFile2
    bbcp -e -E md5= $rootName_1 $rootName_2 &>> $logFile2
    
    while [ -f $queueLaser ]; do
	sleep $((RANDOM%10+20))
    done

    $stage2cmd $scratchDir/${runNum}.cvbf $rootName_2 $laserRoot &>> $logFile2 
    completion=$?
    
    echo "" >> $logFile2
    echo "$stage2cmd $dataFile $rootName_2 $laserRoot" >> $logFile2
    
    test -f $queue2 && rm $queue2
    rm $scratchDir/${runNum}.cvbf 

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

#rm 12logfile if empty
#if [ `cat $logDir/${runNum}.stage12.txt | wc -l` -e 0 ]; then 
#    rm $logDir/${runNum}.stage12.txt
#fi


exit 0 # great success
