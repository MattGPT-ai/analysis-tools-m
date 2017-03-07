#!/bin/bash

### you must source file that exports the variables:
# sourceName baseDir options spectrum
# use environment option first if you want to override other variables

bash_args="$0 $@"
scriptName=${0##*/}
scriptDir=${0/\/$scriptName}
common_functions=$scriptDir/common_functions.sh
source $common_functions
source $scriptDir/defaults_source.sh 
#source $scriptDir/../environments/env_Crab.sh 
source $scriptDir/set_params.sh 
runlistGen=$scriptDir/../../resultsExtractor/utilities/s6RunlistGen.py


usage(){
    echo "usage: execute-stage6.sh -e environment.sh /path/to/runlist --box_cuts medium -N runname -m (skymap|spectrum|both) [--submit]"
    echo 'You must either supply a full stage 6 runlist file or a loggen file.'
    echo '-l|-L /path/to/loggen '
    echo 'If supplied with a loggen file the runlist file will be automatically created. Use -L in place of -l to force a rewrite of the runlist file'
    echo 'If giving a loggen file, you should tell the script where the files are, and what stage you are using: '
    echo -e "\t -4 stg4_dir | -5 stg5_dir"

    echo '[-x|--x6 "-S6_AdditionalFlag=value -S6_AdditionalFlag2=value"] '
}
test -z "$1" && ( usage ; exit 1 )

####################
### set defaults ### 
####################
outputDir=results

s6_defaults="-S6A_ExcludeSource=1 -S6A_DrawExclusionRegions=2" 
suppressRBM=0 # run RBM by default 
# mode for adding cuts. auto just does the stage 6 config. full does this and includes the stage 5 cuts as well, useful if you're running from stage 4 
cuts=auto
# by default use stage 5 files 
subDir=stg5_${default_cuts} # for auto-gen of runlist
extension=".stage5.root" 
readFlag="-S6A_ReadFromStage5Combined=1" 
useTestPosition=false 
runMode=print
backupPrompt=false # 
minTels=(1)

#######################
### Process Options ###
#######################
parseCommonOpts "$@"
eval set -- "$args"

# Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
      "--cutmode")    set -- "$@" "-c" ;;
      "--box_cuts")   set -- "$@" "-s" ;; 
#      "-4")           set -- "$@" "-R" ;;
#      "-5")           set -- "$@" "-T" ;;
#      "--subdir")         set -- "$@" "-d" ;;
      "--x6")         set -- "$@" "-x" ;;
      "--minTels")    set -- "$@" "-t" ;;
      "--distCut")    set -- "$@" "-I" ;;
      "--deny")       set -- "$@" "-D" ;; 
#      "--disp")       set -- "$@" "-T" ;; 
      "--mail")       set -- "$@" "-M" ;; 
      *)              set -- "$@" "$arg" ;;
  esac
done 
 # loop over args 
while getopts 4:5:d:l:L:f:s:Sn:N:Bc:C:x:X:oOpt:T:jux:A:m:M:I:D: FLAG; do 
    case $FLAG in
	l)  loggenFile=$OPTARG #overrides loggen file set in environment 
	    overwrite_loggen=false ;; 
	L)  loggenFile=$OPTARG 
	    overwrite_loggen=true ;; 
	c)
	    case $OPTARG in 
		all | auto | none) cuts=$OPTARG;; 
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
	M)  # send mail 
	    mail_recip="$OPTARG" ;; 
	N)  name=$OPTARG ;; 
	B)  # activate BDT mode  
	    mode=BDT
	    readFlag="-S6A_ReadFromStage5Combined=1"
	    extension=".stage5.root"
	    ;;
	t)
	    minTels=$OPTARG ;; 
	#T)  distance=1.38 ;; 
	#F)  noprompt=true ;; 
	d)  subDir=$OPTARG ;; 
	4) 
	    stage=(4)
	    readFlag="-S6A_ReadFromStage4=1"
	    extension=".stage4.root" 
	    subDir=$OPTARG ;;
	5) 
	    stage=(5)
	    extension=".stage5.root" 
	    subDir=$OPTARG ;;
	o)  s6Opts="$s6Opts -OverrideEACheck=1" ;; 
	O)  s6Opts="$s6Opts -S6A_ObsMode=On/Off" ;; 
	f) # runlist file 
	    runFile=$OPTARG ;; 
	p)
	    useTestPosition=true
	    ;; # allows you to use the test position supplied in environment file 
	A)  s6Opts="$s6Opts -S6A_LoadAcceptance=1 -S6A_AcceptanceLookup=$OPTARG"
	    test -f "$OPTARG" || echo "Acceptance map $OPTARG does not exist!" ;; 
	j)  s6Opts="$s6Opts -RBM_CoordinateMode=\"J2000"\" ;; 
	u)  s6Opts="$s6Opts -S6A_UpperLimit=1" ;; 
	I)  ImpactDistanceUpper=($OPTARG) ;; 
	D)  TelCombosToDeny=$OPTARG ;; 
	x)  
	    customFlags6="$OPTARG" ;; 
	?) # unrecognized option - show help
	    echo -e "${BOLD}Option -${FLAG} -${OPTARG} not allowed.${NORM} "
	    ;;
    esac # option cases
