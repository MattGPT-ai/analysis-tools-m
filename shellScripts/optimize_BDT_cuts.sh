#!/bin/bash 

workDir=$BDT
logDir=$BDT/log # directory where log of submitted jobs will be written
CONFIGFILE=$HOME/config/BDT_stage6config.txt
# S6A_ReadFromStage5Combined 1 S6A_Spectrum 1 S6A_Batch 1 S6A_ExcludeSource 1 S6A_ExcludeStars 1 S6A_RingSize .1 RBM_SearchWindowSqCut .01 

stage5dir=$BDT/processed
subDir=optimize
#loggenBase=$HOME/runlists/BDT_optimize
#RUNLISTBASE=$HOME/work/optimize
loggenBase=$BDT/runlists
RUNLISTBASE=$BDT/runlists
CONFIGDIR=$BDT/config
SUBMITLOG=$logDir/optimizeLog.txt

pyCuts=med
extension=.stage5.root
runMode=print
overwrite=false

#args=`getopt qr:l:u:s:ot:pe: $*` 
args=`getopt -o qr:os:pe:f: -l runFile:,EA:,min:,max:,step: -n 'optimize_BDT_cuts.sh' -- "$@"` 
#set -- ${args//\'/} 
eval set -- $args 
for i; do                 # loop through options 
    case "$i" in 
        -q) runMode=qsub ; shift ;;
        -r) runMode="$2" ; shift 2 ;;
	--min) PARAMETERAMIN=$2 ; shift ; shift ;;
	--max) PARAMETERAMAX=$2 ; shift 2 ;;
	--step) PARAMETERASTEP=$2 ; shift 2 ;;
	-s) subDir="$2" ; shift 2 ;;
	-f|--runFile) 
	    runFile=$2 
	    shift 2 ;; 
	--EA)
	    eaFile=$2
	    shift 2 ;; 
	-o) overwrite="true" ; shift ;;
	-p) priority=$2 ; shift 2 ;;
	-e) source $2 ; shift ; shift ;; #environment
	--) shift; break ;;
    esac # end case $i in options
done # loop over command line arguments 

# take in zenith angles and energy bins as arguments to allow for greater automation
if [ $1 ]; then
    zenith=$1 
else
    echo "Must specify zenith angle!"
    echo "optimize_BDT_cuts.sh \"zenith1 zenith2...\" "
    exit 1
fi

test -n "$2" && eBins="$2"


JOBS=(0)

arrayLow=( 0 320 500 1000 )
arrayHigh=( 320 560 1120 30000 )
case $zenith in 
    10) 
	zenithB=20
	simZ=00 ;; 
    20)
	zenithB=30 ;;
    30) zenithB=20 ;; # to avoid problem with z40 binning 
    40) 
	arrayLow=( 0 500 1000 )
	arrayHigh=( 560 1120 30000 ) 
	zenithB=10
	;; 
    55|60|65) 
	zenithB=10 # will this work? 
        arrayLow=( 0 ) 
	arrayHigh=( 100000 ) 
	#arrayLow=( 0 4000 10000 )
        #arrayHigh=( 4000 10000 100000 )
	;;
esac # zenith cases

#numBinsE=${#arrayLow[@]}
#eBin=(0) # the energy bin index 

