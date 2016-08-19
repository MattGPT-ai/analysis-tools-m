#!/bin/bash 

# VA subscript, for use with larger submission scripts
scratchDir=/scratch1/scratchdirs/mbuchove
workDir=/project/projectdirs/m1304/mbuchove

if [ $3 ]; then
    cmd="$1"
    dataFile=$2
    laserRoot=$3
else
    echo -e "\e[0;31mmust specify stage 1 command, data file, and root filename!\e[0m"
    exit 1 # failure
fi

if [ $4 ]; then 
    environment="$4"
    for env in $environment; do 
	source $environment
    done
fi
source $THISROOT 

trashDir=$HOME/.trash
laserDir=$workDir/lasers #needs to match process_script.sh
logDir=$laserDir/log
rejectDir=$laserDir/rejected
queueDir=$laserDir/queue

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
for sig in $signals; do 
    trap "echo \"TRAP! Signal: $sig\"; rm $laserRoot; mv $logFile $rejectDir/; exit $sig" $sig
done 
# clean up for specific signals 

# just print some useful information about the run 
hostname 
echo $ROOTSYS 
root-config --version 
git --git-dir $VEGAS/.git describe --tags


sleep $((RANDOM%10));
#while [[ "`ps cax`" =~ " bbcp" ]]; do
#    sleep $((RANDOM%10+10));
#done
bbCmd="bbftp -u bbftp -m -p 12 -S -V -e \"get $dataFile $scratchDir/\" gamma1.astro.ucla.edu"
echo "$bbCmd" 
#$bbCmd 
bbftp -u bbftp -m -p 12 -S -V -e "get $dataFile $scratchDir/" gamma1.astro.ucla.edu


module load shifter
##SBATCH --image=docker:registry.services.nersc.gov/0dc266c2474d:latest
##SBATCH --partition=shared
##SBATCH --volume="/scratch1/scratchdirs/mbuchove:/external_data"
##SBATCH --output=$HOME/log/shifter_log.txt

Tstart=`date +%s`
shifter --volume="$scratchDir:/external_output" $cmd ${scratchFile/$scratchDir/\/external_output} /external_output/${laserRoot##*/} 
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
    #mv $logFile $rejectDir/
    #rm $laserRoot
    exit 1
fi # unzip error, sigh

test -f $rejectDir/${logFile##*/} && mv $rejectDir/${logFile##*/} $trashDir/
cp $logFile $laserDir/completed/ 

exit 0 # great success
