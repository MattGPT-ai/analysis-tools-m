#!/bin/bash

### process_script.sh processes the files in a logGen format runlist file through the selected stages with the selected options ### 

##### SET DEFAULTS #####

priority=0

runLaser="false"
runStage1="false"
runStage2="false"
runStage4="false"
runStage5="false"
runStage6="false"
finalFlag=false # flag to signal skipping of earlier stages if later stage (5) file already exists 

baseDataDir=/veritas/data
scratchDir=/scratch/mbuchove
tableDir=$USERSPACE/tables
laserDir=$LASERDIR
weightsDirBase=$BDT/weights
#weightsDir=5-34_defaults
trashDir=$HOME/.trash

spectrum=medium
simulation=GrISUDet # CORSIKA
model=Oct2012  
method=std
environment="" #$HOME/environments/SgrA_source.sh
ltMode=auto
#ltVegas=vegasv254
ltVegas=vegasv250rc5
offset=allOffsets # should find a way to manage this 
zenith=LZA

scriptDir=${0/\/${0##*/}/}
source $scriptDir/setCuts.sh 
stage4cuts=auto
stage5cuts=auto

configFlags4=""
# make an option for setting this 
configFlags5="-Method=VACombinedEventSelection -CMC_RemoveCutEvents=1"
#configFlags5="-Method=VAStereoEventSelection -CMC_RemoveCutEvents=1"
#configFlags5="-Method=VACombinedEventSelection"
suffix="" # only applied to stages 4 and 5 by default
#read2from4=
useStage5outputFile=true
useBDT=false
autoCutTel4=false
applyTimeCuts="true"

reprocess=false
runMode=print # 

laserSubscript=$scriptDir/subscript_laser.sh
subscript12=$scriptDir/subscript_stage1and2.sh
subscript45=$scriptDir/subscript_4or5.sh

##bin/sh -f
qsubHeader="
#PBS -S /bin/bash 
#PBS -l nodes=1,mem=2gb
#PBS -j oe
#PBS -A mgb000
#PBS -V 
"

signals="1 2 3 4 5 6 7 8 11 13 15 30"
nJobs=(0) # number of submits 
nJobsMax=(1000) 

stage1subDir=stg1
stage2subDir=stg2
stage4subDir=stg4
stage5subDir=stg5

##### Process Arguments #####
# use getopt to parse arguments 
args=`getopt -o l124:5:ahB:s:qQr:e:c:C:p:kdn:o:ibL -l x1:,x2:,x4:,x5:,d1:,d2:,d4:,d5:,disp:,atm:,BDT:,deny:,cutTel:,reprocess -n 'process_script.sh' -- "$@"` # B::
eval set -- $args 
# loop through options
for i; do  
    case "$i" in 
	-l) runLaser="true"
	    shift ;;
	-1) runStage1="true"
	    shift ;;
	-2) runStage2="true"
	    shift ;;
	-4) runStage4="true" 
	    stage4subDir="$2"
	    shift 2 ;;
	-5) runStage5="true"
	    stage5subDir="$2" 
	    finalFlag=true 
       	    shift 2 ;;
	--d1) stage1subDir=$2 ; shift 2 ;; 
	--d2) stage2subDir=$2 ; shift 2 ;; 
	--d4) stage1subDir=$2 ; shift 2 ;; 
	--d5) stage2subDir=$2 ; shift 2 ;; 	
	#-F) use copy stage4 instead of stage2 to save having stage2 copies
	-a) runStage1="true"; runStage2="true"; runStage4="true"; runStage5="true"
	    shift ;;
	-r) runMode="$2" # cat bash 
	    shift 2 ;;
	-q) runMode=qsub
	    queue=batch
	    shift ;;
	-Q) runMode=qsub
	    queue=express
	    shift ;; 
	-n) nJobsMax=$2 
	    shift 2 ;;
	-L) mode=lightcurve # | --lc
	    configFlags5="$conf-Method=VAStereoEventSelection -CMC_RemoveCutEvents=1"
	    shift ;; 
	--reprocess)
	    reprocess=true ; shift ;;
	-s) spectrum=$2
	    shift ; shift ;;
	-c) stage4cuts=$2
	    # choose auto to automatically choose optimized cuts, or none to not cut
	    shift ; shift ;;
	-C) stage5cuts=$2
	    # same as for stage 4
	    shift ; shift ;;
	-b) mode=background # | --background # for BDT background 
	    configFlags5="-Method=VACombinedEventSelection"  
	    shift ;;
	-B|--BDT) # mode options should be used first, before other things that modify stage5 config 
	    configFlags5="-Method=VACombinedEventSelection -UseBDT=1"
	    useBDT="true"
	    stage5cuts=none
	    weightsDirBase="$2" # can append array to end, e.g. _V5
	    echo "BDT mode enabled. The argument is the weights directory, if the name contains the string EPOCH that will be replaced by e.g. V5"
	    # useStage5outputFile="true"
	    shift 2 ;;
	--disp) 
	    stg4method=disp
	    dispMethod="$2"
	    configFlags4="$configFlags4 -DR_Algorithm=Method${dispMethod}" #t stands for tmva, Method6 for average disp and geom
	    DistanceUpper=1.38
	    ltVegas=vegas254
	    shift 2 ;; 
	--atm) # use one atmosphere for every run 
	    ATM=$2
	    shift 2 ;; 
	-e) environment="$2" # has problem resetting spectrum if it comes after, should load first 
	    for env in $environment; do  source $env; done
	    #stage4subFlags="$stage4subFlags $envFlag"
	    #stage5subFlags="$stage5subFlags $envFlag"
	    shift; shift ;;
	-p) priority=$2
	    shift ; shift ;;
	-k) simulation=KASCADE
	    shift ;; 
	-h) method=hfit
	    configFlags2="$configFlags2 -HillasFitAlgorithum=2DEllipticalGaussian"
	    #stage2subDir=stg2_hfit
	    configFlags4="$configFlags4 -HillasBranchName=HFit"
	    #stage4cuts="BDT_hfit4cuts.txt"
	    configFlags5="$configFlags5 -HillasBranchName=HFit"
	    #suffix="${suffix}_hfit"
	    shift ;; 
	-i) useStage5outputFile="false"
	    shift ;;
	--deny)
	    TelCombosToDeny="$2" ; shift 2 ;; 
	--cutTel)
	    configFlags4="$configFlags4 -CutTelescope=$2"
	    shift 2 ;; 
	-o)
	    configFlags4="$configFlags4 -OverrideLTCheck=1"
	    shift ;; 
	--x1) customFlags1="$customFlags1 $2" ; shift 2 ;; 
	--x2) customFlags2="$customFlags2 $2" ; shift 2 ;; 
	--x4) customFlags4="$customFlags4 $2" ; shift 2 ;; 
	--x5) customFlags5="$customFlags5 $2" ; shift 2 ;; 
	--) shift; break ;;
	#	*) echo "option $i unknown!" ; exit 1 ;; # may not be necessary, getopt rejects unknowns 
    esac # end case $i in options
