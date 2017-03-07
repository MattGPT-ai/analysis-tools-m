#!/bin/bash

# this script runs a lightcurve analysis. 



scriptDir=${0%/*}
envDir=${scriptDir/processing_scripts/environments} 
source $scriptDir/defaults_source.sh
source $envDir/env_Crab.sh 
source $envDir/env_PKS1424.sh 
common_functions=$scriptDir/common_functions.sh 
source $common_functions 

sourceName=PKS1424

#arrays="na ua"
atms="_ATM21 _ATM22 '' " 
box_cuts=soft 
array='ua'
atm=21

source $scriptDir/set_params.sh


test -n "$1" && runMode="$1" || runMode=cat
test -n "$2" && source $2 
#test -n "$2" && energy=$2 

ext=_daily_no-docker 
timebin=1440
#525960 is 365.25 days, 86400 is 1 day 

#energy=5000
#ext=_E${energy}
#opts=-LC_MinEnergy=${energy} # TeV 

logDir=$workDir/log/lightCurves
checkForDirs $runMode $workDir/log $logDir $workDir/results 

#for array in $arrays; do 
#for atm in $atms; do 
for atm in 21 22; do 

    logFile=$logDir/lightCurve_${sourceName}${atm}${ext}.txt
    outputFileName=$workDir/results/${sourceName}_lightCurve${atm}${ext}.root
    s6FileName=$workDir/results/${sourceName}_validation_2013_${box_cuts}_spectrum_rc7_s6.root
    #s6FileName=$workDir/results/${sourceName}_validation_2013${atm}_soft_spectrum_rc7_s6.root
    stage5list=$scriptDir/../stage6_runlists/${sourceName}_2013_${box_cuts}_stg5list.txt

    setCuts $box_cuts $array 
    eaFlag="-LC_EAFile=\"$finishedEA\" "

    [ "$use_docker" == false ] && volumeDirective=""

    for file in $s6FileName $stage5list $finishedEA; do 
	test -f "$file" || echoErr "$file does not exist. "
    done

    if [ -f "$outputFileName" ]; then 
	echo "$outputFilename already exists! "
	echo "Type 'Y' to move this file to backup and rerun"
	read response 
	if [ "$response" == 'Y' ]; then 
	    mv -v $outputFileName $workDir/backup/
	else
	    continue
	fi
    fi # 
    test $runMode != cat && test -f $logFile && mv -v $logFile $workDir/backup/
    
    cmd="`which vaMoonShine` -LC_S6FileName=\"$s6FileName\" -LC_OutputFileName=\"$outputFileName\"  -LC_S5FileList=\"$stage5list\" -LC_TimeBin=$timebin $eaFlag $opts"
    dump='cd $VEGAS/resultsExtractor/macros && root -l -b -q "dumpLightCurve.C(\"$outputFileName\")" '

    $runMode <<EOF
$submitHeader
#SBATCH -J lc_${sourceName}${ext} 
#SBATCH -o $logFile
#SBATCH --time=03:00:00 
#SBATCH --mem=2gb

source $common_functions
logInit

failed_job() {
    test -f "$outputFileName" && rm -v $outputFileName
    mv -v $logFile $workDir/failed_jobs/
} 

trap failed_job 1

$docker_load 
$docker_cmd $volumeDirective /bin/bash -c '$cmd && $dump'
exitCode=\$?

echo "$cmd"

#test \$exitCode -ne 0 && failed_job

#logStatus $logFile 
exit \$exitCode

EOF

done # loop over arrays 

exit 0 # great job 
