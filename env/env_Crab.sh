# this is the basic template for an environment. to make your own, you can either copy and edit this
# OR
# you can create a smaller file that sources this and overwrites the relevant variables, see the other env files for an example 
# this script is designed for bash shells 
# it might be more clear to append variable names set here with _env 

##############################
##### CUSTOM ENVIRONMENT ##### 
##############################

### Crab specifics ###
export sourceName=Crab # change this if you're not working on the Crab 
default_cuts=medium # default 
# stage 6 variables 
s6_defaults="-S6A_ExcludeSource=1 -S6A_DrawExclusionRegions=2" #-S6A_Spectrum=1
suppressRBM=0
s6Opts="$s6Opts -S6A_SourceExclusionRadius=0.4 "
binfile_relpath="../config_files/EnergyBins_coarse.txt" # adds energy binning filename with path relative to directory containing execute-stage6.sh 
s6Opts="$s6Opts -SP_EnergyBinning=1 "
positionFlags="-S6A_TestPositionRA=187.70593 -S6A_TestPositionDEC=12.54112" # optional for stage 6 

# set this variable to the top level of your analysis 
[ $workSpace ] && export workDir=$workSpace/$sourceName # the paths worked with within the processing scripts 
export dataDir=$scratchDir/data # where to store vbf files, best to let scripts copy from hsi to scratch 
export laserDir=$workSpace/lasers # where processed laser files are stored and logged 
export tableWork=$workSpace/tables # path to store intermediate table files 
#export ltDir=$workSpace/combined # directory with completed LTs for use with stage 4 processing of data and sims 
#export eaDir=$workSpace/combined # directory with completed EAs that will be written into stage 6 runlists 
export simWork=$workSpace/sims # where you store processed sims you create - these will be used to create EAs
export stage2simDir=$scratchDir/sims/stage2 # where stage 2 sims are stored (or will be copied to if they are not present ) - they will be used to create stage 4 sims and LTs 
