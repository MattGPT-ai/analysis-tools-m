#!/bin/bash

workDir=$BDT
logDir=$BDT/log/ # directory where log of submitted jobs will be written
CONFIGFILE=$HOME/config/BDT_stage6config.txt
# S6A_ReadFromStage5Combined 1 S6A_Spectrum 1 S6A_Batch 1 S6A_ExcludeSource 1 S6A_ExcludeStars 1 S6A_RingSize .1 RBM_SearchWindowSqCut .01

stage5dir=$BDT/processed
subDir=optimize
loggenBase=$HOME/runlists/BDT_optimize
RUNLISTBASE=$HOME/work/optimize
CONFIGDIR=$BDT/config/
SUBMITLOG=$logDir/optimizeLog.txt


pyCuts=med
extension=.stage5.root
runMode=print
overwrite=false

args=`getopt qrl:u:s:ot:pe: $*` 
set -- $args

for i; do                      # loop through options
    case "$i" in 
        -q) runMode="qsub" ; shift ;;
        -r) runMode="shell" ; shift ;;
	-l) PARAMETERAMIN=$2 ; shift ; shift ;;
	-u) PARAMETERAMAX=$2 ; shift ; shift ;;
	-t) PARAMETERASTEP=$2 ; shift ; shift ;;
	-s) subDir=$2 ; shift ; shift ;;
	-o) overwrite="true" ; shift ;;
	-p) priority=$2 ; shift ; shift ;;
	-e) source $2 ; shift ; shift ;; #environment
	--) shift; break ;;
    esac # end case $i in options
done # loop over command line arguments 


# take in zenith angles and energy bins as arguments to allow for greater automation
if [ $2 ]; then
    zenith=$1 # 10 20 30 40 
    energyBin=$2 # 1 2 3 4 
else
    echo "Must specify zenith angle and energy bin!"
    echo "optimize_BDT_cuts.sh \"zenith1 zenith2 ...\" \"energyBin1 energyBin2 ...\" "
    exit 1
fi

JOBS=0

#DATADIR=/veritas/userspace2/mbuchove/BDT/optimize_Z${zenith}
#RUNLISTDIR=$HOME/runlists/
#RUNLISTDIR=$BDT/runlists/
#RUNLISTBASE=$RUNLISTDIR/BDT_stage6_extra
#RUNLISTBASE=$RUNLISTDIR/BDT_stage6 # need to use a different runlist for each energy bin
#CUTSDIR=$HOME/cuts/

#^for z in $zeniths; do
#^for e in $energies; do
#^loopScores $z $e 
#^done # loop over energies
#^done # loop over zeniths 
#^loopScores() { # zenith energyBin
#^} # loopScores

case "$zenith" in
    10) zenithB=20 ;;
    20) zenithB=30 ;;
    30) zenithB=40 ;;
    40) zenithB=10 ;;
    *)  echo -e "$zenith not processed!"
#	continue
	;;
esac # cases for zenith

case "$energyBin" in
    1) EnergyLower=0 ; EnergyUpper=320 ;;
    2) EnergyLower=320 ; EnergyUpper=560 ;;
    3) EnergyLower=500 ; EnergyUpper=1120 ;;
    4) EnergyLower=1000 ; EnergyUpper=30000 ;;
    *) echo -e "energy bin $energyBin not processed!" ;; #continue ;
esac # cases for energy bin

if [ "$zenithB" == "40" -a "$energyBin" == "4" ]; then 
    zenithB=20
fi


#CUTSFILE=$CUTSDIR/E${energyBin}_cuts.txt
ROOTOUTDIR=$CONFIGDIR/${subDir}/Z${zenith}_E${energyBin} # directory where root files are written
logDirLower=$logDir/${subDir}/Z${zenith}_E${energyBin}
for dir in $ROOTOUTDIR $logDirLower; do 
    if [ ! -d $dir ]; then
	echo "Creating directory $dir .."
	mkdir -p $dir
    fi
