#!/bin/bash

### you must source file that exports the variables:
# sourceName baseDir options spectrum
# use environment option first if you want to override other variables

scriptName=${0##*/}
scriptDir=${0/\/$scriptName}
source $scriptDir/defaults_source.sh
common_functions=$scriptDir/common_functions.sh
source $common_functions
source $scriptDir/defaults_source.sh 
source $scriptDir/../environments/env_Crab.sh 
source $scriptDir/set_params.sh 
runlistGen=$scriptDir/../../resultsExtractor/utilities/s6RunlistGen.py


usage(){
    echo "usage: execute-stage6.sh -e environment.sh -f /path/to/runlist --box_cuts medium -n runname [--submit]"
    echo '[-x|--x6 "-S6_AdditionalFlag=value -S6_AdditionalFlag2=value"] '
}
test -z "$1" && ( usage ; exit 1 )

####################
### set defaults ### 
####################
outputDir=results
#s6Opts="-S6A_ExcludeSource=1 -S6A_DrawExclusionRegions=2" 
suppressRBM=1
# mode for adding cuts. auto just does the stage 6 config. full does this and includes the stage 5 cuts as well, useful if you're running from stage 4 
cuts=auto
# by default use stage 5 files 
subDir=stg5 # for auto-gen of runlist
extension=".stage5.root"
readFlag="-S6A_ReadFromStage5Combined=1" 
backupPrompt=false
useTestPosition=false 
runMode=print


#######################
### Process Options ###
#######################
# Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
      "--submit")     set -- "$@" "-q" ;;
      "--cutmode")    set -- "$@" "-c" ;;
      "--box_cuts")   set -- "$@" "-s" ;; 
      "--x6")         set -- "$@" "-x" ;;
      *)              set -- "$@" "$arg" ;;
  esac
done 
 # loop over args 
while getopts d:l:f:s:Sn:NBc:C:x:X:e:r:qQ4oOtjux:A:m: FLAG; do 
    case $FLAG in
	e)  environment=$OPTARG ;;
	l)  loggenFile=$OPTARG ;; #overrides loggen file set in environment 
	c)
	    case $OPTARG in 
		all | auto) cuts=$OPTARG;; 
		*) 
		    cuts=file
		    cutsFile=$OPTARG
		    cutsFlag="-cuts=$cutsFile" 
		    ;; 
	    esac ;;
	C)  configFile=$OPTARG
	    s6Opts="$s6Opts -config=$configFile" ;; 
	X)  exclusionList=$OPTARG ;; 
	s)  box_cuts=$OPTARG ;; 
	S) # stereo 
	    readFlag="" ;; 
	m) # mode to run
	    case $OPTARG in
		spectrum)
		    s6Opts="$s6Opts -S6A_Spectrum=1" ; suppressRBM=1 ;; 
		skymap) 
		    suppressRBM=0 ;; 
		both)
		    s6Opts="$s6Opts -S6A_Spectrum=1" ; suppressRBM=0 ;; 
	    esac ;; 
	d)  subDir=$OPTARG ;; 
	n)  name=$OPTARG ;; 
	B)  # activate BDT mode  
	    mode=BDT
	    readFlag="-S6A_ReadFromStage5Combined=1"
	    extension=".stage5.root"
	    ;;
	4) 
	    readFlag="-S6A_ReadFromStage4=1"
	    extension=".stage4.root" ;; 
	o)  s6Opts="$s6Opts -OverrideEACheck=1" ;; 
	O)  s6Opts="$s6Opts -S6A_ObsMode=On/Off" ;; 
	f) # runlist file 
	    runFile=$OPTARG ;; 
	r) # command used to run the generated script, e.g. bash, sbatch, condor, etc. 
	    runMode=$OPTARG ;; 
	q|Q)
	    runMode=sbatch
	    s6Opts="$s6Opts -S6A_Batch=1"
	    [[ $FLAG == 'q' ]] && partition=shared
	    [[ $FLAG == 'Q' ]] && partition=regular
	    ;;
	
	N) # no-docker 
	    docker_cmd=""
	    ;; 
	t)
	    useTestPosition=true
	    ;; # allows you to use the test position supplied in environment file 
	A)  s6Opts="$s6Opts -S6A_LoadAcceptance=1 -S6A_AcceptanceLookup=$OPTARG"
	    test -f "$OPTARG" || echo "Acceptance map $OPTARG does not exist!" ;; 
	j)  s6Opts="$s6Opts -RBM_CoordinateMode=\"J2000"\" ;; 
	u)  s6Opts="$s6Opts -S6A_UpperLimit=1" ;; 
	x)  
	    customFlags6="$OPTARG" ;; 
	?) # unrecognized option - show help
	    echo -e "${BOLD}Option -${FLAG} -${OPTARG} not allowed.${NORM} "
	    ;;
    esac # option cases
done # getopts loop
shift $((OPTIND-1))  #This tells getopts to move on to the next argument.    


### prepare variables and directories after options are read in
for env in $environment; do  source $env || exit 1; done
test -d "$workDir" || ( '$workDir must be set and exist! exiting..' ; exit 1 ) 


