#!/bin/bash 
# script to retrieve all data files for a loggen file 

scriptDir=${0%/*}
common_functions=$scriptDir/common_functions.sh 
source $common_functions 
source $scriptDir/defaults_source.sh

usage() {
    echo "usage:
$0 /path/to/loggenfile [-e /path/to/envfile] [-n nJobsMax] [--submit] 

these are the same basic options as process_master.sh
make sure your environment sets \$dataDir to where you want it
by default, it goes to your \$CSCRATCH/data " 

    exit 1 
}

n=(0)
nJobsMax=(5) # this is the limit of parallel hsi sessions 

# process the arguments 
parseCommonOpts "$@"
eval set -- "$args"


loggenfile=$1

for env in $environment; do source $env || exit 1; done 
# environment should set $dataDir
test -n "$loggenfile" && test -n "$dataDir" || usage # exits 

for dir in $dataDir $dataDir/log $dataDir/failed_jobs; do 
    if [ ! -d $dir ]; then
	echo "The directory $dir does not exist and will be created if you run this script with -r or --submit"
	[ "$runMode" ] && makeSharedDir $dir || exit 
    fi 
done 

laserArray=()

job(){ # date number 

    local date=${1}
    local runNum=${2}
    local fullDir=$dataDir/d${date}
    

    # this should match command in job script 
    copyCmd="getDataFile data/d${date}/${runNum}.cvbf"
    echo "$copyCmd"

    logFile=$dataDir/log/getDataFile_${runNum}_log.txt
    if [ "$runMode" ]; then 
	submitHeader="$(createBatchHeader -N ${runNum}_getDataFile -o $logFile -t 1 -q xfer)
#SBATCH -M esedison" # special flag for edison login node to transfer hsi files 


	$runMode <<EOF
$submitHeader
#trap "rm -v $queue" EXIT 

source $common_functions
$copyCmd 
exitCode=\$? 

echo "exit code: \$exitCode"
#test "\$exitCode" -eq 0 || mv -v $logFile $dataDir/failed_jobs 

exit 
EOF
	n=$((n+1))
    fi # if runMode is set 

} # create job script for bbftp transfer 


test -d $dataDir/log || echo "$fullDir/log does not exist! create this directory if you wish to log these jobs"

# begin the main loop over the lines in the loggen file 
while read -r line && ((n<nJobsMax)); do 
    set -- $line

    date=$1
    runNum=$2
    fullDir=$dataDir/d${date}

    for laser in $3 $4 $5 $6; do 
	elementIn "$laser" "${laserArray[@]}"
	inArray=$?
	if [[ "$laser" != "--" ]] && [ "$inArray" -ne 0 ]; then 
	    laserArray+=("$laser")
	fi # add to array if not present 
    done # loop over lasers in loggen file  

    # don't create job if file exists, or is in progress. * includes temporary bbftp file 
    test -f $fullDir/${runNum}.cvbf* && continue 

    # run the job 
    job "$date" "$runNum"

	
done < $loggenfile # loop over loggen file 

#printf '%s\n' "${laserArray[@]}"

for laser in ${laserArray[@]}; do 

    laserDate=`mysql -h romulus.ucsc.edu -u readonly -s -N -e "use VERITAS; SELECT data_end_time FROM tblRun_Info WHERE run_id=${laser}"` 
    laserDate=${laserDate// */} 
    laserDate=${laserDate//-/} 

    fullDir=$dataDir/d${laserDate}
    #echo "laser $fullDir/${laser}.cvbf"
    test -f $fullDir/${laser}.cvbf && continue 

    job $laserDate $laser 
done # loop over lasers in array 

exit 0 # great job 
