#!/bin/bash

### you must source file that exports the variables:
# sourceName baseDir options spectrum
# use environment option first if you want to override other variables

#environment=$HOME/environments/bashM87.sh

#run specific stuff
BDTcutsFile=$HOME/cuts/BDT_5-16_cuts.txt
#subDir=mediumBDT_5-16
#name=mediumBDT_5-16
#straight cuts file $HOME/cuts/stage5_${spectrum}_cuts.txt

#common defaults
options="-S6A_Spectrum=0 -S6A_Batch=1 -OverrideEACheck=1 -S6A_ExcludeSource=1"
readFlag="-S6A_ReadFromStage4=1"
extension=".stage4.root"
RingSize=.1
SearchWindowSqCut=.01

backupPrompt=false
useTestPosition=false
trashDir=$HOME/.trash

run=true

### process options
while getopts s:d:n:Bc:l:e:r5 FLAG; do
    case $FLAG in
	e)
	    environment=$OPTARG
	    source $environment
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
	r) run=false
	    ;;
	5) extension=".stage5.root"
	   readFlag="-S6A_ReadFromStage5Combined=1" # might change this 
	   ;;
	?) #unrecognized option - show help
	    echo -e "Option -${BOLD}$OPTARG${NORM} not allowed."
	    ;;
    esac # option cases
done # getopts loop
shift $((OPTIND-1))  #This tells getopts to move on to the next argument.

### prepare variables and directories after options are read in

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
if [ "useExclusionList" != "false" ] && [ $exclusionListFlag ]; then
    options="$options $exclusionListFlag"
fi

if [ ! $name ]; then
    name=${subDir} #${spectrum}${mode}
fi

 # had separate variable for baseDir
logDir=$VEGASWORK/log/stage6/
backupDir=$VEGASWORK/backup/
for dir in $logDir $backupDir; do
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

if [ ! $cutsFile ]; then
    if [ "$mode" == "BDT" ]; then
	cutsFile=$BDTcutsFile
    else
	cutsFile=$HOME/cuts/stage5_${spectrum}_cuts.txt
    fi
    cutsFlag="-cuts=${cutsFile}"
fi

# check to see if root file or logfile already exists, and back up
logFile=$logDir/stage6_${name}_${sourceName}.txt
outputFile=$VEGASWORK/config/stage6_${name}_${sourceName}s6.root
for file in $logFile $outputFile; do
    if [ -f $file ]; then
	echo "$file already exists! "
	backupPrompt=true
    fi
done
#if [ "$backupPrompt" == "true" ]; then
#    echo "backup these files and continue? type 'Y' to continue"
#    read response
#    if [ $response == 'Y' ]; then
	test ! -f $logFile || mv $logFile $backupDir
	test ! -f $outputFile || mv $outputFile $backupDir
#    fi
#fi

echo "extension: $extension" 
### create runfile using python script if it doesn't exist ###
runFile=$HOME/work/${sourceName}_${name}_runlist.txt
if [ "true" == "true" ]; then # [ ! -f $runFile ] || 
    tempRunlist=`mktemp` || exit 1 # intermediate runlist file 
    while read -r line; do 
	set -- $line
	echo "$finalRootDir/${2}${extension}" >> $tempRunlist
    done < $loggenFile
    echo $loggenFile
    python $BDT/macros/s6RunlistGen.py --EAmatch --EAdir $TABLEDIR --cuts $pyCuts $tempRunlist $runFile # &>> $logFile
    #$HOME/bin/generateRunlist.sh -s $spectrum -d $finalRootDir -e $extension $runlistDir/${sourceName}_loggen.txt > $runFile
else
    echo "$runFile exists, using this!"
fi # runfile doesn't exist so must be created

### set and run the command ### 
cmd="${VEGAS}/bin/vaStage6 -S6A_ConfigDir=${VEGASWORK}/config/ -S6A_OutputFileName=stage6_${name}_${sourceName} ${cutsFlag} $options $readFlag -S6A_RingSize=${RingSize} -RBM_SearchWindowSqCut=$SearchWindowSqCut $runFile " # &>> $logFile $positionFlags

cat $cutsFile &> $logFile
date &>> $logFile
hostname &>> $logFile
echo "$ROOTSYS" &>> $logFile

echo "$cmd"

#if [ "$run" == "true" ]; then
    $cmd &>> $logFile
#fi
EXITCODE=$?

echo "$cmd" &>> $logFile
echo "$loggenFile" &>> $logFile
  
if [ -f todayresult ]; then
    mv todayresult $HOME/log/ #$trashDir
fi

# after running and logging, check for successful run
if [ $EXITCODE -ne 0 ]; then
    echo "rejected!" >> $logFile
    mv $logFile $VEGASWORK/rejected/
    exit 1
fi

exit 0 # Success!