for energyBin in $eBins; do #while (( eBin < numBinsE )); do 
    
    eBin=$((energyBin-1))
    eLow=${arrayLow[eBin]} # EnergyLower
    eHigh=${arrayHigh[eBin]} # EnergyUpper 
    
    if [ "$zenithB" == "40" -a "$energyBin" == "4" ]; then 
	zenithB=10
    fi
    
    #CUTSFILE=$CUTSDIR/E${energyBin}_cuts.txt
    ROOTOUTDIR=$CONFIGDIR/${subDir}/Z${zenith}_E${energyBin} # directory where root files are written
    logDirLower=$logDir/${subDir}/Z${zenith}_E${energyBin}
    for dir in $ROOTOUTDIR $logDirLower; do 
	if [ ! -d $dir ]; then
	    echo "Must create directory $dir .."
	    test $runMode != print && mkdir -p $dir
	fi
    done # 

    #X-Axis
    PARAMETERANAME=Z${zenith}E${energyBin}BDTScoreLower
    if [ ! $PARAMETERAMIN ]; then
	PARAMETERAMIN=-100  #20
    fi
    if [ ! $PARAMETERAMAX ]; then 
	PARAMETERAMAX=100 #90
    fi
    if [ ! $PARAMETERASTEP ]; then
	PARAMETERASTEP=10 #5
    fi
    #parameters here are 100 times actual parameter, must be converted into floats later

    #Y-Axis
    PARAMETERBNAME=Z${zenithB}E${energyBin}BDTScoreLower
    PARAMETERBMIN=-100 #900
    PARAMETERBMAX=-100 #2000
    PARAMETERBSTEP=1

    PARAMETERA=${PARAMETERAMIN}
    #let PARAMETERAMAX=${PARAMETERAMAX}+1

    ### create runfile using python script if it doesn't exist ###
    loggenFile=${loggenBase}_Z${zenith}.txt
    test -n "$runFile" || runFile=${RUNLISTBASE}_${subDir}_Z${zenith}.txt
    if [ ! -f $runFile ] && [ "$runMode" != print ]; then 
	tempRunlist=`mktemp` || exit 1 # intermediate runlist file 
	while read -r line; do 
	    set -- $line
	    echo "$stage5dir/${subDir}/${2}${extension}" >> $tempRunlist
	done < $loggenFile
	python $VSCRIPTS/s6RunlistGen.py --EAmatch --EAdir $TABLEDIR --cuts $pyCuts $tempRunlist $runFile
    else
	echo "$runFile exists, using this!"
    fi # runfile doesn't exist so must be created

    while [ "${PARAMETERA}" -le "${PARAMETERAMAX}" ]
    do
	
	PARAMETERB=${PARAMETERBMIN}  #times 100
	#let PARAMETERBMAX=${PARAMETERBMAX}+1
	
	while [ "${PARAMETERB}" -le "${PARAMETERBMAX}" ]
	do
	    
	    let JOBS=${JOBS}+1
	    PARAMETERAFLOAT=$(echo "scale=3; ${PARAMETERA}/100" | bc -l)
	    PARAMETERBFLOAT=$(echo "scale=3; ${PARAMETERB}/100" | bc -l)
	    
	    OUTFILEBASE=Stage6_${PARAMETERANAME}${PARAMETERA}_${PARAMETERBNAME}${PARAMETERB}
	    
	    if [ ! -f $ROOTOUTDIR/${OUTFILEBASE}s6.root -o $overwrite == "true" ]; then

		cmd="`which vaStage6` -S6A_ConfigDir=${ROOTOUTDIR} -S6A_OutputFileName=${OUTFILEBASE}.root -${PARAMETERANAME}=${PARAMETERAFLOAT} -${PARAMETERBNAME}=${PARAMETERBFLOAT} -S6A_ReadFromStage5Combined=1 -S6A_Batch=1 -S6A_ExcludeSource=1 -S6A_ExcludeStars=1 -OverrideEACheck=1 -S6A_RingSize=0.1 -RBM_SearchWindowSqCut=0.01 -EnergyLower=$eLow -EnergyUpper=$eHigh ${runFile}"

		test -n "$eaFile" && cmd="$cmd -S6A_LookupFileName=${eaFile}" 

		echo "JOB ${PARAMETERANAME}=${PARAMETERAFLOAT}  ${PARAMETERBNAME}=${PARAMETERBFLOAT}"
		echo "$cmd"
		
		if [ "$runMode" != print ]; then
		    queueFile=$workDir/queue/$OUTFILEBASE
		    touch $queueFile
		    logFile=$logDirLower/${OUTFILEBASE}.txt

		    $runMode <<EOF
#!/bin/bash
#PBS -j oe
#PBS -o $logFile
#PBS -l nodes=1,mem=2gb
#PBS -N ${subDir}_${zenith}_${energyBin}_${PARAMETERA}

date
root-config --version 
echo $VEGAS

$cmd 
exitCode=$?
echo "$cmd"
cat $CONFIGFILE

rm $queueFile
if [ \$exitCode -ne 0 ]; then 
    mv $logFile $BDT/rejected/
    exit 1
else
    cp $logFile $BDT/completed/
    exit 0 
fi

EOF
		fi # runmode not print 
	    fi # if previous file doesn't exist or overwrite set to true 
	    
	    let PARAMETERB=${PARAMETERB}+${PARAMETERBSTEP}
	    
	done # while loop over parameter B

	let PARAMETERA=${PARAMETERA}+${PARAMETERASTEP} 

    done # while loop over parameter A
done # loop over energy bins 

if [ "$runMode" != "print" ]; then
    echo "\n--------------------------------------------------------------------------"
    echo ${JOBS} JOBS SUBMITTED. Have a lot of fun!
fi

exit 0 # success
