setCuts() { # each argument should only be single valued

# defaults for all configurations
NTubesMin=0/5
MeanScaledLengthLower=0.05
MeanScaledWidthLower=0.05
#TelCombosToDeny=
test -z "$DistanceUpper" && DistanceUpper=1.43  
# needs to have form -DistanceUpper=0/$DistanceUpper 

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
	ThetaSquareUpper=0.00
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
	echo "Spectrum $spectrum is not valid!" ;;
esac # loop over spectra 

return 0
} # end of setCuts

#else
#    echo "Usage: setCuts spectrum [array]"
#    return 1

#if [ $1 ]; then
#    spectrum=$1
#fi # make sure both 
#if [ $2 ]; then
#    array=$2
#fi
#telDenyFlag="TelCombosToDeny=T1T4"
