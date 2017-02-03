
# sets cuts and configurations based on array and spectrum
# atmosphere currently not accounted for 
setCuts() { # each argument should only be single valued

test -n "$1" && spectrum=$1
test -n "$2" && array=$2

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
	autoTelCombosToDeny="TelCombosToDeny=T1T4"
	;;
    na | V5)    #model=MDL15NA epoch=V5_T1Move 
	pedVars=4.29,5.28,6.08,6.76,7.37,7.92,8.44,9.32,10.33,11.32,12.33
	autoTelCombosToDeny=""
	;;
    ua | V6)    #model=MDL10UA epoch=V6_PMTUpgrade 
	pedVars=4.24,5.21,6,6.68,7.27,7.82,8.33,9.20,10.19,11.17,12.17
	autoTelCombosToDeny=""
	;;
#    *) 
#	echo "Array $array not recognized! Choose either oa, na, or ua!!"
#	exit 1
#       ;;
esac

#check array is valid
case $spectrum in 
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
	echo "Spectrum $spectrum is not valid!"
	exit 1 ;; 
esac # loop over spectra 

ImpactDistanceUpper=300 # increases sensitivity 
# LT cuts should be same as stage 4 cuts but excludes size cut
# these are applied identically in stage 5 and makeEA
stage5cuts="-MeanScaledLengthLower=$MeanScaledLengthLower -MeanScaledLengthUpper=$MeanScaledLengthUpper"
stage5cuts="$stage5cuts -MeanScaledWidthLower=$MeanScaledWidthLower -MeanScaledWidthUpper=$MeanScaledWidthUpper"
stage5cuts="$stage5cuts -MaxHeightLower=$MaxHeightLower"
stage5cuts="$stage5cuts -ImpactDistanceUpper=$ImpactDistanceUpper"

# set table names
ltBase=lt_Oct2012_${array}_ATM${atm}_GrISUDet_${ltVegas}_7samples_050off_Z00-65_std_d1p43
ltFull=$VALIDATION/tables/full/${ltBase}.root
test $MaxHeightLower != -100 && MaxHeightLabel="_MH${MaxHeightLower//./p}" || MaxHeightLabel=""
eaBase=ea_Oct2012_${array}_ATM${atm}_GrISUDet_vegas255_7samples_050off_Z00-65_std_d${DistanceUpper/./p}_s${SizeLower/0\//}_MSW${MeanS\
caledWidthUpper/./p}_MSL${MeanScaledLengthUpper/./p}${MaxHeightLabel}_ThetaSq${ThetaSquareUpper/./p}
eaFull=$VALIDATION/tables/full/${eaBase}.root


return 0
} # end of setCuts

#else
#    echo "Usage: setCuts spectrum [array]"
#    return 1
