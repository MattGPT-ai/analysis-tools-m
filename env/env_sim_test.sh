##############################
##### CUSTOM ENVIRONMENT ##### 
########################################################################

export tableWork=$projectDir/validation/tables/v255 # directory to store intermediate table files 
export ltDir=$projectDir/validation/tables/full # directory where completed, combined tables are stored, and where other scripts read tables for processing 
export stage2simDir=$scratchDir/sims/stage2 # where the preprocessed sims are stored, project default is in project dir 
export simWork=$scratchDir/sims # where you store processed sims you create - 

########################################################################

# by default, environments/env_Crab.sh is always sourced, so you only need to include variables here that you wish to change!
# multiple people can share data and use the same working directory if permissions are set up properly
# e.g. set stage2simDir=/global/cscratch1/sd/mbuchove/sims/stage2
# you may want to chmod -R g+rw /path/to/shared_directory 