# process variables into command line args for vaStage6
finalRootDir=$workDir/processed/${subDir}
[ "$docker_cmd" == shifter ] && docker_cmd="$docker_cmd $volumeDirective"
if [ -z "$loggenFile" ] && [ -z "$runFile" ]; then 
    echo "must specify either a run file or a loggen file!"
    exit 1
fi
s6Opts="$s6Opts -S6A_SuppressRBM=${suppressRBM}"
[ ! $name ] && name=${sourceName}_${ltVegas}_${subDir}_${box_cuts}_${mode} 
[ "$binfile_relpath" ] && s6Opts="$s6Opts -SP_BinningFilename=$scriptDir/$binfile_relpath"
[ "$useTestPosition" == "true" ] && s6Opts="$s6Opts $positionFlags"
if [[ "$s6Opts" =~ "S6A_UpperLimit" ]]; then
    if [ $UL_Gamma1 ]; then s6Opts="-UL_Gamma1=$UL_Gamma1 $s6Opts"; fi
    if [ $UL_Gamma2 ]; then s6Opts="-UL_Gamma2=$UL_Gamma2 $s6Opts"; fi
    if [ $UL_Gamma3 ]; then s6Opts="-UL_Gamma3=$UL_Gamma3 $s6Opts"; fi
fi
if [ $exclusionList ] && [ "$exclusionList" != none ]; then 
    s6Opts="$s6Opts -S6A_UserDefinedExclusionList=$exclusionList"
fi # could clean up 

# make directories 
logDir=$workDir/log/stage6
backupDir=$workDir/backup
outputDir=$workDir/$outputDir

checkForDirs $runMode $logDir $backupDir $outputDir $workDir/report 

# set cuts based on spectrum 
setCuts $box_cuts 
if [ "$cuts" == auto ] || [ "$cuts" == all ]; then
    cutsFlag="-S6A_RingSize=${S6A_RingSize} -RBM_SearchWindowSqCut=$RBM_SearchWindowSqCut"
    if [ "$cuts" == all ]; then
	cutsFlag="$cutsFlag -MeanScaledLengthLower=${MeanScaledLengthLower} -MeanScaledLengthUpper=${MeanScaledLengthUpper} -MeanScaledWidthLower=${MeanScaledWidthLower} -MeanScaledWidthUpper=${MeanScaledWidthUpper} -MaxHeightLower=${MaxHeightLower}"
    fi
fi

# check to see if root file or logfile already exists, and back up
logFile=$logDir/${name}_stage6.txt
test "$runMode" != print  && logOption="| tee $logFile"
outputFile=$workDir/results/${name}_s6.root
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
	if [ "$response" == 'Y' ]; then
	    test ! -f $logFile || mv -v $logFile $backupDir/
	    test ! -f $outputFile || mv -v $outputFile $backupDir/
	else
	    exit  
	fi
    fi # check file already exists
    
    if [ ! $runFile ]; then 

	runFile=$HOME/work/${name}_runlist.txt
	### create runfile using python script if it doesn't exist ###
	echo "extension: $extension" 
	if [ ! -f $runFile ]; then 
	    tempRunlist=`mktemp` || exit 1 # intermediate runlist file 
	    while read -r line; do 
		set -- $line
		echo "$finalRootDir/${2}${extension}" >> $tempRunlist
	    done < $loggenFile

	    python $runlistGen --standard --EAmatch --EAdir $eaDir --box_cuts $pyCuts $tempRunlist $runFile 
	fi # runfile doesn't exist so must be created
    fi # if runFile isn't already specified  
    
    if [ ! -f $runFile ]; then
	echo -e "$runFile doesn't exist, exiting!\n"
	exit 2
    fi

fi # if runMode is not print only 

cmd="vaStage6 -S6A_ConfigDir=${outputDir} -S6A_OutputFileName=${name} $readFlag $cutsFlag $s6Opts $customFlags6 $runFile " #
echo "$cmd"

if [ "$runMode" != print ]; then

    $runMode <<EOF
$sbatchHeader
#SBATCH --mem=2gb 
#SBATCH -o $logFile 
#SBATCH -J s6_${name} 
#SBATCH --time=12:00:00 

for env in $environment; do  source \$env; done

source $common_functions 
logInit


$docker_load 
$docker_cmd $cmd 

exitCode=\$?

[ $exclusionList ] && cat $exclusionList
[ $cutsFile ] && cat $cutsFile


test -f todayresult && mv todayresult $workDir/log/

echo \$exitCode
if [ "\$exitCode" -eq 0 ]; then 
    logStatus $logFile 
    rsync -v $outputFile $logFile $workDir/report/
else
    for suffix in _s6.root _spectrumPlots.ps _StereoPlots.ps _spectrum.png ; do 
        f=$outputDir/${name}${suffix} 
        test -f $f && rm -v $f 
    done # loop over files for cleanup                                          
    test -f "$logFile" && mv $logFile $workDir/failed_jobs/
fi # run does not exit with success                                                   

echo "$cmd" 
# could send confirmation message 
exit \$exitCode 

EOF

    EXITCODE=$?
fi # runModes 

# after running and logging, check for successful run
if [ "$runMode" != print ] && [ $EXITCODE -ne 0 ]; then
    echo "FAILED!"

    [ -f $logFile ] && mv $logFile $workDir/failed_jobs/ 
    exit 1
fi

exit 0 # great uccess!
