#!/bin/bash

### you must source file that exports the variables:
# sourceName baseDir options spectrum
# use environment option first if you want to override other variables

environment=$HOME/environments/SgrA_source.sh
outputDir=results

sourceName=SgrA 
loggenFile=$HOME/runlists/SgrA_wobble_4tels.txt
#loggenFile=$HOME/runlists/SgrA_wobble_fixed.txt 
positionFlags="-S6A_TestPositionRA=266.4168 -S6A_TestPositionDEC=-29.0078"

#common defaults, make more variables? 
options="-S6A_Spectrum=1 -S6A_ExcludeSource=1 -S6A_DrawExclusionRegions=3"
options="$options -UL_PhotonIndex=2.5 -RBM_CoordinateMode=\"Galactic\""  
exclusionList=$HOME/config/SgrA_exclusionList.txt # put in environment

source $VSCRIPTS/shellScripts/setCuts.sh 
spectrum=medium
cuts=auto

#subDir=stg5
extension=".stage5.root"
readFlag="-S6A_ReadFromStage5Combined=1" 

backupPrompt=false
useTestPosition=false 
trashDir=$HOME/.trash

runMode=print
regen=false # for remaking runlist

### process options
while getopts d:l:f:s:Sn:Bc:C:x:e:r:qb4oOtj FLAG; do 
    case $FLAG in
	e)
	    environment=$OPTARG
	    ;;
	l)
	    loggenFile=$OPTARG # right now this has to come after environment option
	    ;;
	c)
	    case $OPTARG in 
		all | auto) cuts=$OPTARG;; 
		*) 
		    cuts=file
		    cutsFile=$OPTARG
		    cutsFlag="-cuts=$cutsFile" 
		    ;; 
	    esac 
	    ;;
	C)
	    configFile=$OPTARG
	    options="$options -config=$configFile"
	    ;;
	x)
	    exclusionList=$OPTARG
	    ;;
	s)
	    spectrum=$OPTARG
	    ;;
	S)
	    options="$options -S6A_Spectrum=0"
	    ;;
	d) 
	    subDir=$OPTARG
	    ;;
	n)
	    name=$OPTARG
	    ;;
	B)  # activate BDT mode  
	    mode=BDT
	    readFlag="-S6A_ReadFromStage5Combined=1"
	    extension=".stage5.root"
	    ;;
	4) 
	    readFlag="-S6A_ReadFromStage4=1"
	    extension=".stage4.root"
	    ;;
	o)
	    options="$options -OverrideEACheck=1"
	    ;; 
	O)
	    options="$options -S6A_ObsMode=On/Off"
	    ;; 
	f)
	    runFile=$OPTARG
	    ;;
	r) 
	    runMode=$OPTARG
	    ;;
	q)
	    runMode=qsub
	    options="$options -S6A_Batch=1"
	    ;;
	b) # change argument, decide if overwriting runlist, could just trash old before 
	    regen=false
	    ;;
	t)
	    useTestPosition=true
	    ;;
	j)
	    options="$options -RBM_CoordinateMode=\"J2000"\"
	    ;;
	?) # unrecognized option - show help
	    echo -e "Option -${BOLD}$OPTARG${NORM} not allowed."
	    ;;
    esac # option cases
done # getopts loop
shift $((OPTIND-1))  #This tells getopts to move on to the next argument.    

### prepare variables and directories after options are read in
source $environment
finalRootDir=$VEGASWORK/processed/${subDir}

for variable in $sourceName $loggenFile $spectrum $workDir; do 
    if [ ! $variable ]; then
	echo "must set $variable ! Check environment file $environment. Exiting.."
	exit 1
    fi
done # check that necessary variables are set
if [ ! $name ]; then
    name=${subDir} #${spectrum}${mode}
fi

if [ "$useTestPosition" == "true" ]; then
    options="$options $positionFlags"
fi

if [ $exclusionList ] && [ "$exclusionList" != none ]; then 
    options="$options -S6A_UserDefinedExclusionList=$exclusionList"
fi # could clean up 

# had separate variable for baseDir
logDir=$VEGASWORK/log/stage6
backupDir=$VEGASWORK/backup
outputDir=$VEGASWORK/$outputDir
for dir in $logDir $backupDir $outputDir; do
    if [ ! -d $dir ]; then
	echo "$dir does not exist, creating.."
	mkdir -p $dir
    fi