done # loop over command line arguments 

qsubHeader="$qsubHeader
#PBS -q $queue"

workDir=$VEGASWORK
processDir=$workDir/processed
logDir=$workDir/log
rejectDir=$workDir/rejected
queueDir=$workDir/queue
backupDir=$workDir/backup

if [ $1 ]; then
    readList="$1"
else #complete this 
    echo -e "Usage: $0 {args} runlist"
    echo -e "\t-[stageNum] run stage number"
    echo -e "\t-a run all stages"
    echo -e "\t-h \tenable HFit"
    echo -e "\t-s dir\t process stage5 into directory"
    echo -e "\t-o \t run stage5 optimization instead of training"
    echo -e "\t-q \tsubmit jobs to qsub"
    echo -e "Be sure to have environment variables set!"
    echo -e "\t\$VEGASWORK - working directory with subdirs log, processed, queue, rejected"
    exit 1
fi # runlist specified

if [ $2 ]; then
    echo "argument $2 and those following will not be used!"
fi

if [ "$spectrum" == "soft" ] || [ "$spectrum" == "loose" ]; then
    sizeSpec=SoftLoose
else
    sizeSpec=$spectrum 
fi # size setting for soft and loose is the same 

### quick check for files and directories ###
for subDir in queue processed log completed rejected results config backup; do
    if [ ! -d $workDir/$subDir ]; then
	echo "Must create directory $workDir/$subDir"
	if [ "$runMode" != "print" ]; then
	    mkdir -p -v -v $workDir/$subDir
	fi
    fi # processing directories do not exist 
