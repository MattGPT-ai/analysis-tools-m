#!/bin/bash

### process_script.sh processes the files in a logGen format runlist file through the selected stages with the selected options ### 

##### SET DEFAULTS #####
scriptName=${0##*/}
scriptDir=${0/\/$scriptName}
common_functions=$scriptDir/common_functions.sh # has functinos common to multiple scripts 
setCuts=$scriptDir/set_params.sh # has functions that automatically set cuts and generate filenames according to array / epoch 
source $common_functions 
source $scriptDir/defaults_source.sh # defaults source must come after common functions as it uses a hash function defined there
source $setCuts

# any defaults that are overridden should be changed in environment file supplied by -e 
#source $scriptDir/../environments/env_Crab.sh # set all the necessary default parameters. you can override all of these parameters with the -e flag  
laserSubscript=$scriptDir/subscript_laser.sh # subscripts used to run full job and checks on different stages 
subscript12=$scriptDir/subscript_stage1and2.sh
subscript45=$scriptDir/subscript_4or5.sh


# for batch job scripts 
mem=2gb 

# these are not recommended to go into environment, times should be different for sims (sim_script.sh) vs. data 
timeLaser="03:00:00"
time1=(4) # hours 
time2=(8) # time required for each stage of the job 
time4=(2) 
time5=(1) 
priority=0
signals="1 2 3 4 5 6 7 8 11 13 15 30"

box_cuts=medium
method=std # or hfit 
# for custom LT files

stage4cuts=auto
stage5cuts=auto
applyTimeCuts=true

configFlags4=""
# make an option for setting this 
configFlags5="-Method=VACombinedEventSelection -CMC_RemoveCutEvents=1"
#configFlags5="-Method=VAStereoEventSelection -CMC_RemoveCutEvents=1"
suffix='' # only applied to stages 4 and 5 by default
useStage5outputFile=true
useBDT=false
autoCutTels4=false
#read2from4=

reprocess=false
runMode=print # should make 3 modes - print, run, and other 

timecuts=auto # stage 5 timecuts, fetched from sql query if set to auto, or use file made with time_cut_gen.sh 

nJobs=(0) # number of submits 
nJobsMax=(1000) 

stage1subDir=stg1

runLaser=false
runStage1=false
runStage2=false
runStage4=false
runStage5=false
#runStage6=false # deprecated 

usage() { # print the usage details 
    echo -e "Usage: ./${0##*/} [stageflags] /path/to/runlistfile [options]"
    echo -e "\t     -{stageNum} stagesubdir 
\t\t run stage number, saving files into specified subdirectory
\t\t the subdirectory should specify stage number, VEGAS version,
\t\t and some indication of cuts, options, special algorithms applied
\t\t the full details are not necessary, as the full commands are logged
\t\t into the log directory "
    echo -e "-e /path/to/environmentfile
\t\t "
    echo -e "\tDefault env is disabled to prevent use of incorrect environment"
    echo -e '\t-x{stageNum} "options" 
\t\t provide extra options to corresponding stage number. 
\t\t make sure you use quotes if the option has spaces' 
    echo -e "\t--submit | -q \tsubmit jobs with specified job submitter, e.g. $batch_cmd "
    echo -e "\t-r cmd \t run the job script with another program, e.g. bash, cat" 
    echo -e "\t--no-docker \t turn off the docker switches"
    echo -e "*note: docker is only supported in batch mode on NERSC"
    echo -e "\t standard validation runlists can be found in \$VEGAS/validation/test_samples/"
    echo -e "\t--lt [custom|auto|/path/to/ltfile.root]"
    echo -e "change the mode for finding LTs. default is custom, which uses the filenames that would be created by your analysis. auto uses filenames from the archived v250 LTs. or specify a single name to be used for all jobs"
    echo -e "\tFind other options in the top of this script!"
    echo -e "\t-o \t (BDTs) run stage5 optimization instead of training"
    echo -e "\t-h \tenable HFit"
    exit 1
} # usage 


####### Process Arguments using getopt #######
parseCommonOpts "$@"
eval set -- "$args"

args=`getopt -o l1:2:4:5:c:hB:s:p:kdm:o:ibL -l box_cuts:,c4:,c5:,xl:,x1:,x2:,x3:,x4:,x5:,d1:,d2:,d4:,d5:,timecuts:,mem:,disp:,atm:,deny:,BDT:,lt:,reprocess -n "$scriptName" -- "$@"`
# use :: for optional args 
eval set -- $args 
# loop through options
for i; do  
    case "$i" in 
	# flags for running stages and setting their directories
	-l) runLaser=true ; shift ;;
	-1) runStage1=true # run stage 1 or signals stage 2 to save stage 1 files 
	    stage1subDir=$2 ; shift 2 ;;
	-2) runStage2=true ; runLaser=true # runs stage 1 and 2 
	    stage2subDir=$2; shift 2 ;;
	-4) runStage4=true 
	    stage4subDir="$2" ; shift 2 ;;
	#-F) use copy stage4 instead of stage2 to save having stage2 copies
	-5) runStage5=true
	    stage5subDir="$2" ; shift 2 ;;
	--xl) customFlagsL="$customFlagsL $2" ; shift 2 ;; 
	--x1) customFlags1="$customFlags1 $2" ; shift 2 ;; 
      	--x2) customFlags2="$customFlags2 $2" ; shift 2 ;; 
	--x4) customFlags4="$customFlags4 $2" ; shift 2 ;; 
	--x5) customFlags5="$customFlags5 $2" ; shift 2 ;; 
	--c4) stage4cuts=$2 # choose auto to automatically choose optimized cuts, or none to not cut
	    shift 2 ;;
	--c5) stage5cuts=$2
	    # same as for stage 4
	    shift ; shift ;;
	--box_cuts|-c) 
	    box_cuts=$2 ; shift 2 ;;
	-m|--mem) mem="$2" ; shift 2 ;; 
	--timecuts)
	    timecuts=$2 ; shift 2 ;; 
	# to set directories without choosing to run 
	--d1) stage1subDir=$2 ; shift 2 ;;
	--d2) stage2subDir=$2; shift 2 ;;
	--d4) stage4subDir=$2 ; shift 2 ;;
	--d5) stage5subDir=$2 ; shift 2 ;;
	-L) mode=lightcurve # | --lc
	    configFlags5="-Method=VAStereoEventSelection -CMC_RemoveCutEvents=1"
	    shift ;; 
	--reprocess)
	    reprocess=true ; shift ;;
	-b) mode=background # | --background # for BDT background 
	    configFlags5="-Method=VACombinedEventSelection"  
	    shift ;;
	-B|--BDT) # mode options should be used first, before other things that modify stage5 config 
	    configFlags5="-Method=VACombinedEventSelection -UseBDT=1"
	    useBDT=true
	    stage5cuts=none
	    weightsDirBase="$2" # can append array to end, e.g. _V5
	    echo "BDT mode enabled. The argument is the weights directory, if the name contains the string EPOCH that will be replaced by e.g. V5"
	    # useStage5outputFile=true
	    shift 2 ;;
	--disp) 
	    stg4method=disp
	    dispMethod="$2"
	    configFlags4="$configFlags4 -DR_Algorithm=Method${dispMethod}" #t stands for tmva, Method6 for average disp and geom
	    DistanceUpper=1.38
	    time4=(6) # stage 4 takes much more time now 
	    shift 2 ;; 
	--atm) # use one atmosphere for every run 
	    ATM=$2 ; shift 2 ;; 
	--lt)
	    ltMode=$2
	    shift 2 ;; 
	-h) method=hfit
	    configFlags2="$configFlags2 -HillasFitAlgorithum=2DEllipticalGaussian"
	    configFlags4="$configFlags4 -HillasBranchName=HFit"
	    configFlags5="$configFlags5 -HillasBranchName=HFit"
	    shift ;; 
	-i) useStage5outputFile=false ; shift ;;
	--deny)
	    TelCombosToDeny="$2" ; shift 2 ;; 
	-o) configFlags4="$configFlags4 -OverrideLTCheck=1" ; shift ;; 
	# these flags will override any previous flags, as they come after 
	-k) simulation=KASCADE
	    shift ;; 
	--) shift; break ;;
	#*) echo "option $i unknown!" ; exit 1 ;; # may not be necessary, getopt rejects unknowns 
    esac # end case $i in options