done

# set cuts based on spectrum 
setCuts $spectrum 
if [ "$cuts" == auto ] || [ "$cuts" == all ]; then
    cutsFlag="-S6A_RingSize=${S6A_RingSize} -RBM_SearchWindowSqCut=$RBM_SearchWindowSqCut"
    if [ "$cuts" == all ]; then
	cutsFlag="$cutsFlag -MeanScaledLengthLower=${MeanScaledLengthLower} -MeanScaledLengthUpper=${MeanScaledLengthUpper} -MeanScaledWidthLower=${MeanScaledWidthLower} -MeanScaledWidthUpper=${MeanScaledWidthUpper} -MaxHeightLower=${MaxHeightLower}"
    fi
fi
if [ "$spectrum" == "medium" ]; then
    pyCuts=med
else
    pyCuts="$spectrum"
fi 

# check to see if root file or logfile already exists, and back up
logFile=$logDir/stage6_${name}_${sourceName}.txt
test "$runMode" != print  && logOption="| tee $logFile"
outputFile=$VEGASWORK/results/stage6_${name}_${sourceName}s6.root
for file in $logFile $outputFile; do
    if [ -f $file ]; then
	echo "$file already exists! "
	backupPrompt=true
    fi
done

if [ -n "$runFile" ]; then
    test -f $runFile || ( echo "$runFile does not exist! exiting.."; exit 1 )
fi # if runFile is specified, make sure it exists 

if [ "$runMode" != print ]; then
    
    if [ "$backupPrompt" == "true" ]; then
	echo "backup these files and continue? type 'Y' to continue"
	read response
	if [ $response == 'Y' ]; then
	    test ! -f $logFile || mv $logFile $backupDir/log/
	    test ! -f $outputFile || mv $outputFile $backupDir/stage6/
	fi
    fi # check file already exists
    
    if [ ! $runFile ]; then 

	runFile=$HOME/work/${sourceName}_${name}_runlist.txt
	### create runfile using python script if it doesn't exist ###
	echo "extension: $extension" 
	if [ ! -f $runFile ]; then 
	    tempRunlist=`mktemp` || exit 1 # intermediate runlist file 
	    while read -r line; do 
		set -- $line
		echo "$finalRootDir/${2}${extension}" >> $tempRunlist
	    done < $loggenFile
	    echo $loggenFile
	    python $BDT/macros/s6RunlistGen.py --EAmatch --EAdir $TABLEDIR/ --cuts $pyCuts $tempRunlist $runFile # -- | $logOption
	fi # runfile doesn't exist so must be created
    fi # if runFile isn't already specified  
    
    if [ ! -f $runFile ]; then
	echo -e "$runFile doesn't exist, exiting!\n"
	exit 2
    fi

fi # if runMode is not print only 

cmd="`which vaStage6` -S6A_ConfigDir=${outputDir} -S6A_OutputFileName=stage6_${name}_${sourceName} $options $readFlag $cutsFlag $runFile " #
echo "$cmd"

if [ "$runMode" != print ]; then
    $runMode <<EOF
#PBS -S /bin/bash
#PBS -l nodes=1,mem=2gb
#PBS -j oe
#PBS -o $logFile
#PBS -N stage6_${name}_${sourceName}

source $environment
date
hostname
root-config --version 
echo "$ROOTSYS"
cd $VEGASWORK
#git --git-dir $VEGAS/.git rev-parse HEAD
git --git-dir $VEGAS/.git describe --tags 

if [ "$exclusionList" != none ]; then 
cat $exclusionList
fi

$cmd
exitCode=\$?
echo "$cmd" 

if [ $cutsFile ]; then
cat $cutsFile
fi

test -f todayresult && mv todayresult $VEGASWORK/log/

#if [ "\$exitCode" -e 0 ]; then 
cp $logFile $VEGASWORK/completed/
#else
#test -f $logFile && mv $logFile $VEGASWORK/rejected/
#fi

exit \$exitCode 

EOF
    EXITCODE=$?
fi # runModes 

# after running and logging, check for successful run
if [ "$runMode" != print ] && [ $EXITCODE -ne 0 ]; then
    echo "FAILED!"
    if [ -f $logFile ]; then
	mv $logFile $VEGASWORK/rejected/
    fi
    exit 1
fi

exit 0 # Success!