done # could make common functions for checking dirs
subDirs="$stage1subDir $stage2subDir errors"
if [ "$runStage4" == "true" ]; then
    subDirs="$subDirs $stage4subDir"
fi
if [ "$runStage5" == "true" ]; then
    subDirs="$subDirs $stage5subDir"
fi
for dir in $processDir $logDir; do
    for subDir in $subDirs; do
	if [ ! -d $dir/$subDir ] && [ "$dir/$subDir" != "$processDir/errors" ]; then
	    echo "Must create directory $dir/$subDir"
	    if [ "$runMode" != "print" ]; then
		mkdir -p -v -v $dir/$subDir
	    fi
	fi # processing directories do not exist 
    done # loop over subdirs
done # loop over main dirs, process and log

setEpoch() { # try to move into common file with setCuts

    date=$1

    # try to read from database 
    runMonth=$(( (date % 10000 - date % 100) / 100 ))
    # used to be runMonth > 4, but changed to agree with s6RunlistGen.py 
    if [ ! $ATM ]; then 
	if (( runMonth > 3 && runMonth < 11 )); then
	    atm=22
	else
	    atm=21
	fi
    else
	atm=$ATM
    fi

    # determine array for stage 4   
    if (( date < 20090900 )); then
        array=oa 
	epoch=V4 # MDL8OA_V4_OldArray 
    elif (( date > 20120900 )); then
        array=ua 
	epoch=V6 # MDL10UA_V6_PMTUpgrade 
    else
        array=na 
	epoch=V5 # MDL15NA_V5_T1Move
    fi
    
} # end setEpoch 

setCuts # sets the values for various cut parameters 

