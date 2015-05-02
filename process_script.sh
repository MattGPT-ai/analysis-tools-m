#!/bin/bash

### BDT_script.sh processes the files in a logGen format runlist file through the selected stages with the selected options, tailored for Boosted Decision Trees ###

# exceptions that need to be handled include: combined laser files, laser files that are on a different date from runs being processed .. 

##### SET DEFAULTS #####

priority=0

runLaser="false"
runStage1="false"
runStage2="false"
runStage4="false"
runStage5="false"
runStage6="false"

baseDataDir=/veritas/data
scratchDir=/scratch/mbuchove
tableDir="$USERSPACE/tables"
cutsDir=$HOME/cuts
laserDir=$LASERDIR
weightsDirBase=$BDT/weights
weightsDir=5-34_defaults
trashDir=$HOME/.trash

spectrum=medium
simulation=Corsika
environment=""

DistanceUpper='0/1.43'
NTubesMin='0/5'
stage4cuts=auto
declare -A stg4_size_map
stg4_size_map[V4V5_SoftLoose]="0/200"
stg4_size_map[V6_SoftLoose]="0/400"
stg4_size_map[V4V5_medium]="0/400"
stg4_size_map[V6_medium]="0/700"
stg4_size_map[V4V5_hard]="0/1000"
stg4_size_map[V6_hard]="0/1200"

stage5cuts=auto
declare -A stg5_cuts_map
stg5_cuts_map[all]="-MeanScaledWidthLower=.05 -MeanScaledLengthLower=.05"
stg5_cuts_map[loose]="-MeanScaledWidthUpper=1.1 -MeanScaledLengthUpper=1.4"
stg5_cuts_map[SoftMedium]="-MeanScaledWidthUpper=1.1 -MeanScaledLengthUpper=1.3 -MaxHeightLower=7"
stg5_cuts_map[hard]="-MeanScaledWidthUpper=1.15 -MeanScaledLengthUpper=1.4"

configFlags4=""
configFlags5="-Method=VACombinedEventSelection"
suffix="" # only applied to stages 4 and 5 by default
useStage5outputFile="true"
useBDT="false"

runMode="print" # 

laserSubscript=$HOME/bin/subscript_laser.sh
subscript12=$HOME/bin/subscript_stage1and2.sh
subscript45=$HOME/bin/subscript_4or5.sh

applyTimeCuts="true"

##bin/sh -f
#PBS -S /bin/bash
#PBS -p 0

qsubHeader="
#PBS -S /bin/bash 
#PBS -l nodes=1,mem=2gb
#PBS -j oe
#PBS -A mgb000
#PBS -V 
"

stage1subDir=stg1
stage2subDir=stg2
stage4subDir=stg4
stage5subDir=stg5

##### Process Arguments #####
# use getopt to parse arguments 
args=`getopt -o l124d:5D:ahbB::s:qre:c:C:p:kd -l disp,BDT:: -n 'process_script.sh' -- $*` 
eval set -- $args 

for i; do                  # loop through options
    case "$i" in 
	-l) runLaser="true"
	    shift ;;
	-1) runStage1="true"
	    shift ;;
	-2) runStage2="true"
	    shift ;;
	-4) runStage4="true" ; 
	    shift ;;
	-d) stage4subDir="$2"
	    shift 2 ;;
	-5) runStage5="true"
       	    shift ;;
	-D) stage5subDir="$2"
	    shift ;; 
	-a) runStage1="true"; runStage2="true"; runStage4="true"; runStage5="true"
	    shift ;;
	-q) runMode="qsub"
	    shift ;;
	-r) runMode="shell"
	    shift ;;
	-s) spectrum=$2
	    shift ; shift ;;
	-c) stage4cuts=$2
	    # choose auto to automatically choose optimized cuts, or none to not cut
	    shift ; shift ;;
	-C) stage5cuts=$2
	    # same as for stage 4
	    shift ; shift ;;
	-B|BDT) configFlags5="$configFlags5 -UseBDT=1"
	    useBDT="true"
	    weightsDir="$2"
	    shift 2 ;;