done

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
#RUNLIST=${RUNLISTBASE}_Z${zenith}_E${energyBin}.txt 
runFile=${RUNLISTBASE}_${subDir}_Z${zenith}.txt
if [ ! -f $runFile ]; then 
    tempRunlist=`mktemp` || exit 1 # intermediate runlist file 
    while read -r line; do 
	set -- $line
	echo "$stage5dir/${subDir}/${2}${extension}" >> $tempRunlist
    done < $loggenFile
    python $BDT/macros/s6RunlistGen.py --EAmatch --EAdir $TABLEDIR --cuts $pyCuts $tempRunlist $runFile
    #$HOME/bin/generateRunlist.sh -s $spectrum -d $stage5dir -e $extension $runlistDir/${sourceName}_loggen.txt > $runFile
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

	    cmd="`which vaStage6` -S6A_ConfigDir=${ROOTOUTDIR} -S6A_OutputFileName=${OUTFILEBASE}.root -${PARAMETERANAME}=${PARAMETERAFLOAT} -${PARAMETERBNAME}=${PARAMETERBFLOAT} -S6A_ReadFromStage5Combined=1 -S6A_Batch=1 -S6A_ExcludeSource=1 -S6A_ExcludeStars=1 -OverrideEACheck=1 -S6A_RingSize=0.1 -RBM_SearchWindowSqCut=0.01 -EnergyLower=$EnergyLower -EnergyUpper=$EnergyUpper ${runFile}"
	    #cmd="`which vaStage6` -S6A_ConfigDir=${ROOTOUTDIR} -S6A_OutputFileName=${OUTFILEBASE}.root -S6A_ReadFromStage5Combined=1 -S6A_Batch=1 -S6A_ExcludeSource=1 -S6A_ExcludeStars=1 -OverrideEACheck=1 ${RUNLIST}"
	    #-S6A_Spectrum=1 -cuts=${CUTSFILE} -S6A_OutputFileName=${OUTFILEBASE}.S6 
	    #cmd="vaStage6 -S6A_ConfigDir=${CONFIGDIR} -${PARAMETERANAME}=${PARAMETERAFLOAT} -S6A_OutputFileName=${OUTFILEBASE}.S6 -cuts=${CUTSFILE} -config=${CONFIGFILE} ${RUNLIST}"    
	    
	    
	    echo "JOB ${PARAMETERANAME}=${PARAMETERAFLOAT}  ${PARAMETERBNAME}=${PARAMETERBFLOAT}"
	    echo "$cmd"
	    #cat $CONFIGFILE >> ${logDir}/${OUTFILEBASE}.txt       	
	    
	    if [ "$runMode" == "qsub" ]; then
		echo "$cmd" >> $SUBMITLOG
#		touch $workDir/queue
		#submit to qsub
		#    echo "#!/bin/sh -f " > $QSUBFILE
		qsub <<EOF
    #PBS -j oe
    #PBS -o $logDirLower/${OUTFILEBASE}.txt
    #PBS -l nodes=1,mem=2gb
    #PBS -N ${subDir}_${zenith}_${energyBin}_${PARAMETERA}

cat $CUTSFILE
$cmd 
echo "$cmd"
#rm $workDir/queue/${OUTFILEBASE}

EOF
	    elif [ "$runMode" == "shell" ]; then
		$cmd | tee $logDirLower/${OUTFILEBASE}.txt
		echo "$cmd" | tee $logDirLower/${OUTFILEBASE}.txt
	    fi # runmode
	fi # if previous file doesn't exist or overwrite set to true 
	
	let PARAMETERB=${PARAMETERB}+${PARAMETERBSTEP}
	
    done # while loop over parameter B

    let PARAMETERA=${PARAMETERA}+${PARAMETERASTEP} 

done # while loop over parameter A

echo --------------------------------------------------------------------------
if [ "$runMode" != "print" ]; then
    echo ${JOBS} JOBS SUBMITTED. Have a lot of fun!
fi

exit 0 # success