done # loop over command line arguments 
### END OPTIONS ###

if [ $1 ]; then
    readList="$1"
else 
    echoErr "must specify a runlist!"
    usage
fi # runlist specified
if [ $2 ]; then
    echo "Some arguments weren't processed properly: $2 - exiting!"
    exit 1 
fi

for env in $environment; do  source $env || exit 1; done

test -z "$workDir" && ( echoErr "working directory \$workDir must be set!!!" ; exit 1 )
# check all important directories exist 

if [ "$use_docker" == true ] && [ "$runMode" != "print" ]; then 
    # make sure shifter image is ready 
    echo "attempting to pull docker image. this could take some time!"
    echo "shifterimg pull docker:registry.services.nersc.gov/$imageID"
    $docker_load 
    img_pull=`shifterimg pull docker:registry.services.nersc.gov/$imageID`
    echo $img_pull
    [[ "$img_pull" =~ "READY" ]] || exit 1 
    # expand on batch job header 
fi 

processDir=$workDir/processed
logDir=$workDir/log
failDir=$workDir/failed_jobs
queueDir=$workDir/queue
backupDir=$workDir/backup

laserProcessed=$laserDir/processed # shorten variable name 
laserQueue=$laserDir/queue
laserLog=$laserDir/log
laserBackup=$laserDir/backup
laserArray=() # keeps track of laser jobs that have been submitted 