#	    useStage5outputFile="true"
	-d|--disp) 
	    configFlags4="$configFlags4 -DR_Algorithm=Method5t" #t stands for tmva, Method6 for average disp and geom
	    useDisp=true
	    DistanceUpper='0/1.38'
	    shift ; shift ;;
	-e) environment=$2
	    source $environment
	    envFlag="-e $environment"
	    stage4subFlags="$stage4subFlags -e $environment"
	    stage5subFlags="$stage5subFlags -e $environment"
	    shift; shift ;;
	-p) priority=$2
	    shift ; shift ;;
	-k) simulation=KASCADE
	    shift ;; 
	-h) configFlags4="$configFlags4 -HillasBranchName=HFit"
	    configFlags5="$configFlags5 -HillasBranchName=HFit"
	    suffix="${suffix}_hfit"
	    shift ;; #stage4cuts="BDT_hfit4cuts.txt"
	-b) useStage5outputFile="false"
	    shift ;;
	--) shift; break ;;
    esac # end case $i in options
done # loop over command line arguments 

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
    sizeSpec=softLoose
fi # size setting for soft and loose is the same 

for array in V5 V6; do 
    if [[ "$useBDT" == "true" ]] && [[ ! -d $weightsDirBase/${weightsDir}_${array} ]]; then
	echo "$weightsDirBase/${weightsDir}_${array} does not exist. this may be a problem!"
    fi
done # check for weights dirs

### quick check for files and directories ###
for subDir in rejected queue backup processed; do
  if [ ! -d $workDir/$subDir ]; then
      echo "Must create directory $workDir/$subDir"
      if [ "$runMode" != "print" ]; then
	  mkdir -p $workDir/$subDir
      fi
  fi # processing directories do not exist 
done
subDirs="$stage1subDir $stage2subDir"
if [ "$runStage4" == "true" ]; then
    subDirs="$subDirs $stage4subDir"
fi
if [ "$runStage5" == "true" ]; then
    subDirs="$subDirs $stage5subDir"
fi
for dir in $processDir $logDir; do
    for subDir in $subDirs; do
	if [ ! -d $dir/$subDir ]; then
	    echo "Must create directory $dir/$subDir"
	    if [ "$runMode" != "print" ]; then
		mkdir -p $dir/$subDir
	    fi
	fi # processing directories do not exist 
    done # loop over subdirs
done # loop over main dirs, process and log

#check for lt files, maybe only do if running stage 4
#for season in Winter Summer; do
#    for array in V4 V5 V6; do
#        if [ ! -f $tableDir/${ltMap[${array}_${season}]} ]; then
#             echo -e "\e[0;31m$tableDir/${ltMap[${array}${season}]} does not exist! this may be a problem if you run stage 4 :(\e[0m"
#        fi
#    done
#done


if [ "$runStage1" == "true" -o "$runStage2" == "true" -o "$runLaser" == "true" ]; then
    
    while read -r line
    do
	set -- $line
	
	
	runDate=$1
	runNum=$2
	laser1=$3; laser2=$4; laser3=$5; laser4=$6 # shorten variable names
	combinedLaserName="combined_${laser1}_${laser2}_${laser3}_${laser4}_laser"

	dataDir=$baseDataDir/d${runDate}/
	runData="$scratchDir/${runNum}.cvbf"
	
	laserProcessed=$laserDir/processed # shorten variable name 
	laserQueue=$laserDir/queue
	laserLog=$laserDir/log

	laserRoot="null"
	laserNum="null"
	
	numTels=(0)
	runBool="false"

	stage1cmd="null"
	stage2cmd="null"
	
	for n in $laser1 $laser2 $laser3 $laser4; do
	    # loop through the lasers
	    if [ "$n" != "--" ]; then
		
		numTels=$((numTels + 1))
		
		if [ "$laserNum" == "null" ]; then
		    
		    laserNum=$n
		    runBool="true"
		    
		elif [ "$laserNum" != "$n" ]; then
		    laserRoot="${combinedLaserName}.root"
		    runBool="true"
		fi # new laser num is different from previous
		
		laserData="NULL"
		if [ "$runBool" == "true" ]; then
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
			    laserCmd="`which vaStage1` "
			    echo "$laserCmd $laserData $laserProcessed/${n}_laser.root" 
			    if [ "$runMode" == "qsub" ]; then
				
				touch $laserQueue/${n}_laser
				
				qsub <<EOF
