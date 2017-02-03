#!/bin/bash 

# environment 
scriptDir=${0%/*}
envDir=${scriptDir/processing_scripts/environments} 
source $scriptDir/defaults_source.sh
source $envDir/env_Crab.sh 
common_functions=$scriptDir/common_functions.sh 
source $common_functions 
source $scriptDir/set_params.sh


# slurm 
time="06:00:00" # may need to be adjusted 
combineTime="01:30:00"
mem=4gb # a lot of jobs can get away with 2gb, but 4gb is safer. 1 core is charged per 2gb, so there is no reason to choose 3gb 

# run settings 
runMode=print # doesn't do anything but print command 
mode=create # 'create' individual tables or 'combine' into larger tables 


allNoise=false
stage=4 # the default stage to read from (for EAs) can be changed to 5 with -5, LTs use stage 2 
simdir=stg4_medium 

# WindowSizeForNoise is 7 by default
ltFlags="$ltFlags -LTM_WindowSizeForNoise=7"
ltFlags="$ltFlags -GC_CorePositionAbsoluteErrorCut=20 -GC_CorePositionFractionalErrorCut=0.25"
ltFlags="$ltFlags -Log10SizePerBin=0.07 -MetersPerBin=5.5"
ltFlags="$ltFlags -TelID=0,1,2,3"
#ltFlags="$ltFlags -ImpDistUpperLimit=800" # test this, defaults to 400, but using 300 in stage 5 / EA 

#eaFlags="-EA_RealSpectralIndex=-2.4" 
# old disp table flags, these do not seem to combine correctly! disp 5t method recommended 
dtFlags="-Log10SizePerBin=0.25 -Log10SizeUpperLimit=6 -RatioPerBin=1 -DTM_WindowSizeForNoise=7"
dtFLags="$dtFlags -DTM_Width=0.04,0.06,0.08,0.1,0.12,0.14,0.16,0.2,0.25,0.3,0.35"
dtFlags="$dtFlags -DTM_Length=0.05,0.09,0.13,0.17,0.21,0.25,0.29,0.33,0.37,0.41,0.45,0.5,0.6,0.7,0.8"

# for traps 
signals="1 2 3 4 5 6 7 8 11 13 15 30"

priority=(0)
nJobs=(0)
nJobsMax=(1000)

args=`getopt -o qQr:n:e:p:c:5x: -l submit,run:,env:,combine,arrays:,atms:,zeniths:,azimuths:,offsets:,noises:,box_cuts:,distance:,nameExt:,simdir:,telID,xOpts:,allNoise,waitFor:,mem:,reprocess,deny:,suppress,no-docker -- "$@"`
eval set -- $args
for i; do 
    case "$i" in 
	-q|--submit) 
	    runMode=sbatch 
	    partition=shared ; shift ;; 
	-Q) runMode=sbatch
	    partition=regular ; shift ;; 
	-r|--run) # the command that runs the herefile
	    runMode="$2" ; shift 2 ;;	
	-n)
	    nJobsMax=($2) ; shift 2 ;; 	
	-e|--env)
	    environment="$2" ; shift 2 ;; 
	--combine)
	    mode=combine ; shift ;; 
	--mem)
	    mem="$2" ; shift 2 ;; 
	--arrays) 
	    arrays="$2" ; shift 2 ;;	
	--atms) 
	    atms="$2" ; shift 2 ;;	
	--zeniths)
	    zeniths="$2"  
	    shift 2 ;;    	
	--azimuths)
	    azimuths="$2"  
	    shift 2 ;;    	
	--offsets) 
	    offsets="$2" ; shift 2 ;;	
	--distance)
	    DistanceUpper="$2" ; shift 2 ;;	
	--box_cuts|-c)
	    cuts_set="$2" ; shift 2 ;; 
	--simdir) # the subdirectory under $simWork/processed/ from which to use simulationos for EA production 
	    simdir="$2" ; shift 2 ;;
	-5) # use stage 5 sims instead of stage 4 for EAs
	    stage=5 ; shift ;; 
	--deny)
	    TelCombosToDeny="$2" ; shift 2 ;; 
	--telID)
	    dtFlags="$dtFlags -DTM_TelID=0,1,2,3" ; shift ;; 
	--no-docker)
	    export use_docker=false ; shift ;; 
	-x|--xOpts) # must enter full argument 
	    xOpts="$xOpts ${2}" ; shift 2 ;; # be careful about
	--nameExt) 
	    nameExt="${nameExt}_${2}" ; shift 2 ;; 
	--allNoise)
	    allNoise=true ; shift ;; 
	--noises) # questionable  
	    noises="$2" ; shift 2 ;; 
	--suppress)
	    suppress=true ; shift ;; # don't print build command 
	--waitFor) # do not start if pattern shows up in current processes 
	    waitString="$2" ; shift 2 ;; 
	-p) 
	    priority=($2) ; shift 2 ;; 
	--) 
	    shift ; break ;;
	#*)
    esac # argument cases
done # loop over i in args

usage() { 
    echo "Usage: "
    echo "$0 lt -e /path/to/env_file.sh [options]"
    echo "$0 ea -e /path/to/env_file.sh --simdir sim_directory [options]"
    echo "sim_directory should be the subdirectory name under $simWork/processed"
    echo 
    echo "you can override the default parameter space specified in this script with the following options: " 
    echo "arrays and atmospheres can be specified as space-separated lists"
    echo -e "\t--arrays \"na ua\" "
    echo -e "\t--atms \"21\" "    
    echo -e "\t-c \"soft medium hard\" "
    echo "zeniths must be organized into comma-separated groups of at least 2!"
    echo -e "\t--zeniths \"00,20 30,35\" "
    echo "you can provide any additional flags: " 
    echo -e "\t-x \"-additional_flag1 -additional_flag2 "
} # usage 

test -n "$1" && table="$1" || ( echoErr "must specify a table type" ; usage ; exit )


# source the environments left to right 
for env in $environment; do source $env || exit 1; done 
test -n "$tableWork" || ( echoerr '$tableWork must be specified. set in environment file' ; exit 1 )


# set in environment 
#imageDirective="--image=docker:registry.services.nersc.gov/${imageID}" 
#volumeDirective="--volume=\"$projectDir/:$projectContainer\"" # --volume=\"$scratchDir/:$scratchContainer/\""
test "$docker_cmd" == shifter && docker_cmd="$docker_cmd $imageDirective $volumeDirective"

# check dirs!
if [ ! -d $tableWork ]; then
    echo "Must create directory $dir !!!"
    [[ "$runMode" == sbatch ]] && ( makeSharedDir $tableWork || exit 1 ) 
fi
for subdir in backup completed_jobs config combined log processed queue failed_jobs ; do 
    dir=$tableWork/$subdir
    if [ ! -d $dir ]; then
	echo "Must create directory $dir !!!"
        [[ "$runMode" == sbatch ]] && makeSharedDir $dir
    fi
done 
logDir=$tableWork/log


# loop over parameter space 
for array in $arrays; do 
    for atm in $atms; do 
	for box_cuts in $cuts_set; do 
	    firstTable=""

setCuts # sets cut parameters, table names 

if [ "$allNoise" = true ]; then
    noiseArray=(${noiseLevels}) # all noises in one element 
    pedVarArray=(${pedVars})
else 
    set -- ${noiseLevels//,/ }
    noiseArray=(${1},${2},${3} ${4},${5} ${6},${7} ${8},${9} ${10},${11})
    set -- ${pedVars//,/ }
    pedVarArray=(${1},${2},${3} ${4},${5} ${6},${7} ${8},${9} ${10},${11})
    # could make function for this but not necessary now 
fi # do not split tables by noise level groups 
noiseNum=${#noiseArray[@]}

#epoch=$array
simFileSubDir=Oct2012_${array}_ATM${atm} # not used 

if [ "$table" == ea ]; then
    # tweak offsets 
    tableList=$tableWork/config/tableList_${table}_${simdir}_${array}_ATM${atm}_${box_cuts}_${offsets//./}off${nameExt}.txt    
    # stage defaults to 4 unless stage 5 option is given 
else
    tableList=$tableWork/config/tableList_${table}_${array}_ATM${atm}.txt
fi
tempTableList=`mktemp` || ( echo -e "\e[0;31m tempTableList creation failed\e[0m" ; exit 1 )

individualTableSubmitted=false
# loop over groups of parameters 
for zenGroup in $zeniths; do 
    for azGroup in $azimuths; do 
	for oGroup in $offsets; do 
	    noiseIndex=(0) #noiseIndex
	    while (( noiseIndex < noiseNum )); do 
		oGroupNoDot=${oGroup//./}
		
		azGroup=${azGroup// /,}
		azLabel="${azGroup%%,*}-${azGroup##*,}" 
		#azLabel=${azGroup//,/-}
		if [ "$table" == ea ]; then 
		    # could put into setTableNames 
		    tableFileBase=${table}_${model}_${array}_ATM${atm}_${simulation}_${ltVegas}_7samples_${oGroupNoDot//,/-}off_s${SizeLower//0\//}_Z${zenGroup//,/-}_A${azLabel}_std_d${DistanceUpper//./p} #modify zeniths, offsets 
		    tableFileBase="${tableFileBase}_MSW${MeanScaledWidthUpper//./p}_MSL${MeanScaledLengthUpper//./p}"
		    tableFileBase="${tableFileBase}${MaxHeightLabel}"
		    tableFileBase="${tableFileBase}_ThetaSq${ThetaSquareUpper//./p}_DistCut${ImpactDistanceUpper}m"
		else
		    tableFileBase=${table}_${model}_${array}_ATM${atm}_${simulation}_${ltVegas}_7samples_${oGroupNoDot//,/-}off_Z${zenGroup//,/-}_A${azLabel}_std_d${DistanceUpper//./p} #modify zeniths, offsets 
		fi # 	    
		if [ "$allNoise" == true ]; then
		    noiseSpec=allNoise
		else
		    noiseSpec=${noiseIndex//,/-}noise
		fi # append noise levels 
		tableFileBase="${tableFileBase}_${noiseSpec}${nameExt}"
		
		
		simFileList=$tableWork/config/simFileList_${table}
		[ "$table" == "ea" ] && simFileList=${simFileList}_${simdir}_${box_cuts}
		simFileList=${simFileList}_${array}_ATM${atm}_Z${zenGroup//,/-}_A${azLabel}_${oGroupNoDot//,/-}wobb_${noiseSpec}${nameExt}.txt 
		
		tempSimFileList=`mktemp` || ( echo -e "\e[0;31m temp file creation failed! \e[0m" 1>&2 ; exit 1 ) 
		for zen in ${zenGroup//,/ }; do 
		    for offset in ${oGroup//,/ }; do 
			noiseGroup=${noiseArray[$noiseIndex]} 
			for noise in ${noiseGroup//,/ }; do

			    setSimNames $zen $offset $noise #$stage 
			    # sets $simFileBase and $simFile2
			    
			    if [ "$table" == ea ]; then 
				simFile=$simWork/processed/$simdir/${simFileBase}.stage${stage}.root
			    else
				simFile=$simFile2
				#getDataFile / getSimFile $simFile2
			    fi

			    # check for the data file before putting into list 
			    if [ -f "$simFile" ]; then 
				#echo "$simFile" | tee -a $tempSimFileList
				echo "$simFile" >> $tempSimFileList
			    else  
				echoErr "$simFile does not exist!"
				break 3 # breaks from loop over subgroups 
			    fi 
			    
			done # individual noises
		    done # individual offsets
		done # individual zeniths
		if [ "$runMode" != print ]; then 
		    if [ ! -f "$simFileList" ]; then
			cat $tempSimFileList > $simFileList
		    elif [[ `diff $tempSimFileList $simFileList` != "" ]]; then
			echo "$simFileList has changed, backing up"
			mv $simFileList $tableWork/backup/
			cat $tempSimFileList > $simFileList
		    fi
		fi # update simFileList if it's new 
		
		smallTableFile=$tableWork/processed/${tableFileBase}.root
		echo "$smallTableFile" >> $tempTableList
		test -z "$firstTable" && firstTable=$smallTableFile
		
		logFile=$logDir/${tableFileBase}.txt
		queueFile=$tableWork/queue/$tableFileBase
		
		case "$table" in 
		    lt) # lookup table 
			[[ "$oGroup" != ${oGroup/ /} ]] && offsetFlag="$flags -AbsoluteOffset=${oGroup}" 
			cuts="-DistanceUpper=0/${DistanceUpper} -NTubesMin=${NTubesMin}" # -SizeLower=${SizeLower}
			flags="$ltFlags"
			flags="$flags -Azimuth=${azGroup} -Zenith=${zenGroup} -Noise=${pedVarArray[$noiseIndex]}" 
			flags="$flags $offsetFlag"
		    #flags="$flags -G_SimulationMode=1" 
			
			cmd="produce_lookuptables $flags $cuts $simFileList $smallTableFile"
			
			macroDir='$VEGAS/showerReconstruction2/macros' # single quotes so variable is read within container or shell  
			validateMacro=validate.C
			box_cuts=medium # lt mode doesn't actually use this, but it prevents the loop over cuts from repeating 
			;; # lookup tables 
		    
		    ea) # effective area table 
			cuts="$stage5cuts_auto"
			flags="$eaFlags"
			flags="$flags -Azimuth=${azGroup} -Zenith=${zenGroup} -Noise=${pedVarArray[$noiseIndex]}" # same as lt		    		    		    
			flags="$flags -ThetaSquareUpper=$ThetaSquareUpper"
			
		    # only takes this argument for multiple offset groups. for single offset leave it out 
			test "$oGroup" != "${oGroup//,/}" && flags="$flags -AbsoluteOffset=${oGroup}" 
			
			denyFlag="" 
			for combo in $TelCombosToDeny $autoTelCombosToDeny ; do 
			    test -z "$denyFlag" && denyFlag="-TelCombosToDeny=${combo}" ||  denyFlag="${denyFlag},${combo}"
			done # print option for first combo, then append 
			
			cmd="makeEA $cuts $flags $denyFlag $xOpts $simFileList $smallTableFile" 
			macroDir='$VEGAS/resultsExtractor/macros'
			validateMacro=validate2.C
			
			;; # effective areas 
		    dt) # disp table
			cuts="-DistanceUpper=0/${DistanceUpper} -NTubesMin=${NTubesMin}" # -SizeLower=${SizeLower}
			flags="$cuts -DTM_Azimuth=${azGroup}"
			flags="$flags -DTM_Noise=${pedVarArray[$noiseIndex]} -DTM_Zenith=$zenGroup"
			flags="$flags -DTM_AbsoluteOffset=$oGroup"
		    #flags="$flags -G_SimulationMode=1" # unnecessary 
			
			cmd="produceDispTables $flags $simFileList $smallTableFile"
			macroDir='$VEGAS/showerReconstruction2'
			validateMacro=validate.C
			
			;; # effective area table
		    *)
			echo -e "\e[0;31m Table type $table is not valid! choose lt, ea, or dt \e[0m" 
			exit 1 ;; 
		esac # table modes
			
		
	    # needs revision for queueDel 
		if [ -f "$smallTableFile" ] || [ -f "$queueFile" ]; then # or check squeue 
		# reprocess option not implemented yet 
	            if [ -n "$reprocess" ]; then 
			sleep 0 # placeholder 
#queueDel $tableFileBase # this function not loaded 
		    else
			noiseIndex=$((noiseIndex+1)) 
			continue
		    fi 
		    
		else # file does not exist and is not queued 
		    
		    echo "$cmd" 
		    validateCmd="root -l -b -q \"$validateMacro(\\\"$smallTableFile\\\")\" " 
		    diagFile=${smallTableFile/.root/.diag}
		    sumFile=${smallTableFile/.root/.summary.csv}

		    
		    if [ "$runMode" != print ]; then 
			individualTableSubmitted=true
			if [ ! $nJobs -lt $nJobsMax ]; then 
			    echo "Total number of requested jobs submitted, exiting.. " 
			    exit 0
			fi

			test "$runMode" == sbatch && ( test -f "$logFile" && mv $logFile $tableWork/backup/ )
			
			$runMode <<EOF 
$sbatchHeader
#SBATCH -J $tableFileBase
#SBATCH -o $logFile
#SBATCH --time=${time}
#SBATCH --mem=${mem}

# clean up files upon exit, make sure this executes when other trap is triggered 
cleanUp() { 
    test -f "$queueFile" && rm $queueFile
    echo -e "\n$cmd"
}
trap cleanUp EXIT # called upon any exit 
rejectTable() {
    echo "exit code: \$exitCode"
    test -f "$smallTableFile" && mv $smallTableFile $tableWork/backup/
    mv $logFile $tableWork/failed_jobs/
}

for sig in $signals; do 
    trap "echo -e \"TRAP! Signal: \${sig} - Exiting..\"; rejectTable; exit \$sig" \$sig
done 

source $common_functions # this is sourced here so functions can run in shell. environment 
logInit

$docker_load

# execute command
timeStart=\`date +%s\`

$docker_cmd /bin/bash -c '$cmd && cd $macroDir && $validateCmd' 

exitCode=\$?
timeEnd=\`date +%s\`
echo "Table completed with exit status \$exitCode in:"
date -d @\$((timeEnd-timeStart)) -u +%H:%M:%S


if [ "\$exitCode" -ne 0 ]; then 
    rejectTable
    exit \$exitCode
fi 


# validate table 
if [ "$table" == "ea" ]; then 

    # ea files have an additional summary csv file that should not have more than one line 
    if [ -f $sumFile ]; then
        test \`cat $sumFile | wc -l\` -gt 1 && badDiag=true || rm $sumFile
    else
        echo "no sumfile!"
    fi 
fi

if [ -s $diagFile ] || [ ! -f $diagFile ] || [ "\$badDiag" == true ]; then 
    echo -e "There may be a problem with this table!! check $diagFile files"
    rejectTable 
else
    echo 'Exiting successfully!'
    rm -v $diagFile
    logStatus $logFile 
    echo '$validateCmd'
    exit 0
fi

exit 5 # didn't exit successfully 

EOF
			exitCode=$?
			if (( exitCode == 0 )); then
			    test "$runMode" == sbatch && touch $queueFile 
			    nJobs=$((nJobs+1))
			else
			    echo -e "FAILED!"
			    exit $exitCode # 
			fi # was job submitted successfully 
		    fi # runMode options
		    
		fi # not already in queue
		noiseIndex=$((noiseIndex+1))
	    done # noise levels
	done # offsets 
    done # azimuths 
done # zeniths 

offsets=${offsets// /,}
offsetName=${offsets//./}
zenithsCombined=${zeniths// /,}
azimuths=${azimuths// /,}
combinedFileBase=${table}_${model}_${array}_ATM${atm}_${simulation}_${ltVegas}_7samples_${offsetName//,/-}off_Z${zenithsCombined//,/-}_std_d${DistanceUpper//./p}

if [ "$runMode" != print ]; then
    if [ ! -f $tableList ]; then
	cat $tempTableList > $tableList
    elif [[ `diff $tempTableList $tableList` != "" ]]; then
	echo "$tableList has changed, backing up"
	mv $tableList $tableWork/backup/
	cat $tempTableList > $tableList
    fi
fi # write table list file if it's changed 



# combining of tables! # 
case $table in 
    dt)
	buildCmd="buildDispTree $dtWidth $dtLength -DTM_Azimuth=${azimuths} -DTM_Zenith=${zenithsCombined} -DTM_Noise=${pedVars}"
	combinedTable=$tableWork/processed/${combinedFileBase}.root ;;
    lt) 
	buildCmd="buildLTTree -TelID=0,1,2,3 -Azimuth=${azimuths} -Zenith=${zenithsCombined} -Noise=${pedVars} $offsetFlag"
	combineCmd="root -l -b -q \"combo.C(\\\"$tableList\\\", \\\"$buildCmd\\\")\" "
	combinedTable=$tableWork/processed/${combinedFileBase}.root 
	finishedTable=$finishedLT ;; 
    ea) 
	test $MaxHeightLower != -100 && MaxHeightLabel="_MH${MaxHeightLower//./p}" || MaxHeightLabel=""
	buildCmd="buildEATree -Azimuth=${azimuths} -Zenith=${zenithsCombined} -Noise=${pedVars} " 
	combinedTable=$tableWork/processed/${combinedFileBase}_s${SizeLower//0\//}_MSW${MeanScaledWidthUpper//./p}_MSL${MeanScaledLengthUpper//./p}${MaxHeightLabel}_ThetaSq${ThetaSquareUpper//./p}${nameExt}.root # $cuts 
	validateCmd="root -l -b -q \"$validateMacro(\\\"$combinedTable\\\")\" "
	combineCmd="$macroDir/combineEA.pl $tableList $combinedTable  &&  $buildCmd $combinedTable  &&  root -l -b -q \"$validateMacro(\\\"$combinedTable\\\")\" "
	finishedTable=$finishedEA ;; 
esac # build commands based on table type 

if [ $mode == combine ] && [ ! -f $combinedTable ]; then 
    echo $combineCmd
    [ "$suppress" != "true" ] && echo "$buildCmd $combinedTable" 
    logFile=${combinedTable/processed/log}
    logFile=${logFile/.root/_combine.txt}
    diagFile=${combinedTable/.root/.diag} 
    sumFile=${combinedTable/.root/.summary.csv}

    if [ "$individualTableSubmitted" != false ]; then
	echo "you had to submit a small table file that belongs to this group, so you should not combine tables until those are all complete" 
	continue 
    fi


    if [ "$runMode" != print ]; then 
	if [ ! $nJobs -lt $nJobsMax ]; then 
	    echo "Total number of requested jobs submitted, exiting.. " 
	    exit 0
	fi

	[ "$runMode" == sbatch ] && test -f $logFile && mv $logFile $tableWork/backup/ 
	$runMode <<EOF 
$sbatchHeader 
#SBATCH -J combine_$combinedFileBase
#SBATCH -o $logFile
#SBATCH --time=${combineTime} 
#SBATCH --mem=${mem} 

for src in $common_functions $environment;  do source \$src ; done  
logInit 

cleanUp() { 

    [ "$table" == lt ] && mv -v ${firstTable}.backup $firstTable 
    echo '$combineCmd'

} # clean up files, executed upon exit 

rejectTable() {

    echo "Rejecting table!!!" 
    test -f $smallTableFile && mv -v $smallTableFile $tableWork/backup/ 
    mv -v $logFile $tableWork/failed_jobs/ 
    test -f $tableWork/completed_jobs/${logFile##*/} && unlink $tableWork/completed_jobs/${logFile##*/} 

} # trap for failure 

