# sets box cuts and configurations based on array and spectrum 
# atmosphere currently not accounted for 
# also sets the appropriate lookup table names 

setEpoch() { # date(YYYYMMDD) 

    local date=$1

    # try to read from database 
    local runMonth=$(( (date % 10000 - date % 100) / 100 ))
    # used to be runMonth > 4, but changed to agree with s6RunlistGen.py 
    if (( runMonth > 3 && runMonth < 11 )); then
	atm=22
    else
	atm=21
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


setCuts() { # box_cuts array atm 
# each argument should only be single valued 
test -n "$1" && local box_cuts=$1 
test -n "$2" && local array=$2 
test -n "$3" && local atm=$3

# defaults for all configurations
NTubesMin=0/5
MeanScaledLengthLower=0.05
MeanScaledWidthLower=0.05
#TelCombosToDeny=""
test -n "$DistanceUpper" || DistanceUpper=1.43 
# needs to have form -DistanceUpper=0/$DistanceUpper 

noiseLevels=100,150,200,250,300,350,400,490,605,730,870
case "$array" in
    oa | V4)   #model=MDL8OA ; epoch=V4_OldArray 
	pedVars=3.62,4.45,5.13,5.71,6.21,6.66,7.10,7.83,8.66,9.49,10.34 
	autoTelCombosToDeny="T1T4" 
	;;
    na | V5)    #model=MDL15NA epoch=V5_T1Move 
	pedVars=4.29,5.28,6.08,6.76,7.37,7.92,8.44,9.32,10.33,11.32,12.33
	autoTelCombosToDeny=""
	;;
    ua | V6)    #model=MDL10UA epoch=V6_PMTUpgrade 
	pedVars=4.24,5.21,6,6.68,7.27,7.82,8.33,9.20,10.19,11.17,12.17
	autoTelCombosToDeny=""
	;;
    "")
	echo "array not set! only setting array-independent values!"
	;;
    *) 
	echo "Array $array not recognized! Choose either oa (V4), na (V5), ua (V6), or leave it blank!!"
	exit 1
	;;
esac

#check array is valid
case $box_cuts in 
    soft) 
	MeanScaledLengthUpper=1.3
	MeanScaledWidthUpper=1.1
	MaxHeightLower=7
	ThetaSquareUpper=0.03
	S6A_RingSize=0.17
	RBM_SearchWindowSqCut=0.03
	case $array in 
	    oa | V4)
		SizeLower=0/200 ;; 
	    na | V5)
		SizeLower=0/200 ;; 
	    ua | V6)
		SizeLower=0/400 ;;
	esac # loop over arrays 
	;;
    medium) 
	MeanScaledLengthUpper=1.3
	MeanScaledWidthUpper=1.1
	ThetaSquareUpper=0.01
	MaxHeightLower=7
	S6A_RingSize=0.1
	RBM_SearchWindowSqCut=0.01
	case $array in 
	    oa | V4)
		SizeLower=0/400 ;; 
	    na | V5)
		SizeLower=0/400 ;; 
	    ua | V6)
		SizeLower=0/700 ;;
	esac # loop over arrays 
	;;
    hard) 
	MeanScaledLengthUpper=1.4
	MeanScaledWidthUpper=1.1
	MaxHeightLower=-100 # the default value, could
	ThetaSquareUpper=0.01
	S6A_RingSize=0.1
	RBM_SearchWindowSqCut=0.01
	case $array in 
	    oa | V4)
		SizeLower=0/1000 ;; 
	    na | V5)
		SizeLower=0/1000 ;; 
	    ua | V6)
		SizeLower=0/1200 ;; # not well evaluated
	esac # loop over arrays 
	;;
    loose) 
	MeanScaledLengthUpper=1.4
	MeanScaledWidthUpper=1.15
	MaxHeightLower=-100 # check for consistency with process_script and sim_script and tableMaker/ea
	ThetaSquareUpper=0.03
	S6A_RingSize=0.17
	RBM_SearchWindowSqCut=0.03
	case $array in 
	    oa | V4)
		SizeLower=0/200 ;; 
	    na | V5)
		SizeLower=0/200 ;; 
	    ua | V6)
		SizeLower=0/400 ;;
	esac # loop over arrays 
	;;
    *) # array must be specified to set stage 4 cuts
	echo "Box_Cuts $box_cuts is not valid!"
	echo "Usage: setCuts box_cuts [arr]"
	exit 1 ;; 