$qsubHeader
#PBS -N ${n}_laser
#PBS -o $laserLog/qsubLog.txt
#PBS -p $priority

$laserSubscript "$laserCmd" $laserData $laserProcessed/${n}_laser.root $envFlag
EOF
#echo "VEGAS job \$PBS_JOBID started on:  " ` hostname -s` " at: " ` date ` >> $laserLog/qsubLog.txt

			    elif [ "$runMode" == "shell" ]; then
				
				$laserSubscript "$stage1cmd" $laserData $laserProcessed/${n}_laser.root $envFlag
				
			    fi # end qsub for regular laser 
			    
			else ### end run normal laser
			    echo -e "\e[0;31mLaser data file ${dataDir}/${n}.cvbf does not exist! check directory\e[0m"
			fi # data file found
		    fi # laser file does not yet exist
		fi # run bool is true
		
	    fi # laser isn't --
	done # for loop over telescopes
	
	if [[ "$laserRoot" == "null" ]]; then
	    
	    laserRoot="$laserProcessed/${laserNum}_laser.root"
	    
	else # process the combined laser file
	    if [ ! -f $laserQueue/${combinedLaserName} ]; then
		if [ ! -f $laserProcessed/${combinedLaserName}.root ]; then
		    
		    echo "root -b -l -q 'combineLaser.C(\"$laserProcessed/${combinedLaserName}.root\",\"$laserProcessed/${laser1}_laser.root\",\"$laserProcessed/${laser2}_laser.root\",\"$laserProcessed/${laser3}_laser.root\",\"$laserProcessed/${laser4}_laser.root\")'"
		    
		    if [ "$runMode" == "qsub" ]; then     
			
			touch $laserQueue/${combinedLaserName}
			
			qsub <<EOF
$qsubHeader
#PBS -N ${combinedLaserName}
#PBS -o $laserLog/${combinedLaserName}.txt
#PBS -p $priority

cd $VEGAS/macros/ # so you can process macros
pwd 
while [ -f $laserQueue/${laser1}_laser -o -f $laserQueue/${laser2}_laser -o -f $laserQueue/${laser3}_laser -o -f $laserQueue/${laser4}_laser ]; do
    sleep $((RANDOM%10+20))
done 
bbcp $laserProcessed/${laser1}_laser.root $laserProcessed/${combinedLaserName}.root
echo "bbcp $laserProcessed/${laser1}_laser.root $laserProcessed/${combinedLaserName}.root"

