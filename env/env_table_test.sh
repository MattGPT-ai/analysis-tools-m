##############################
##### CUSTOM ENVIRONMENT ##### 
##############################
sourceName=Crab # change this if you're not working on the Crab 
export workDir=$projectDir/$sourceName # the paths worked with within the processing scripts 

export dataDir=$scratchDir/data # where to store vbf files, best to let scripts copy from hsi to scratch 
export laserDir=$projectDir/validation/lasers # where processed laser files are stored and logged 
export tableWork=$projectDir/validation/tables/v255 # path to store intermediate table files 
export ltDir=$tableWork/full # where completed tables go 
export stage2simDir=$scratchDir/sims/stage2 # where the preprocessed sims are stored, project default is in project dir 
export simWork=$scratchDir/sims # where you store processed sims you create - 

ltVegas=vegasv250rc5

########################################################################