esac # case for all cuts 

ImpactDistanceUpper=300 # new cut to improve sensitivity 

# LT cuts should be same as stage 4 cuts but excludes size cut 
stage4cuts_auto="-DistanceUpper=0/${DistanceUpper} -SizeLower=$SizeLower -NTubesMin=$NTubesMin"

# these are applied identically in stage 5 and makeEA 
stage5cuts_auto="-MeanScaledLengthLower=$MeanScaledLengthLower -MeanScaledLengthUpper=$MeanScaledLengthUpper"
stage5cuts_auto="$stage5cuts_auto -MeanScaledWidthLower=$MeanScaledWidthLower -MeanScaledWidthUpper=$MeanScaledWidthUpper"
stage5cuts_auto="$stage5cuts_auto -MaxHeightLower=$MaxHeightLower"
stage5cuts_auto="$stage5cuts_auto -ImpactDistanceUpper=$ImpactDistanceUpper"
# common variable for the full set of stage 5 box cuts 
test $MaxHeightLower != -100 && MaxHeightLabel="_MH${MaxHeightLower//./p}" || MaxHeightLabel="" 

#to compact zeniths:
zens_hyph=${zeniths//[ ,]/-}
zenrange="${zens_hyph%%-*}-${zens_hyph##*-}"

# set table names 
ltBase=lt_${model}_${array}_ATM${atm}_${simulation}_${ltVegas}_7samples_${offlabel}_Z${zenrange}_std_d${DistanceUpper//./p}
finishedLT=$ltDir/${ltBase}.root
ltAuto=lt_Oct2012_${array}_ATM${atm}_GrISUDet_vegas250rc5_7samples_050wobb_Z${zenrange}_std_d1p43
eaBase=ea_${model}_${array}_ATM${atm}_${simulation}_${ltVegas}_7samples_${offlabel}_Z${zenrange}_std_d${DistanceUpper/./p}_s${SizeLower/0\//}_MSW${MeanScaledWidthUpper/./p}_MSL${MeanScaledLengthUpper/./p}${MaxHeightLabel}_ThetaSq${ThetaSquareUpper/./p}
finishedEA=$eaDir/${eaBase}_DistCut${ImpactDistanceUpper}m.root


return 0
} # end of setCuts

setSimNames() { # zen offset noise stage 
    # $array and $atm must be set 
    #test -n "$4" && local stage=$4 || ( echoErr "must provide a stage number to setSimNames!!" ; return 1 )

    simFileBase2=Oct2012_${array}_ATM${atm}_vegasv250rc5_7samples_${1}deg_${2//./}wobb_${3}noise
    simFile2=$stage2simDir/${simFileBase2}.root
    simSubDir=Oct2012_${array}_ATM${atm} # for its place in archive 
#simBaseDir=

    simFileBase=Oct2012_${array}_ATM${atm}_${ltVegas}_7samples_${1}deg_${2//./}wobb_${3}noise
    #simFile=$simDir/${simFileBase}.stage${stage}.root
    
    #echo "$simFile"
   
    #if [ "$hillasMode" != HFit ]; then
    #simFileBase=Oct2012_${array}_ATM${atm}_vegasv251_7samples_${z}deg_${offset//./}wobb_${n}noise
    #simFile=$stage2SimDir/Oct2012_${array}_ATM${atm}_HFit/${simFileBase}.root
    #simSubDir=${simSubDir}_HFit
    
} # print out the simulation name 

