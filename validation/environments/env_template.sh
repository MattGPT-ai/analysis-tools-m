##############################
##### CUSTOM ENVIRONMENT ##### 
##############################

# Information on using this file can be found at 
#
# https://veritas.sao.arizona.edu/OAWGwiki/index.php/VEGAS_validation_pipeline_NERSC
#

# this environment file is sourced after $VALIDATION/environments/env_Crab.sh and the options are processed
# so its values override those set in the script defaults and options 

# the paths worked with within the processing scripts 
# for default validation this is set to $VALIDATION_DIR/$source_name
export workDir= 

# where to store vbf files prior to analysis, best to let scripts copy from hsi to scratch 
export dataDir= 

# where processed laser files are stored and logged, it is useful to set this to the same directory for 
# all sources to prevent rerunning if not necessary
export laserDir= 

# directory to store intermediate table files
# for default validation this is set to $VALIDATION_DIR/TableProduction
export tableWork= 

# directories where completed, combined tables are stored, and where other scripts read tables for processing
export ltDir=$tableWork/ltDir
export eaDir=$tableWork/eaDir

# where the preprocessed sims are stored
export stage2simDir= 

# as for workDir but for workDir but where simulation work is conducted
# for default validation this is set to $VALIDATION/sims
export simWork=

# assuming that you are working with docker/shifter this is the id of the image that you want to run.
# see https://veritas.sao.arizona.edu/OAWGwiki/index.php/Docker_and_Shifter_Environments for information on this 
export imageID=764f612bbc90:VV-rc

########################################################################

# multiple people can share data and use the same working directory if permissions are set up properly
# e.g. set stage2simDir=/global/cscratch1/sd/mbuchove/sims/stage2
# you will want to chown -R `whoami`:m1304 /path/to/shared_directory
# chmod -R g+rw /path/to/shared_directory 
