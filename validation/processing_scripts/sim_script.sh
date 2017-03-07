#!/bin/bash 

### creates jobs to submit simulation jobs to process them through stages 4 and/or 5 
### stage 4 files can be used to create EA files 

scriptDir=${0%/*}
envDir=${scriptDir/processing_scripts/environments} 
source $scriptDir/defaults_source.sh
source $envDir/env_Crab.sh 
common_functions=$scriptDir/common_functions.sh 
source $common_functions 
source $scriptDir/set_params.sh
subscript45=$scriptDir/subscript_4or5.sh

# instructions for creating sbatch job 
mem=4gb # for sbatch, it's better if this could be 2gb, but some jobs fail - investigate! 
time4=(3) # hours, should be more if disp 
time5=(1) 

# run settings 
runStage4=false
runStage5=false
noises="100 150 200 250 300 350 400 490 605 730 870"

# default model and simulation set in environment 0

# determines standard cuts, set in set_params.sh 
box_cuts=medium

# automatically apply cuts according to what you have box_cuts set to 
cutMode4=auto
cutMode5=auto

configFlags4="-G_SimulationMode=1"
configFlags5="-G_SimulationMode=1 -Method=VACombinedEventSelection"

runMode=print
nJobsMax=(1000) 

args=`getopt -o 4:5:qQr:bd:z:o:n:c:h:l:w:BD:e:x:L: -l env:,box_cuts:,c4:,c5:,x4:,x5:,submit,BDT:,disp:,cutTel:,override,offsets:,arrays:,atms:,noises:,zeniths: -n sim_script.sh -- "$@"`
eval set -- $args
for i; do 
    case "$i" in
	-4) runStage4=true 
	    stage4subDir=$2
	    shift 2 ;; 
	-5) runStage5=true
	    stage5subDir=$2
	    shift 2 ;; 
	--submit|-q) 
	    runMode=sbatch 
	    shift ;;
	-Q) runMode=sbatch
	    partition=regular 
	    shift ;; 
	-r) runMode="${2}" ; shift 2 ;;
	-n) nJobsMax=$2 ; shift 2 ;; 
	--c4) 
	    case "$2" in 
		auto)
		    cutMode4=auto ;; 
		none)
		    cutMode4=none 
		    cutFlags4="" ;; 
		*)
		    cutMode4=file
		    cutFlags4="-cuts=${2}" ;; 
	    esac 
	    shift 2 ;; 
	--c5)
	    case ${2} in 
		auto) cutMode5=auto ;; 
		none) cutMode5=none # not necessary 
		    cutFlags5="" ;; 
		*)  cutMode5=file 
		    cutFlags5="-cuts=${2}" ;; 
	    esac 
	    shift 2 ;; 
	-z|--zeniths) zeniths="$2" ; shift 2 ;;
	-o|--offsets) offsets="$2" ; shift 2 ;; 
	--noises) noises="$2" ; shift 2 ;;
	--arrays) arrays="$2" ; shift 2 ;;
	--atms) atms="$2" ; shift 2 ;;
	-c|--box_cuts) box_cuts="$2" ; shift 2 ;; 
	--x4)
	    configFlags4="$configFlags4 $2"
	    shift 2 ;; 
	--x5)
	    configFlags5="$configFlags5 $2"
	    shift 2 ;; 
	-x) extraFlags="$2" # add additional flags to both stages, or use above for single 
	    shift 2 ;; 
	-h) hillasMode=HFit
	    configFlags4="$configFlags4 -HillasBranchName=HFit"
	    configFlags5="$configFlags5 -HillasBranchName=HFit"
	    shift ;;
	-l) 
	    case "$2" in 
		auto | custom) 
		    ltMode=$2 ;; 
		*)
		    ltMode=single
		    ltName=$2 ;; 
	    esac
	    shift 2 ;; 
	-w) simWork=$2 ; shift 2 ;; 
	-e) environment="$2" 
	    shift 2 ;;
	--disp) 
	    stg4method=disp 
	    dispMethod=${2}
            configFlags4="$configFlags4 -DR_Algorithm=Method${2}" #t stands for tmva, Method6 for average disp and geom 
	    DistanceUpper=1.38 
	    time4=12 
            echo "using disp method"
	    zenith="Z55-70" 
            shift 2 ;;
	--cutTel)
	    configFlags4="$configFlags4 -CutTelescope=${2}/1"
	    shift 2 ;; 
  	-B) # only makes stage 5 BDT training ready, doesn't apply BDTs
	    prepareBDT=true
	    cutMode5=none # not necessary 
	    cutFlags5="" 
	    shift ;; 
	--BDT) # actually applies BDTs, requires weights file
	    configFlags5="$configFlags5 -UseBDT=1"
	    configFlags5="$configFlags5 -BDTDirectory=${2}"
	    test -d $2 || ( echo -e "\e[0;31m Weights directory does not exist! \e[0m"; exit 1 ) 
	    shift 2 ;; 
	-D) DistanceUpper=${2} ; shift 2 ;; 
	--override) 
	    configFlags4="$configFlags4 -OverrideLTCheck=1"
	    shift ;; 
	-L) logDir="$2"
	    shift 2 ;; 
	--) shift ;;
    esac # option cases
done # loop over options 

usage() {

    echo $0 
    echo 
    # complete this 


} # print usage 

for env in $environment; do  source $env || exit 1; done 
test -n "$simWork" || ( echo '$simWork must be set!!! Make sure you are supplying a proper environment file' && usage ; exit 1 )
test -d "$simWork" || ( echo "$simWork does not exist!!! Exiting! " && exit 1 ) 
processDir=$simWork/processed 
queueDir=$simWork/queue
logDir=$simWork/log
backupDir=$simWork/backup
completeDir=$simWork/completed_jobs
failDir=$simWork/failed_jobs

for dir in $processDir/$stage4subDir $processDir/$stage5subDir $logDir/$stage4subDir $logDir/$stage5subDir $queueDir $backupDir $logDir/errors $completeDir $failDir; do 
    if [ ! -d $dir/$subDir ] && [ $dir/$subDir != $processDir/errors ]; then
	echo "must create $dir/$subDir"
	[ "$runMode" != print ] && makeSharedDir $dir/$subDir -p 
    fi 
done  # check dirs exist 

nJobs=(0) 

for array in $arrays; do
    for atm in $atms; do
	for zen in ${zeniths//,/ }; do 
	    for offset in ${offsets//./}; do 
		for noise in $noises; do

		    if (( nJobs >= nJobsMax )); then
			exit 0 
		    fi

		    # set the cuts parameters, table names, and simFileBase 
		    setCuts
		    setSimNames $zen $offset $noise # $array and $atm must also be set 
		    subDir=Oct2012_${array}_ATM${atm}/${zen}_deg # deprecated 

		    rootName_2=$simFile2 # set by setSimNames 
		    rootName_4=$processDir/${stage4subDir}/${simFileBase}.stage4.root
		    queueFile_4=$queueDir/${stage4subDir}_${simFileBase}.stage4${extension}
		    rootName_5=$processDir/${stage5subDir}/${simFileBase}.stage5.root
		    queueFile_5=$queueDir/${stage5subDir}_${simFileBase}.stage5${extension}

		    # reset job variables 
		    stage4cmd=""; stage5cmd=""
		    jobCmds=""; stages=""; queue=""
		    runBool=false 
		    timeTotal=(0) 
		    logFile4="" ; logFile5="" 
		    

		    ##### STAGE 4 #####

		    if [ "$runStage4" == "true" ]; then
			logFile4="$logDir/$stage4subDir/${simFileBase}.stage4.txt"
			if [ ! -f $rootName_4 ] && [ ! -f $queueFile_4 ]; then
			    if [ -f $rootName_2 ]; then

				if [ "$ltMode" == custom ]; then
				    ltName=$ltBase # set in setCuts 
				elif [ "$ltMode" == auto ]; then
				    # not functioning currently 
				    ltName=$ltAuto
				fi # automatic lookup table, should match name from tableMaker.sh 
				ltFile=$ltDir/${ltName}.root
				test -f $ltFile || echo -e "\e[0;31mLookup table $ltFile does not exist! \e[0m"
				tableFlags="-table=${ltFile}"

				if [ "$stg4method" == disp ]; then
				    
				    if [ "$dispMethod" == 5t ]; then
					dtName=TMVA_Disp.xml
				    else
				       	dtName=dt_Oct2012_${array}_ATM${atm}_GrISUDet_${ltVegas}_7sam_${offset}wobb_Z50-65_std_d1p38_allNoise.root 
					# specify disp mode # deprecated ^ 
				    fi
				    
				    dtFile=$ltDir/${dtName}
				    test -f $dtFile || echo -e "\e[0;31mDisp table $dtFile does not exist! \e[0m"
				    tableFlags="$tableFlags -DR_DispTable=$dtFile" 
				fi # disp method 

				if [ "$cutMode4" == auto ]; then
				    cutFlags4="$stage4cuts_auto"
				fi # set cuts automatically based on array and box_cuts 
				# which
				stage4cmd="vaStage4.2 $configFlags4 $tableFlags $cutFlags4 $extraFlags $rootName_4"
				test "$array" == "oa" && stage4cmd="$stage4cmd -TelCombosToDeny=T1T4" # config only for old array
				echo "$stage4cmd" 
				
				runBool=true 
				jobCmds="$subscript45 \"$stage4cmd\" $rootName_4 $rootName_2 \"$environment\" &> $logFile4 " 
				stages="${stages}4" 
				timeTotal=$((timeTotal+time4))
				queue=$queueFile_4 
				
			    else
				echo -e "\e[0;31mSource simulation file $rootName_2 does not exist! check directory\e[0m"
			    fi # if stage 2 sim file does exist
			fi # if stage 4 file does not exist
		    fi # run stage 4
		    
		    ##### STAGE 5 #####
		    if [ $runStage5 == "true" ]; then

			stage5Dir=$processDir/$stage5subDir
			
			if [ ! -f $rootName_5 ] && [ ! -f $queueFile_5 ]; then 
			    if [ -f $rootName_4 ] || [ "$stage4cmd" ] || [ -f $queueFile_4 ] || [ "$runMode" == print ]; then 
				logFile5="$logDir/$stage5subDir/${simFileBase}.stage5${extension}.txt"
				#sims organized into directories for training 
				
				if [ "$cutMode5" == auto ]; then
				    #setCuts
				    cutFlags5="$stage5cuts_auto"
				elif [ "$cutMode5" != none ]; then 
				    cutFlags5=""
				fi # automatic cuts for stage 5 based on array 
				
				stage5cmd="vaStage5 $configFlags5 $cutFlags5 $extraFlags -inputFile=$rootName_4 -outputFile=$rootName_5"
				echo "$stage5cmd"

				[ "$runBool" == true ] && jobCmds="$jobCmds && "
				jobCmds="$jobCmds $subscript45 \"$stage5cmd\" $rootName_5 $rootName_4 \"$environment\" &> $logFile5 " 
				runBool=true
				stages="${stages}5"
				timeTotal=$((timeTotal+time5)) 
				queue="$queue $queueFile_5" 

			    else
				echo -e "\e[0;31mStage 4 file $rootName_4 does not exist and is not in queue!\e[0m"
			    fi # either stage 4 file exists or is in queue 
			fi # stage 5 file does not exist 
		    fi # run stage 5

		    # submit jobs 
		    ((timeTotal > 10)) && timeStamp=${timeTotal}:00 || timeStamp=0${timeTotal}:00:00 		    
		    
		    if [ "$runMode" != print ] && [ "$runBool" == true ]; then 
			
			$runMode $redirection <<EOF  
$submitHeader   
#SBATCH -J ${stages}_${simFileBase}_${stage4subDir} 
#SBATCH -o $logDir/errors/${simFileBase}.txt  
#SBATCH --time=$timeStamp 

trap 'for q in $queue; do  test -f \$q && rm -v \$q; done ' EXIT 

date 
echo "image to be loaded: $imageID" 
echo "slurm ID: $SLURM_JOBID"

for log in $logFile4 $logFile5; do 
    test -f \$log && mv -v \$log $backupDir/
done 

# deal with cuts file 
module load shifter
shifter $volumeDirective /bin/bash -c '$jobCmds' 

exitCode=\$? 
echo "exit status: \$exitCode" 
exit \$exitCode 

EOF
			completion=$? 
			if [ "$completion" -eq 0 ]; then 
			    [ "$runMode" == "sbatch" ] && touch $queue 
			    nJobs=$((nJobs+1))
			fi
			
			
		    fi # runMode isn't print 
		    

		done # loop over noises
	    done # loop over offsets
	done # zeniths
    done # atmospheres
done # loop over arrays

exit 0 # success