root -b -l -q 'combineLaser.C("$laserProcessed/${combinedLaserName}.root","$laserProcessed/${laser1}_laser.root","$laserProcessed/${laser2}_laser.root","$laserProcessed/${laser3}_laser.root","$laserProcessed/${laser4}_laser.root")'
exitCode=\$?
rm $laserQueue/${combinedLaserName}
echo "root -b -l -q 'combineLaser.C(\"$laserProcessed/${combinedLaserName}.root\",\"$laserProcessed/${laser1}_laser.root\",\"$laserProcessed/${laser2}_laser.root\",\"$laserProcessed/${laser3}_laser.root\",\"$laserProcessed/${laser4}_laser.root\")'"
if [ \$exitCode -ne 0 ]; then
rm $laserProcessed/${combinedLaserName}.root
mv $laserLog/${combinedLaserName}.txt $rejectDir
EOF
#PBS -o $laserLog/qsubLog.txt
		    elif [ "$runMode" == "shell" ]; then
			if [ -f $laserLog/${combinedLaserName}.txt ]; then
			    mv $laserLog/${combinedLaserName}.txt $trashDir
			fi

			cd $VEGAS/macros/
			bbcp $laserProcessed/${laser1}_laser.root $laserProcessed/${combinedLaserName}.root  
			root -b -l -q 'combineLaser.C("$laserProcessed/${combinedLaserName}.root","$laserProcessed/${laser1}_laser.root","$laserProcessed/${laser2}_laser.root","$laserProcessed/${laser3}_laser.root","$laserProcessed/${laser4}_laser.root")' 2>&1 | tee $laserLog/${combinedLaserName}.txt 
		    fi # end qsub for combined laser 
		fi # if combined laser root file does not exist
	    fi # if queue file doesn't exist
	fi # check if laser is normal or combined
	
	if (( $numTels < 3 )); then
	    echo -e "\e[0;31mWarning! only ${numTels} telescopes for ${runNum}!\e[0m"
	fi
	# end laser stuff
	
	rootName_1="$processDir/${stage1subDir}/${runNum}.stage1.root"	    
	rootName_2="$processDir/${stage2subDir}/${runNum}.stage2.root"
	runBool="false" # reset 
	stage1cmd="NULL" # must match null assignment in subscript
	stage2cmd="NULL"
	dataFile=${dataDir}/${runNum}.cvbf		    

	if [ "$runStage1" == "true" -o "$runStage2" == "true" ]; then

	    ##### STAGE 1 #####
	    if ( [ ! -f $rootName_1 ] && [ ! -f ${queueDir}/${runNum}.stage1 ] ) && ( ( [ ! -f $rootName_2 ] && [ ! -f ${queueDir}/${runNum}.stage2 ] && [ "$runStage2" == "true" ] ) || [ "$runStage1" == "true" ] ); then
		if [ -f $dataFile ]; then
		    runBool="true"
		    stage1cmd="`which vaStage1` -Stage1_RunMode=data "
		    echo "$stage1cmd $dataFile $rootName_1" 
		else
		    echo "Data file $dataFile does not exits!"
		fi # data file exists
	    fi # stage 1 file doesn't exist and isn't in queue, and you're either running stage 1 or stage 2
	    
	    ##### STAGE 2 #####
	    if [ ! -f $rootName_2 ] && [ ! -f ${queueDir}/${runNum}.stage2 ] && [ "$runStage2" == "true" ]; then
		if [ -f $dataFile ]; then
  		    
		    runBool="true"
		    stage2cmd="`which vaStage2` "
		    echo "$stage2cmd $dataFile $rootName_2 $laserRoot" 
		    
		else # data file doesn't exist
		    echo -e "\e[0;31mData file ${dataFile} does not exist! check directory\e[0m"
		fi # original data file exists in expected location, file not in queu
	    fi # stage 2 root file does not exist and isn't in queue
	    
	    
	    if [ "$runBool" == "true" ]; then
		if [ "$runMode" == "qsub" ]; then
		    
		    touch $queueDir/${stage1subDir}_${runNum}.stage1
		    touch $queueDir/${stage2subDir}_${runNum}.stage2
		    
		    qsub <<EOF
$qsubHeader
#PBS -N ${runNum}.stage12
#PBS -o $logDir/qsubLog.txt
#PBS -p $priority

$subscript12 "$stage1cmd" "$stage2cmd" $runNum $dataFile $laserRoot $envFlag
EOF
#echo "VEGAS job \$PBS_JOBID started on:  "` hostname -s` " at: " ` date ` >> $logDir/qsubLog.txt
#PBS -o $logDir/${runNum}.stage12.txt

		elif [ "$runMode" == "shell" ]; then
		    $subscript12 "$stage1cmd" "$stage2cmd" $runNum $dataFile $laserRoot $envFlag
		fi # end qsub for stage 1 data file
	    fi # end runBool = true
	    
	fi # run stage 1 or stage 2
	
    done < $readList