# set traps for what to do if job receives some signal 
trap "cleanUp" EXIT # called upon any exit 
for sig in $signals; do 
    trap "echo \"TRAP! Signal: \${sig} - Exiting..\"; rejectTable; exit \$sig" \$sig
done # loop over standard signals 

[ "$table" == lt ] && rsync -v $firstTable ${firstTable}.backup 


$docker_load 
$docker_cmd /bin/bash -c 'cd $macroDir/ && $combineCmd' 

completion=\$? 
echo "status: \$completion " 

# check diagnostic files are empty 
test -f $diagFile && test -s $diagFile && badDiag=true || rm -v $diagFile 
test "$table" == "ea" && test -f $sumFile && test \`cat $sumFile | wc -l\` -gt 1 && badDiag=true || rm $sumFile 

if [ "\$completion" -eq 0 ] && [ "\$badDiag" != true ]; then 
    [ "$table" == lt ] && mv -v $firstTable $combinedTable 
    logStatus $logFile 
    cp -v $combinedTable $finishedTable 
else 
    rejectTable 
fi 

exit \$completion 

EOF

	
	exitCode=$?
	if (( exitCode == 0 )); then
	    nJobs=$((nJobs+1))
	else
	    echo -e "FAILED!"
	    exit $exitCode # 
	fi # was job submitted successfully 
    fi # runmode 
fi # if combine mode 

	done # box_cuts 
    done # atm groups 
done # array groups 

exit 0 # great job 