### quick check for files and directories ###
dirs=()
for dir in $workDir $laserDir; do 
    for subDir in queue processed log completed_jobs failed_jobs results config backup; do
	dirs+=("$dir/$subDir")
    done # could make common functions for checking dirs
done # do for both working directory and laser directory 
subDirs="$stage1subDir $stage2subDir batch_out"
[ "$runStage4" == true ] && subDirs="$subDirs $stage4subDir"
[ "$runStage5" == true ] && subDirs="$subDirs $stage5subDir"
for dir in $processDir $logDir; do
    for subDir in $subDirs; do
	dirs+=("$dir/$subDir")
    done # loop over subdirs
done # loop over main dirs, process and log
delete=($processDir/batch_out)
dirs=( "${dirs[@]/$delete}" )
checkForDirs $runMode ${dirs[@]}


while read -r line
do # loop through loggen file, determine lasers and commands for all stages 
    
    test $nJobs -lt $nJobsMax || exit 0 # for the -n flag 
    
    set -- $line # split up line into args 
    
    runDate=$1
    runNum=$2

    # empty out jobs for new run 
    stage1cmd=""; stage2cmd=""; stage4cmd=""; stage5cmd=""
    jobCmds=""; stages=""; queue=""
    get_data="" # gets filled with getDataFile command to retrieve data file if stage 1 or 2 need to be run 
    runBool=false # becomes true when any stage needs to be run 

    # could condense into an array 
    rootName_1="$processDir/${stage1subDir}/${runNum}.stage1.root"         
    rootName_2="$processDir/${stage2subDir}/${runNum}.stage2.root"
    rootName_4="$processDir/${stage4subDir}/${runNum}.stage4.root"
    rootName_5="$processDir/${stage5subDir}/${runNum}.stage5.root"
    queueFile_1="$queueDir/${stage1subDir}_${runNum}.stage1"
    queueFile_2="$queueDir/${stage2subDir}_${runNum}.stage2"
    queueFile_4="$queueDir/${stage4subDir}_${runNum}.stage4"
    queueFile_5="$queueDir/${stage5subDir}_${runNum}.stage5"
    logFile1=""
    logFile2=""
    logFile4=""
    logFile5=""
    timeTotal=(0) 

    # use the date to properly select epoch, then set appropriate cuts for epoch and box_cuts 
    setEpoch $runDate
    setCuts $box_cuts $array $atm
    setTableNames


    if [ "$runStage1" == true -o "$runStage2" == true -o "$runLaser" == true ]; then
	
	laserRoot="NULL"
	laserNum="NULL"
	numTels=(0)
	laser1=$3; laser2=$4; laser3=$5; laser4=$6 # shorten variable names
	combinedLaserName="combined_${laser1}_${laser2}_${laser3}_${laser4}.laser"
	runLaser=false
    	
	for n in $laser1 $laser2 $laser3 $laser4; do
	    # loop through the lasers
	    if [ "$n" != "--" ]; then
		
		numTels=$((numTels + 1))
		
		if [ "$laserNum" == "NULL" ]; then
		    # set the first laser number 
		    laserNum=$n
		    runLaser=true
		    
		elif [ "$laserNum" != "$n" ]; then
		    laserRoot="$laserProcessed/${combinedLaserName}.root"
		    runLaser=true
		fi # new laser num is different from previous
		
		laserData="NULL"
		if [ "$runLaser" == true ]; then 
		    queueFileLaser=$laserQueue/${n}.laser 
		    laserFilename=$laserProcessed/${n}.laser.root
		    if [ ! -f $laserFilename -a ! -f $queueFileLaser ]; then
			# laser file needs to be processed: 
			laserDate=$runDate
			# could test for laser data file 

			elementIn "${n}" "${laserArray[@]}"
			inArray=$?
			[ "$inArray" -eq 0 ] && continue # skip this laser if it has already been printed 
			laserArray+=("${n}")

			laserCmd="vaStage1 $customFlagsL"
			echo "$laserSubscript \"$laserCmd\" data/d${laserDate}/${n}.cvbf $laserFilename"
			logFileLaser=$laserLog/${n}.laser.txt
			### run normal laser 
			if [ "$runMode" != "print" ]; then
			    
			    laserDate=`mysql -h romulus.ucsc.edu -u readonly -s -N -e "use VERITAS; SELECT data_end_time FROM tblRun_Info WHERE run_id=${n}"`
			    laserDate=${laserDate// */}
			    laserDate=${laserDate//-/}
			    laserData=data/d${laserDate}/${n}.cvbf 
			    fullCmd="$laserSubscript \"$laserCmd\" $laserData $laserFilename" 
			    
			    echo $laserData
			    
			    [ "$runMode" == "$batch_cmd" ] && test -f $logFileLaser && mv $logFileLaser $laserBackup/
			    # hsi command can be executed in shell, but not from docker image 
			    [ "$copy_local" == true ] || getDataFile $laserData || continue 

			    submitHeader=$(createBatchHeader -N ${n}.laser -o $logFileLaser -M $mem -T ${timeLaser} -p $priority )

			    $runMode <<EOF
$submitHeader

trap "test -f $queueFileLaser && rm -v $queueFileLaser" EXIT 

for s in $environment $common_functions; do source \$s ; done 

# doesn't work in shifter image 
echo "attempting to fetch laser file"
sleep $((RANDOM%3))


$docker_load
$docker_cmd $volumeDirective $laserSubscript "$laserCmd" $laserData $laserFilename "$environment"

exit 

EOF
			    completion=$?
			    [ "$runMode" == "$batch_cmd" ] && test "$completion" -eq 0 && touch $queueFileLaser
			    nJobs=$((nJobs+1))
			fi # end batch submission for regular laser 
		    fi # laser file does not yet exist
		fi # run bool is true		
	    fi # laser isn't --
	done # for loop over telescopes
	
	if [[ "$laserRoot" == "NULL" ]]; then
	    
	    laserRoot="$laserProcessed/${laserNum}.laser.root"
	    
	else # process the combined laser file
	    queueFileLaser=$laserQueue/${combinedLaserName}
	    combinedLaserRoot=$laserProcessed/${combinedLaserName}.root
	    if [ ! -f $combinedLaserRoot ] && [ ! -f $queueFileLaser ]; then		    
		
		if [ "$runMode" == "print" ]; then 
		    elementIn "${combinedLaserName}" "${laserArray[@]}"
		    inArray=$?
		    [ "$inArray" -eq 0 ] && continue # skip this laser if it has already been printed 
		    laserArray+=("${combinedLaserName}")
		fi
		
		cmd="root -b -l -q \"combineLaser.C(\\\"$laserProcessed/${combinedLaserName}.root\\\", \\\"$laserProcessed/${laser1}.laser.root\\\", \\\"$laserProcessed/${laser2}.laser.root\\\", \\\"$laserProcessed/${laser3}.laser.root\\\", \\\"$laserProcessed/${laser4}.laser.root\\\")\" "
		echo "$cmd"
		logFileLaser=$laserLog/${combinedLaserName}.txt

		submitHeader=$( createBatchHeader -N ${combinedLaserName} -o $logFileLaser -M $mem -T ${timeLaser} -p $priority )
				
		if [ "$runMode" != "print" ]; then 
		    [ "$runMode" == "$batch_cmd" ] && test -f $logFileLaser && mv $logFileLaser $backupDir/
		    
		    $runMode <<EOF
$submitHeader

source $common_functions


failed() {
    test -f $combinedLaserRoot && rm -v $combinedLaserRoot
    mv -v $logFileLaser $failDir/
}

trap 'test -f $queueFileLaser && rm -v $queueFileLaser' EXIT 
signals="1 2 3 4 5 6 7 8 11 13 15 30"
for sig in $signals; do 
    trap "echoErr \"TRAP! Signal: \$sig\"; failed $sig" \$sig
done 

logInit 


pwd 
t=(0)
while [ -f $laserQueue/${laser1}.laser -o -f $laserQueue/${laser2}.laser -o -f $laserQueue/${laser3}.laser -o -f $laserQueue/${laser4}.laser ]; do
    (( t > 175 )) && failed # number of minutes - 5 
    sleep 60 
    t=$((t+60)) 
done # make sure the times here are consistent; waiting for other lasers 

rsync -v $laserProcessed/${laser1}.laser.root $combinedLaserRoot
echo "rsync -v $laserProcessed/${laser1}.laser.root $combinedLaserRoot"

$docker_load 
$docker_cmd $volumeDirective /bin/bash -c 'cd \$VEGAS/macros/ && $cmd' 
exitCode=\$?
echo "$cmd"

if [ \$exitCode -eq 0 ]; then
    logStatus $logFileLaser 
else
    failed # trap function 
fi

exit \$exitCode 

EOF

		    completion=$?
		    [ "$runMode" == "$batch_cmd" ] && test "$completion" -eq 0 && touch $queueFileLaser 
		    nJobs=$((nJobs+1))
			
		fi # end job submission for combined laser 
	    fi # if combined laser root file does not exist and not queued 
	fi # check if laser is normal or combined
	
	if (( $numTels < 1 )); then 
	    echo -e "\e[0;31No telescopes found for ${runNum}, skipping!\e[0m"
	    continue
	elif (( $numTels < 3 )); then
	    echo -e "\e[0;31mWarning! only ${numTels} telescopes for ${runNum}!\e[0m"
	fi
	# end laser stuff
	
	dataFile=data/d${runDate}/${runNum}.cvbf		    

	if [ "$runStage1" == true -o "$runStage2" == true ]; then

	    ##### STAGE 1 #####
	    if ( [ ! -f $rootName_1 ] && [ ! -f $queueFile_1 ] ) && ( ( [ ! -f $rootName_2 ] && [ ! -f $queueFile_2 ] && [ "$runStage2" == true ] ) || [ "$runStage1" == true ] ); then 
		# run stage 1 command if it needs to be run for stage 2 or if it is set to run explicitly with the -1 flag 
		# could test for data file 
		stage1cmd="vaStage1 -Stage1_RunMode=data $customFlags1 " # &> $logFile1
		echo "$stage1cmd $dataFile $rootName_1"
		logFile1=$logDir/$stage1subDir/${runNum}.stage1.txt
		queue="$queueFile_1 "
		stages="1"
		timeTotal=$((timeTotal+time1))
		runBool=true
	    fi # stage 1 file doesn't exist and isn't in queue, and you're either running stage 1 or stage 2
	    
	    ##### STAGE 2 #####
	    if [ ! -f $rootName_2 ] && [ ! -f $queueFile_2 ] && [ "$runStage2" == true ]; then
		# could test for data file 
		runBool=true
		stage2cmd="vaStage2 $configFlags2 $customFlags2"
		logFile2=$logDir/$stage1subDir/${runNum}.stage2.txt
		echo "$stage2cmd $dataFile $rootName_2 $laserRoot " # &> $logFile2
		stages="${stages}2"
		timeTotal=$((timeTotal+time2)) 
		queue="${queue}${queueFile_2} "
	    fi # running stage 2, file not in queue
	    
	    if [ "$runBool" == "true" ]; then 
		jobCmds="$subscript12 \"$stage1cmd\" $rootName_1 \"$runStage1\" \"$stage2cmd\" $rootName_2 $runNum $dataFile $laserRoot \"$environment\" "
		get_data="getDataFile $dataFile || continue "
	    fi # if stages 1 or 2 are being run, add to jobs list and retrieve data file 
	    
	fi # run stage 1 or stage 2 	
    fi # stage 1 or stage 2, or laser 

##### STAGE 4 #####
    if [ "$runStage4" == true ]; then
	if ( [ ! -f $rootName_4 ] && [ ! -f $queueFile_4 ] ) || [ "$reprocess" == true ]; then  
	    if  [ ! -f $rootName_2 ] && [ ! "$stage2cmd" ] && [ ! -f $queueFile_2 ]; then
		echo -e "\e[0;31m $rootName_2 does not exist and is not in the queue! skipping $rootName_4 !\e[0m" 
		continue 
	    fi # rootName_2 exists or is queued 
	    
		#offset=`mysql -h romulus.ucsc.edu -u readonly -s -N -e "use VERITAS; SELECT offset_distance FROM tblRun_Info WHERE run_id = ${runNum}"`
	        #zenith=`mysql -h romulus.ucsc.edu -u readonly -s N -e "use ; SELECT FROM WHERE "`
				
	    if [ "$ltMode" == custom ]; then 
		ltFile=$finishedLT # set in setCuts
	    elif [ "$ltMode" == auto ]; then
	        ltFile=$ltAuto 
	    else
		ltFile=$ltMode # just use command line supplied ltFile
	    fi # automatic lookup table 
    
	    tableFlags="-table=${ltFile}" 
	    
	    if [ "$stg4method" == disp ]; then		    
		if [ "$dispMethod" == 5t ]; then
		    dtName=TMVA_Disp.xml
		else
		    offset=`mysql -h romulus.ucsc.edu -u readonly -s -N -e "use VERITAS; SELECT offset_distance FROM tblRun_Info WHERE run_id = ${runNum}"`
		    dtName=dt_Oct2012_${array}_ATM${atm}_GrISUDet_${ltVegas}_7sam_${offset}wobb_Z50-55_std_d${DistanceUpper//./p}.root 
		fi # disp modes 
		
		dtFile=$ltDir/${dtName}
		test -f $dtFile || echo -e "\e[0;31mDisp table $dtFile does not exist! \e[0m"
		tableFlags="$tableFlags -DR_DispTable=$dtFile" 
	    fi # disp method 
	    
	        # don't reprocess if in queue? add to earlier stages? 
	    if [ "$stage4cuts" == "auto" ]; then
                cutFlags4="-DistanceUpper=0/${DistanceUpper} -NTubesMin=${NTubesMin} -SizeLower=${SizeLower}"
	    elif [ "$stage4cuts" == "none" ]; then
		cutFlags4=""
	    else
                cutFlags4="-cuts=${stage4cuts}"
	    fi
	    
	    denyFlag="" 
	    for combo in $TelCombosToDeny $autoTelCombosToDeny ; do 
		test -z "$denyFlag" && denyFlag="-TelCombosToDeny=${combo}" ||  denyFlag="${denyFlag},${combo}"
	    done 

	        # not sure if should use cutTelFlags
	    logFile4="$logDir/${stage4subDir}/${runNum}.stage4.txt"     
	    stage4cmd="vaStage4.2 $tableFlags $cutFlags4 $configFlags4 $denyFlag $cutTelFlags $customFlags4 $rootName_4 "
	    echo "$stage4cmd"
	    [ "$runBool" == true ] && jobCmds="$jobCmds && "
	    jobCmds="$jobCmds $subscript45 \"$stage4cmd\" \"$rootName_4\" \"$rootName_2\" \"$environment\" $box_cuts &> $logFile4" 
	    runBool=true 
	    stages="${stages}4" 
	    timeTotal=$((timeTotal+time4)) 
	    queue="$queue $queueFile_4 " 

	        # condense 
	    if [ ! -f "$ltFile" ]; then
		echo -e "\e[0;31m $ltFile Does Not Exist!! skipping $runNum!\e[0m"
		continue
	    fi
	    if [ "$stg4method" == disp ] && [ ! -f "$dtFile" ]; then
		echo -e "\e[0;31m $dtFile Does Not Exist!!, Skipping $runNum!\e[0m"
		continue
	    fi
	    
	fi # rootName_4 does not exist 
    fi # runStage4 

##### STAGE 5 #####

    if [ "$runStage5" == true ]; then

	if [ ! -f $rootName_5 ] && [ ! -f $queueFile_5 ] || [ "$reprocess" == true ]; then
	    if [ -f $rootName_4 ] || [ "$stage4cmd" ] || [ -f $queueFile_4 ] || [ "$runMode" == print ] ; then		
		if [ "$stage5cuts" == "auto" ]; then
		    cutFlags5="$stage5cuts_auto"
		elif [ "$stage5cuts" == "none" ]; then
		    cutFlags5=""
		else
		    cutFlags5="-cuts=$stage5cuts"
		fi
		
		stage5cmd="vaStage5 $configFlags5 $cutFlags5 $customFlags5"
		if [ "$useStage5outputFile" == true ]; then
		    stage5cmd="$stage5cmd -inputFile=$rootName_4 -outputFile=$rootName_5"
		else
		    stage5cmd="$stage5cmd -inputFile=$rootName_5"
		fi
		
		if [ "$useBDT" == true ]; then
		    
		    weightsDir=${weightsDirBase/EPOCH/$epoch} 
			#  
		    if [[ ! -d ${weightsDir} ]]; then
			echo -e "\e[0;31m${weightsDir} does not exist. this may be a problem!\e[0m"
		    fi
		    stage5cmd="$stage5cmd -BDTDirectory=${weightsDir}"
		fi # BDT 
		
		timeCutMask="NULL"
		if [ "$timecuts" == auto ]; then
			timeCutMask=`mysql -h romulus.ucsc.edu -u readonly -s -N -e "use VOFFLINE; SELECT time_cut_mask FROM tblRun_Analysis_Comments WHERE run_id = ${runNum}"`
		    elif [ "$timecuts" != off ]; then 
			while read -r line; do 
			    set -- $line
			    [ "$1" == $runNum ] && timeCutMask="$2" && break
			done < $timecuts
		    fi # find time cuts
		    [ "$timeCutMask" != "NULL" ] && stage5cmd="$stage5cmd -ES_CutTimes=${timeCutMask}" # apply 
	   
		    logFile5="$logDir/${stage5subDir}/${runNum}.stage5.txt"

		    echo "$stage5cmd"
		    [ "$runBool" == true ] && jobCmds="$jobCmds && "
		    jobCmds="$jobCmds $subscript45 \"$stage5cmd\" \"$rootName_5\" \"$rootName_4\" \"$environment\" $box_cuts &> $logFile5 " 
		    runBool=true 
		    stages="${stages}5"
		    timeTotal=$((timeTotal+time5))
		    queue="${queue} $queueFile_5 "
	    else
		echo -e "\e[0;31m $rootName_4 is not present or is in the queue, skipping $rootName_5 !\e[0m"
	    fi # stage 4 file exists or is in queue  
	fi # stage 5 not present yet
    fi # runStage5

    if ((timeTotal > 10)); then
	timeStamp=${timeTotal}:00:00
    else
	timeStamp=0${timeTotal}:00:00
    fi

##### Main Job Submission ##### 
# after running through all stages, submit one job that runs all jobs 
    if [ "$runMode" != print ] && [ "$runBool" == true ]; then
	[ "$copy_local" == true ] || $get_data 

	submitHeader=$(createBatchHeader -N ${runNum}_${stages} -t $timeTotal -M $mem -o $logDir/batch_out/${runNum}.txt -p $priority)

	$runMode <<EOF
$submitHeader

rmQueue() {
    for q in $queue; do test -f \$q && rm -v \$q ; done 
}

trap rmQueue EXIT 
for sig in $signals ; do 
    trap "echo \"TRAP! Signal: \$sig\"; exit \$sig" \$sig 
done 


for log in $logFile1 $logFile2 $logFile4 $logFile5; do 
    test -f \$log && mv \$log $backupDir/
done 

source $common_functions 

date
umask


$docker_load 
$docker_cmd $volumeDirective /bin/bash -c '$jobCmds' 

exitStatus=\$? 
echo "exit status: \$exitStatus" 
exit \$exitStatus 

EOF
	completion=$? 
	if [ "$completion" -eq 0 ]; then
            [ "$runMode" == "$batch_cmd" ] && touch $queue 
	    nJobs=$((nJobs+1)) 
	else
	    echoErr "failed to run job with $runMode "
	fi
	
    ##### End Main Job Submission ##### 
    fi # end check runmode and that there is a job to submit 

done < $readList # loop over runs in loggen file 
 

##### STAGE 6 #####
if [ "$runStage6" == true ]; then
    cmd6="$scriptDir/execute-stage6.sh -e \"$environment\" -c box_cuts -d $subDir -n $name -r $runMode"
    echo "$cmd6"
fi
# not working 

if [ "$runMode" == "$batch_cmd" ]; then
    echo -e "script submitted $nJobs jobs \t on ` date ` \n" # | tee ${logDir}/batchLog.txt
fi

exit 0 # success 
