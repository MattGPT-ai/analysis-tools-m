##############################
##### CUSTOM ENVIRONMENT ##### 
##############################

# this environment file is sourced after env_Crab.sh and the options are processed
# so its values override those set in the script defaults and options 
sourceName=Segue # change this if you're not working on the Crab 
### PKS1424 specifics for stage 6 ###
default_cuts=soft # default 
suppressRBM=0


########################################################################
### working directories 

scratchDir=$CSCRATCH
export workDir=$scratchDir/$sourceName # the paths worked with within the processing scripts 
export dataDir=$scratchDir/data # where to store vbf files, best to let scripts copy from hsi to scratch 
export laserDir=$scratchDir/lasers # where processed laser files are stored and logged 
export tableWork=$scratchDir/tables # directory to store intermediate table files 
export ltDir=$tableWork/combined # directory where completed, combined tables are stored, and where other scripts read tables for processing 
export stage2simDir=$scratchDir/sims/stage2 # where the preprocessed sims are stored, project default is in project dir 
export simWork=$scratchDir/sims # where you store processed sims you create - 

# for tables 
zeniths="00,20 30,35"