fi # stage 1 or stage 2, or laser 

##### STAGE 4 #####
if [ "$runStage4" == "true" ]; then
    while read -r line; do
	set -- $line
	
	runDate=$1
	runNum=$2
	rootName_2="$processDir/${stage2subDir}/${runNum}.stage2.root"
	rootName_4="$processDir/${stage4subDir}/${runNum}${suffix}.stage4.root"
	runLog="$logDir/${stage4subDir}/${runNum}${suffix}.stage4.txt"
	
	runMonth=$(( (runDate % 10000 - runDate % 100) / 100 ))
	if (( runMonth > 4 && runMonth < 11 )); then
	    season=22
	else
	    season=21
	fi

        # determine array for stage 4   
        if (( runDate < 20090900 )); then
            array=MDL8OA_V4_OldArray
            sizeArray=V4V5
        elif (( runDate > 20120900 )); then
            array=MDL10UA_V6_PMTUpgrade
            sizeArray=V6
        else
            array=MDL15NA_V5_T1Move
            sizeArray=V4V5
        fi

        tableFlags="-table=$tableDir/lt_${array}_ATM${season}${simulation}_vegasv250rc5_7sam_Alloff_std_d1.43_LZA.root" # 1p43
	if [ $useDisp ]; then 
	    tableFlags="$tableFlags -DR_DispTable=$tableDir/dt_${array}_ATM${season}${simulation}_vegasv250rc5_7sam_Alloff_std_d1.43_LZA.root" # PathToTMVA_Disp.xml
	fi 

        SizeLower=${stg4_size_map[${sizeArray}_${sizeSpec}]}

        queueFile=$queueDir/${stage4subDir}_${runNum}.stage4${suffix}
        if [ ! -f $rootName_4 -a ! -f $queueFile ]; then
            if [ "$stage4cuts" == "auto" ]; then
                stg4_cuts="-DistanceUpper=${DistanceUpper} -NTubesMin=${NTubesMin} -SizeLower=${SizeLower}"
            elif [ "$stage4cuts" == "none" ]; then
		stg4_cuts=""
	    else
                stg4_cuts="-cuts=${stage4cuts}"
            fi

            if [ "$array" == "V4" ]; then
                telCombosToDeny="-TelCombosToDeny=T1T4"
	    else
		telCombosToDeny=""
	    fi

            cmd="`which vaStage4.2` $tableFlags $stg4_cuts $configFlags4 $telCombosToDeny $rootName_4"
	    echo "$cmd"


	    if [ "$runMode" == "qsub" ]; then
		touch $queueFile

		qsub <<EOF
$qsubHeader
#PBS -N ${stage4subDir}${runNum}${suffix}.stage4
#PBS -o $runLog
#PBS -p $priority

$subscript45 "$cmd" $rootName_4 $rootName_2 $cutsDir/$stage4cuts $stage4subFlags
echo "$spectrum"
EOF
#PBS -o $runLog		
#echo "VEGAS job \$PBS_JOBID started on:  "` hostname -s` " at: " ` date ` >> $logDir/qsubLog.txt
	    elif [ "$runMode" == "shell" ]; then
		if [ -f $runLog ]; then
		    mv $runLog $trashDir/
		fi
		
		# make one variable for qsub as well
		$subscript45 "$cmd" $rootName_4 $rootName_2 $cutsDir/$stage4cuts $stage4subFlags | tee $runLog
		
	    fi # end runmode check

	    #	    cat $cutsDir/${stage4cuts} >> $runLog # deal with getting this into the log file
	fi # rootName_4 does not exist

    done < $readList  