done # getopts loop
shift $((OPTIND-1))  #This tells getopts to move on to the next argument.    


### prepare variables and directories after options are read in
#for env in $environment; do  source $env || exit 1; done
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

denyFlag="" 
for combo in $TelCombosToDeny $autoTelCombosToDeny ; do 
    test -z "$denyFlag" && denyFlag="-TelCombosToDeny=${combo}" ||  denyFlag="${denyFlag},${combo}"
done 


# make directories 
logDir=$workDir/log/stage6
backupDir=$workDir/backup
outputDir=$workDir/$outputDir
runlistDir=$workDir/runlists/auto

checkForDirs $runMode $logDir $backupDir $outputDir $runlistDir # $workDir/report 

# set cuts based on spectrum 
setCuts $box_cuts 
setTableNames
if [ "$cuts" == auto ] || [ "$cuts" == all ]; then
    cutsFlag="-S6A_RingSize=${S6A_RingSize} -RBM_SearchWindowSqCut=$RBM_SearchWindowSqCut"
    if [ "$cuts" == all ]; then
	cutsFlag="$cutsFlag $stage5cuts_auto"
    fi
fi

# binningFile, configFile, and cutsFile not yet set 
for file in $exclusionList $binningFile $configFile $cutsFile; do 
    test -f $file || echoErr "File $file does not exist!!"
done # check config files exist 

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

## generate the runlist automatically and store in $runlistDir 
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

	runFile=$runlistDir/${name}_runlist.txt
	### create runfile using python script if it doesn't exist ###
	echo "extension: $extension" 
	if [ ! -f "$runFile" ] || [ "$overwrite_loggen" == true ]; then 
	    test -f "$loggenFile" || ( echoErr "Loggen file $loggenFile does not exist!" ; exit 1 )
	    tempRunlist=`mktemp` || exit 1 # intermediate runlist file 
	    while read -r line; do 
		set -- $line
		echo "$finalRootDir/${2}${extension}" >> $tempRunlist
	    done < $loggenFile

	    # pass the arguments to python script to generate runlist 
	    # many arguments passed are set in environment / defaults 
	    echo "python $runlistGen --standard --runfile-dir $finalRootDir --stage $stage --obs-tel --EAmatch --EAdir $eaDir --zeniths $zenlabel --Offset $offlabel --distance $DistanceUpper --distCut $ImpactDistanceUpper --minTels $minTels --box_cuts $box_cuts --VegasV $ltVegas --SimModel $model --SimSource $simulation $loggenFile $runFile "
	    python $runlistGen --standard --runfile-dir $finalRootDir --stage $stage --obs-tel --EAmatch --EAdir $eaDir --zeniths $zenlabel --Offset $offlabel --distance $DistanceUpper --distCut $ImpactDistanceUpper --minTels $minTels --box_cuts $box_cuts --VegasV $ltVegas --SimModel $model --SimSource $simulation --ea_ext "$ea_ext" $loggenFile $runFile 
#$tempRunlist
	    # could call bash process to use exact same naming function using bash variables directly
	    #if bashEAflag
	    #$runlistGen --minimal
	    #for configuration
	    #setCuts ; setTableNames
	    #replace generic names with full names

	fi # runfile doesn't exist so must be created
    fi # if runFile isn't already specified  
    
    if [ ! -s "$runFile" ]; then
	rm -fv $runFile
	echoErr "Runfile $runFile doesn't exist or is empty, exiting!"
	exit 2 
    fi

fi # if runMode is not print only 


[ $runFile ] || runFile=$runlistDir/${name}_runlist.txt

cmd="vaStage6 -S6A_ConfigDir=${outputDir} -S6A_OutputFileName=${name} $readFlag $cutsFlag $s6_defaults $denyFlag $s6Opts $customFlags6 $runFile " #
echo "$cmd"

submitHeader=$(createBatchHeader -m 2 -o $logFile -N s6_${name} -t 12 )

if [ "$runMode" != print ]; then

    $runMode <<EOF
$submitHeader

for env in $environment; do  source \$env; done

source $common_functions 
use_docker=false
logInit
echo $bash_args

$docker_load 
$docker_cmd $cmd 

exitCode=\$?

[ $exclusionList ] && cat $exclusionList
[ $cutsFile ] && cat $cutsFile


test -f todayresult && mv todayresult $workDir/log/

echo \$exitCode
if [ "\$exitCode" -eq 0 ]; then 
    logStatus $logFile 
    #rsync -v $outputFile $logFile $workDir/report/
else
    for suffix in _s6.root _spectrumPlots.ps _StereoPlots.ps _spectrum.png ; do 
        f=$outputDir/${name}${suffix} 
        test -f $f && rm -v $f 
    done # loop over files for cleanup                                          
    test -f "$logFile" && mv $logFile $workDir/failed_jobs/
fi # run does not exit with success                                                   

if [ "$mail_recip" ]; then 
    mailto -s "stage 6 job completed" <<EOf
        stage 6 job $name completed!
EOf
fi

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
