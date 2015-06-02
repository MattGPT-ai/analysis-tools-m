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
options="-S6A_Spectrum=1 -OverrideEACheck=0 -S6A_ExcludeSource=1 -S6A_DrawExclusionRegions=3"
options="$options -UL_PhotonIndex=2.1" # 
exclusionListFlag="-S6A_UserDefinedExclusionList=$HOME/config/SgrA_exclusionList.txt" # put in environment
RingSize=.1
SearchWindowSqCut=.01

spectrum=medium

subDir=stg5
extension=".stage5.root"
readFlag="-S6A_ReadFromStage5Combined=1" 

backupPrompt=false
useTestPosition=false 
trashDir=$HOME/.trash

runMode=print
regen=false # for remaking runlist

### process options
while getopts s:d:n:Bc:l:e:r:qb4of:tg FLAG; do
    case $FLAG in
	e)
	    environment=$OPTARG
	    ;;
	l)
	    loggenFile=$OPTARG # right now this has to come after environment option
	    ;;
	c)
	    cutsFile=$OPTARG
	    cutsFlag="-cuts=${cutsFile}"
	    ;;
	s)
	    spectrum=$OPTARG
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
	    options="$option -S6A_Batch=1"
	    ;;
	b) # change argument, decide if overwriting runlist, could just trash old before 
	    regen=false
	    ;;
	t)
	    useTestPosition=true
	    ;;
	g)
	    options="$options -RBM_CoordinateMode=\"Galactic\""
	    ;;
	?) #unrecognized option - show help
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

if [ "$useTestPosition" == "true" ]; then
    options="$options $positionFlags"
fi

# could clean up 
options="$options $exclusionListFlag"

if [ ! $name ]; then
    name=${subDir} #${spectrum}${mode}
fi

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

# set spectrum stuff
if [ "$spectrum" == "soft" ]; then
    RingSize=.17
    SearchWindowSqCut=.03
    pyCuts=soft
elif [ "$spectrum" == "medium" ]; then
    RingSize=.1
    SearchWindowSqCut=.01
    pyCuts=med
elif [ "$spectrum" == "hard" ]; then
    RingSize=.1
    SearchWindowSqCut=.01
    pyCuts=hard
elif [ "$spectrum" == "loose" ]; then
    RingSize=.17
    SearchWindowSqCut=.03
    pyCuts=loose
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


if [ "$runMode" != print ]; then
    
    if [ "$backupPrompt" == "true" ]; then
	echo "backup these files and continue? type 'Y' to continue"
	read response
	if [ $response == 'Y' ]; then
	    test ! -f $logFile || mv $logFile $backupDir
	    test ! -f $outputFile || mv $outputFile $backupDir
	fi
    fi # check file already exists
    
    if [ ! $runFile ]; then 

	### set command to be run or printed ###
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
fi # if runMode is not print only 

test -n $runFile || ( echo "runFile variable empty!" ; exit 1 ) 
#test -f $runFile || ( echo "$runFile doesn't exist, exiting!" && exit 2 ) 
if [ ! -f $runFile ]; then
    echo -e "$runFile doesn't exist, exiting!\n"
    exit 2
fi

cmd="${VEGAS}/bin/vaStage6 -S6A_ConfigDir=${outputDir} -S6A_OutputFileName=stage6_${name}_${sourceName} ${cutsFlag} $options $readFlag -S6A_RingSize=${RingSize} -RBM_SearchWindowSqCut=$SearchWindowSqCut $runFile " #
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
echo "$ROOTSYS"

$cmd
echo "$cmd" 

test \$? -ne 0 && test -f $logFile && mv $logFile $VEGASWORK/rejected 
test -f todayresult && mv todayresult $VEGASWORK/log/

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
