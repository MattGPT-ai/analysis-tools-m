
### stage 6 stuff ###

export sourceName=Crab
#export loggenFile=$HOME/runlists/M87_V5_loggen.txt
#export positionFlags="-S6A_TestPositionRA=187.70593 -S6A_TestPositionDEC=12.54112"       
export spectrum=medium # default spectrum

### workdir ### 

export SHIFTER=docker:registry.services.nersc.gov/0dc266c2474d:latest
export VEGASWORK=/external_output #/$sourceName 
#project/projectdirs/m1304/mbuchove/$sourceName

##### VERITAS #####

#export VERITASBASE=/project/projectdirs/m1304/mbuchove/veritas/
#export VEGAS=$VERITASBASE/src/vegas-v2_5_4/
#source $VERITASBASE/src/root-v5-34/bin/thisroot.sh

#export LD_LIBRARY_PATH=$VERITASBASE/lib/:${LD_LIBRARY_PATH}
#export PKG_CONFIG_PATH=$VERITASBASE/lib/pkgconfig/:${PKG_CONFIG_PATH}

#export LD_LIBRARY_PATH=$VEGAS/common/lib/:$LD_LIBRARY_PATH
#export LD_LIBRARY_PATH=$VEGAS/diagnostics/lib/:$LD_LIBRARY_PATH
#export LD_LIBRARY_PATH=$VEGAS/diagnostics/displays/lib/:$LD_LIBRARY_PATH
#export LD_LIBRARY_PATH=$VEGAS/resultsExtractor/lib/:$LD_LIBRARY_PATH
#export LD_LIBRARY_PATH=$VEGAS/showerReconstruction2/lib/:$LD_LIBRARY_PATH

#export VERITASBASENAME=$VERITASBASE
#export PATH=$VEGAS/bin/:$VERITASBASE/bin/:$VERITASBASE/include/:$PATH