fi # runStage4

##### STAGE 5 #####

if [ "$runStage5" == "true" ]; then
    while read -r line; do
	set -- $line
	
	runDate=$1
	runNum=$2
	rootName_4="${processDir}/${stage4subDir}/${runNum}${suffix}.stage4.root"
	rootName_5="${processDir}/${stage5subDir}/${runNum}${suffix}.stage5.root"
	runLog="${logDir}/${stage5subDir}/${runNum}${suffix}.stage5.txt"

	# determine array for both stage 4 and 5
	if (( runDate < 20090900 )); then
	    array=V4
	elif (( runDate > 20120900 )); then
	    array=V6
	else
	    array=V5
	fi

	if [ ! -f $rootName_5 ]; then
	    queueName=${queueDir}/${stage5subDir}_${runNum}${suffix}.stage5
	    if [ ! -f $queueName ]; then
	
		
		if [ "$useStage5outputFile" == "true" ]; then
		    cmd="`which vaStage5` $configFlags5 -inputFile=$rootName_4 -outputFile=$rootName_5"
		else
		    cmd="`which vaStage5` $configFlags5 -inputFile=$rootName_5"
		fi

		if [ "$stage5cuts" == "auto" ]; then
		    cmd="$cmd ${stg5_cuts_map[all]}"
		    if [ "$spectrum" == "soft" ] || [ "$spectrum" == "medium" ]; then
			cmd="$cmd ${stg5_cuts_map[SoftMedium]}"
		    else
			cmd="$cmd ${stg5_cuts_map[${spectrum}]}"
		    fi
		elif [ "$stage5cuts" != "none" ]; then
		    cmd="$cmd -cuts=$stage5cuts"
		fi

		if [ "$useBDT" == "true" ]; then
		    cmd="$cmd -BDTDirectory=${weightsDirBase}/${weightsDir}_${array}"
		fi

		if [ "$applyTimeCuts" == "true" ]; then
		    timeCutMask=`mysql -h romulus.ucsc.edu -u readonly -s -N -e "use VOFFLINE; SELECT time_cut_mask FROM tblRun_Analysis_Comments WHERE run_id = ${runNum}"`
		    if [ "$timeCutMask" != "NULL" ]; then 
			cmd="$cmd -ES_CutTimes=${timeCutMask}"
		    fi
		fi # apply time cuts
		
		echo "$cmd"

		if [ "$runMode" == "qsub" ]; then
		    
		    touch $queueName
		    
		    qsub <<EOF
$qsubHeader
#PBS -N ${stage5subDir}${runNum}${suffix}.stage5
#PBS -o $runLog
#PBS -p $priority

$subscript45 "$cmd" $rootName_5 $rootName_4 $cutsDir/$stage5cuts $stage5subFlags
echo "$spectrum"
EOF
#PBS -o $runLog
#echo "VEGAS job \$PBS_JOBID started on: \` hostname -s\` at: \` date \` " >> $logDir/qsubLog.txt 
		elif [ "$runMode" == "shell" ]; then
		    if [ -f $runLog ]; then
			mv $runLog $trashDir/
		    fi
		    
		    $subscript45 "$cmd" $rootName_5 $rootName_4 $cutsDir/$stage5cuts $stage5subFlags | tee $runLog
		    
		fi # end runmode check
	    fi # stage 5 not in queue 
	fi # stage 5 not present yet
    done < $readList
fi # runStage5

##### STAGE 6 #####
if [ "$runStage6" == "true" ]; then
    cmd="vaStage6 -config=${HOME}/config/BDT_stage6.config ${HOME}/run/BDT_runlist.txt"
    echo "$cmd"
    echo `which vaStage6`
    #submitJob "$cmd" BDT_stage6
fi

if [ "$runMode" == "qsub" ]; then
    echo -e "script complete \t on ` date ` \n" >> ${logDir}/qsubLog.txt
fi

exit 0 # success 
