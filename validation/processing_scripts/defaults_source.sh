# whether or not to use docker. the rest of the configuration related to this is set in environment 
test -z "$use_docker" && use_docker=true # by default, use docker 
# this can be turned off either here or in the options when running script files

#######################################
### simulation and table variables  ###
#######################################
ltMode=custom 
# the table names are set using these options in setCuts function in set_params.sh 
ltVegas=vegas255 # these parameters determine the filename of the lookup tables when auto is selected 
simulation=GrISUDet # detector simulation, other option CORSIKA 
model=Oct2012 # simulation model 
atms="21 22" # atmosphere for winter / summer 
arrays="oa na ua"
# parameter space specification for sims and tables 
zeniths="00,20 30,35" # 40,45" # 50,55 60,65"
#zeniths="00,20 30,35 40,45 50,55 60,65"
offsets="0.50" 
#offsets="0.00,0.50,0.75 0.25,1.00 1.25,1.50 1.75,2.00" 
offlabel="050off" # for tables 
azimuths="0,45,90,135,180,225,270,315"
#azimuths="0,45 90,135 180,225 270,315"
cuts_set="soft medium hard" # only relevant for EAs
# loose cuts not performed by default 

# job processing - signals for traps 
#signals="1 2 3 4 5 6 7 8 11 13 15 30"

##### Stage 6 #####