while read -r line
do
    test $nJobs -lt $nJobsMax || exit 0 # for the -n flag 
    set -- $line # split up command line 
    
    runDate=$1
    runNum=$2
    laser1=$3; laser2=$4; laser3=$5; laser4=$6 # shorten variable names
    
    stage1cmd="" # NULL 
    stage2cmd=""
    stage4cmd=""
    stage5cmd=""

    jobCmds=""
    stages=""
    queue="" 

    rootName_1="$processDir/${stage1subDir}/${runNum}.stage1.root"	    
    rootName_2="$processDir/${stage2subDir}/${runNum}.stage2.root"
    rootName_4="${processDir}/${stage4subDir}/${runNum}.stage4.root"
    rootName_5="${processDir}/${stage5subDir}/${runNum}.stage5.root"
    queueFile_1="${queueDir}/${stage1subDir}_${runNum}.stage1"
    queueFile_2="${queueDir}/${stage2subDir}_${runNum}.stage2"
    queueFile_4=$queueDir/${stage4subDir}_${runNum}.stage4
    queueFile_5=${queueDir}/${stage5subDir}_${runNum}.stage5
    runLog4="$logDir/${stage4subDir}/${runNum}.stage4.txt"	
    runLog5="${logDir}/${stage5subDir}/${runNum}.stage5.txt"
    
    setEpoch $runDate
    setCuts

    # skip over run if the stage 5 file already exists
    finalFile=$rootName_5
    $finalFlag && test -f $finalFile && echo "$finalFile already exists! skipping.." && continue 
    

    if [ "$runStage1" == "true" -o "$runStage2" == "true" -o "$runLaser" == "true" ]; then
	
	combinedLaserName="combined_${laser1}_${laser2}_${laser3}_${laser4}_laser"

	dataDir=$baseDataDir/d${runDate}
	dataFile=${dataDir}/${runNum}.cvbf		    
	runData="$scratchDir/${runNum}.cvbf"
	
	laserProcessed=$laserDir/processed # shorten variable name 
	laserQueue=$laserDir/queue
	laserLog=$laserDir/log

	laserRoot="NULL"
	laserNum="NULL"
	
	numTels=(0)
	runBool="false" # set to true if any lasers need to be run 

	for n in $laser1 $laser2 $laser3 $laser4; do
	    # loop through the lasers
	    if [ "$n" != "--" ]; then
		
		numTels=$((numTels + 1))
		
		if [ "$laserNum" == "NULL" ]; then
		    
		    laserNum=$n
		    runBool="true"
		    
		elif [ "$laserNum" != "$n" ]; then
		    laserRoot="${combinedLaserName}.root"
		    runBool="true"
		fi # new laser num is different from previous
		
		laserData="NULL"
		if [ "$runBool" == "true" ]; then
		    # change ${n}_laser.root to ${n}.laser.root 
		    if [ ! -f $laserProcessed/${n}_laser.root -a ! -f $laserQueue/${n}_laser ]; then
			if [ -f $dataDir/${n}.cvbf ]; then
			    laserData=$dataDir/${n}.cvbf
			else
			    laserDate=`mysql -h romulus.ucsc.edu -u readonly -s -N -e "use VERITAS; SELECT data_end_time FROM tblRun_Info WHERE run_id=${n}"`
			    laserDate=${laserDate// */}
			    laserDate=${laserDate//-/}
			    echo "laser $n has a different date from the run on $runDate, contacting the database to find the laser date $laserDate"
			    if [ -f $baseDataDir/d${laserDate}/${n}.cvbf ]; then
				laserData=$baseDataDir/d${laserDate}/${n}.cvbf
			    else
				echo "couldn't find laser file!"
			    fi
			fi # find data file for laser

			if [ "$laserData" != "NULL" ]; then
			    ### run normal laser			    
			    laserCmd="`which vaStage1` $customFlags1"
			    echo "$laserCmd $laserData $laserProcessed/${n}_laser.root" 
			    if [ "$runMode" != "print" ]; then
				[ "$runMode" == "qsub" ] && touch $laserQueue/${n}_laser
				
				$runMode <<EOF
$qsubHeader
#PBS -N ${n}_laser
#PBS -o $laserLog/${n}_laser.txt
#PBS -p $priority

$laserSubscript "$laserCmd" $laserData $laserProcessed/${n}_laser.root $envFlag
 
EOF

				completion=$?
				test "$completion" -eq 0 && nJobs=$((nJobs+1)) 
			    fi # end qsub for regular laser 
			    
			else ### end run normal laser
			    echo -e "\e[0;31mLaser data file ${dataDir}/${n}.cvbf does not exist! check directory\e[0m"
			fi # data file found
		    fi # laser file does not yet exist
		fi # run bool is true		
	    fi # laser isn't --
	done # for loop over telescopes
	
	if [[ "$laserRoot" == "NULL" ]]; then
	    
	    laserRoot="$laserProcessed/${laserNum}_laser.root"
	    
	else # process the combined laser file
	    laserQueue=$laserQueue/${combinedLaserName}
	    combinedLaserRoot=$laserProcessed/${combinedLaserName}.root
	    if [ ! -f $queueFileLaser ]; then
		if [ ! -f $combinedLaserRoot ]; then		    
		    cmd="root -b -l -q 'combineLaser.C(\"$laserProcessed/${combinedLaserName}.root\",\"$laserProcessed/${laser1}_laser.root\",\"$laserProcessed/${laser2}_laser.root\",\"$
laserProcessed/${laser3}_laser.root\",\"$laserProcessed/${laser4}_laser.root\")'"
		    echo "$cmd"
		    logFileLaser=$laserLog/${combinedLaserName}.txt

		    if [ "$runMode" != print ]; then     
			[ "$runMode" == "qsub" ] && touch $queueFileLaser

			$runMode <<EOF
$qsubHeader
#PBS -N ${combinedLaserName}
#PBS -o $logFileLaser
#PBS -p $priority

cd $VEGAS/macros/ # so you can process macros
pwd 
while [ -f $laserQueue/${laser1}_laser -o -f $laserQueue/${laser2}_laser -o -f $laserQueue/${laser3}_laser -o -f $laserQueue/${laser4}_laser ]; do
    sleep $((RANDOM%10+20))
done 
bbcp -e -E md5= $laserProcessed/${laser1}_laser.root $combinedLaserRoot
echo "bbcp -e -E md5= $laserProcessed/${laser1}_laser.root $combinedLaserRoot"

$cmd
exitCode=\$?
rm $queueFileLaser
echo "$cmd"

if [ \$exitCode -ne 0 ]; then
    rm $combinedLaserRoot
    mv $logFileLaser $rejectDir/
else
    cp $logFileLaser $workDir/completed/
EOF
			completion=$? 
			test "$completion" -eq 0 && nJobs=$((nJobs+1)) 
		    fi # end qsub for combined laser 
		fi # if combined laser root file does not exist
	    fi # if queue file doesn't exist
	fi # check if laser is normal or combined
	
	if (( $numTels < 3 )); then
	    echo -e "\e[0;31mWarning! only ${numTels} telescopes for ${runNum}!\e[0m"
	fi
	# end laser stuff
	
	runBool="false"
	if [ "$runStage1" == "true" -o "$runStage2" == "true" ]; then

	    ##### STAGE 1 #####
	    if ( [ ! -f $rootName_1 ] && [ ! -f $queueFile_1 ] ) && ( ( [ ! -f $rootName_2 ] && [ ! -f $queueFile_2 ] && [ "$runStage2" == "true" ] ) || [ "$runStage1" == "true" ] ); then
		if [ -f $dataFile ]; then
		    runBool="true"
		    stage1cmd="`which vaStage1` -Stage1_RunMode=data $customFlags1"
		    echo "$stage1cmd $dataFile $rootName_1" 
		    queue="$queueFile_1 "
		    stages="1"
		else
		    echo "Data file $dataFile does not exits!"
		fi # data file exists
	    fi # stage 1 file doesn't exist and isn't in queue, and you're either running stage 1 or stage 2
	    
	    ##### STAGE 2 #####
	    if [ ! -f $rootName_2 ] && [ ! -f $queueFile_2 ] && [ "$runStage2" == "true" ]; then
		if [ -f $dataFile ]; then
  		    
		    runBool="true"
		    stage2cmd="`which vaStage2` $configFlags2 $customFlags2"
		    echo "$stage2cmd $dataFile $rootName_2 $laserRoot" 
		    stages="${stages}2"
		    queue="$queue $queueFile_2"
		else # data file doesn't exist
		    echo -e "\e[0;31mData file ${dataFile} does not exist! check directory\e[0m"
		fi # original data file exists in expected location, file not in queue 
	    fi # stage 2 root file does not exist and isn't in queue

	    [ "$runBool" == "true" ] && jobCmds="$subscript12 \"$stage1cmd\" $rootName_1 \"$runStage1\" \"$stage2cmd\" $rootName_2 $runNum $dataFile $laserRoot \"$environment\"
"
	    	    
	fi # run stage 1 or stage 2
	
    fi # stage 1 or stage 2, or laser 

    ##### STAGE 4 #####
    if [ "$runStage4" == "true" ]; then

	if ( [ ! -f $rootName_4 ] && [ ! -f $queueFile_4 ] ) || [ "$reprocess" == true ]; then  
	    if [ ! -f $rootName_2 ] && [ ! "$stage2cmd" ] && [ ! -f $queueFile_2 ]; then
		echo "stage 2 file $rootName_2 does not exist! skipping $rootName_4!"
		continue
	    fi

	    offset=`mysql -h romulus.ucsc.edu -u readonly -s -N -e "use VERITAS; SELECT offset_distance FROM tblRun_Info WHERE run_id = ${runNum}"`

	    if [ "$ltMode" == auto ]; then
		ltName=lt_Oct2012_${array}_ATM${atm}_7samples_${ltVegas}_allOffsets_LZA
		#ltName=lt_Oct2012_${array}_ATM${atm}_${simulation}_${ltVegas}_7sam_allOff_LZA_std_d${DistanceUpper//./p}
		test "$DistanceUpper" == 1.43 || ltName=${ltName}_d${DistanceUpper//./p} # std 

		ltFile=$tableDir/${ltName}.root
	    fi # automatic lookup table 
	    tableFlags="-table=${ltFile}"

	    if [ "$stg4method" == disp ]; then
		
		if [ "$dispMethod" == 5t ]; then
		    dtName=TMVA_Disp.xml
		else
		    dtName=dt_Oct2012_${array}_ATM${atm}_GrISUDet_${ltVegas}_7sam_${offset}wobb_Z50-55_std_d${DistanceUpper//./p}.root 
		    # specify disp mode 
		fi
		
		dtFile=$tableDir/${dtName}
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

	    if [ -n "$TelCombosToDeny" ]; then # if [ $telCombosToDeny ]
		denyFlag="-TelCombosToDeny=$telCombosToDeny"
            elif [ -n "$autoTelCombosToDeny" ]; then # V4
                denyFlag="-TelCombosToDeny=$autoTelCombosToDeny"
	    else
		denyFlag=""
	    fi
	    
	    if [ "$autoCutTels4" == "true" ]; then 
		laserNum=(1)
		cutTelFlags=""
		for laser in $3 $4 $5 $6; do 
		    test "$laser" == "--" && cutTelFlags="-CutTelescope=${laserNum}/1 -OverrideLTCheck=1"  #cutTelFlags="$cutTelFlags -CutTelescope=${laserNum}/1"
		    laserNum=$((laserNum+1))
		done
	    fi # automatically add -CutTelescopes flag, don't think this is necessary 

	    # not sure if should use cutTelFlags
            stage4cmd="`which vaStage4.2` $tableFlags $cutFlags4 $configFlags4 $denyFlag $cutTelFlags $rootName_4"
	    echo "$stage4cmd"
	    jobCmds="$jobCmds
$subscript45 \"$stage4cmd\" \"$rootName_4\" \"$rootName_2\" \"$environment\" $spectrum &>> $runLog4 
"
	    stages="${stages}4"
	    queue="$queue $queueFile_4"
	    # condense 
	    if [ ! -f $ltFile ]; then
		echo -e "\e[0;31m $ltFile Does Not Exist!!, skipping $runNum!\e[0m"
		continue
	    fi
	    if [ "$stg4method" == disp ] && [ ! -f $dtFile ]; then
		echo -e "\e[0;31m $dtFile Does Not Exist!! Skipping $runNum!\e[0m"
		continue
	    fi

	fi # rootName_4 does not exist
    fi # runStage4

    ##### STAGE 5 #####

    if [ "$runStage5" == "true" ]; then
	
	if [ ! -f $rootName_5 ] || [ "$reprocess" == true ]; then
	    if [ -f $rootName_4 ] || [ -f $queueDir/${stage4subDir}_${runNum}.stage4 ] || [ "$stage4cmd" ] || [ "$runMode" == print ]; then
		
		if [ ! -f $queueFile_5 ]; then
		    
		    if [ "$stage5cuts" == "auto" ]; then
			cutFlags5="-MeanScaledLengthLower=$MeanScaledLengthLower -MeanScaledLengthUpper=$MeanScaledLengthUpper -MeanScaledWidthLower=$MeanScaledWidthLower -MeanScaledWidthUpper=$MeanScaledWidthUpper -MaxHeightLower=$MaxHeightLower"
		    elif [ "$stage5cuts" == "none" ]; then
			cutFlags5=""
		    else
			cutFlags5="-cuts=$stage5cuts"
		    fi
		    
		    if [ "$useStage5outputFile" == "true" ]; then
			stage5cmd="`which vaStage5` $configFlags5 $cutFlags5 $customFlags5 -inputFile=$rootName_4 -outputFile=$rootName_5"
		    else
			stage5cmd="`which vaStage5` $configFlags5 $cutFlags5 $customFlags5 -inputFile=$rootName_5"
		    fi
		    
		    if [ "$useBDT" == "true" ]; then
			
			weightsDir=${weightsDirBase/EPOCH/$epoch} 
			#  
			if [[ ! -d ${weightsDir} ]]; then
			    echo -e "\e[0;31m${weightsDir} does not exist. this may be a problem!\e[0m"
			fi
			stage5cmd="$stage5cmd -BDTDirectory=${weightsDir}"
		    fi # BDT 
		    
		    if [ "$applyTimeCuts" == "true" ]; then
			timeCutMask=`mysql -h romulus.ucsc.edu -u readonly -s -N -e "use VOFFLINE; SELECT time_cut_mask FROM tblRun_Analysis_Comments WHERE run_id = ${runNum}"`
			if [ "$timeCutMask" != "NULL" ]; then 
			    stage5cmd="$stage5cmd -ES_CutTimes=${timeCutMask}"
			fi
		    fi # apply time cuts
		    
		    echo "$stage5cmd"
		    jobCmds="$jobCmds
$subscript45 \"$stage5cmd\" \"$rootName_5\" \"$rootName_4\" \"$environment\" $spectrum &>> $runLog5
"
		    stages="${stages}5"
		    queue="$queue $queueFile_5"
		    
		fi # queueFile_5 does not exist 
	    else
		echo "$rootName_4 is not present, skipping $rootName_5 !"
	    fi # stage 4 file exists or is in queue  
	fi # stage 5 not present yet
    fi # runStage5

    if [ "$runMode" != print ] && [ "$jobCmds" ]; then
     
	$runMode <<EOF
$qsubHeader
#PBS -N ${runNum}_${stages} 
#PBS -o $logDir/errors/${runNum}.txt
#PBS -p $priority

for sig in $signals; do  
    trap "echo \"TRAP! Signal: $sig\"; rm $queue; exit $sig" $sig
done

date

$jobCmds

EOF
	completion=$? 
	#echo "VEGAS job \$PBS_JOBID started on:  " ` hostname -s` " at: " ` date ` >> $laserLog/qsubLog.txt

	if [ "$completion" -eq 0 ]; then
	    [ "$runMode" == "qsub" ] && touch $queue 
	    nJobs=$((nJobs+1))  
	fi
 
    fi # end check runmode and that there is a job to submit 

done < $readList # loop over lines in loggen file 


##### STAGE 6 #####
if [ "$runStage6" == "true" ]; then
    cmd="`which execute-stage6.sh` -e \"$environment\" -s spectrum -d $subDir -n $name -r $runMode"
    echo "$cmd"
fi

if [ "$runMode" == "qsub" ]; then
    echo -e "script submitted $nJobs jobs \t on ` date ` \n" | tee ${logDir}/qsubLog.txt
fi

exit 0 # success 
