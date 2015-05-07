# Information used by all python scripts:

## Variables
scratchDir = '/scratch/mbuchove'
# template for simulation files
simPathnameUCLA = '/veritas/upload/OAWG/stage2/vegas2.5/Oct2012_{ARRAY}_ATM{ATMOSPHERE}{HFITFLAG}/{ZENITH}_deg/Oct2012_{ARRAY}_ATM{ATMOSPHERE}_vegasv250rc5_7samples_{ZENITH}deg_{OFFSET}wobb_{NOISE}noise.root' 
produceLTConfigFile = '/home/mbuchove/config/produce_lookupTables_config.txt'
produceLTCutsFile = 'home/mbuchove/cuts/lt_cuts.txt'
fullZenithList=[0,20,30,35,40,45,50,55,60,65]
fullAzimuthList=[0,45,90,135,180,225,270,315]
fullOffsetList=[0.00,0.25,0.50,0.75,1.00,1.25,1.50,1.75,2.00]
fullNoiseList=[100,150,200,250,300,350,400,490,605,730,870]


## Functions
# add usage functions, function call with no arguments 

def getSimFileName(array,atmosphere,zenith,offset,noise,mode='std'):

    if array.lower()=='oa' or array=='V4': array='oa' # or array=='old' 
    elif array.lower()=='na' or array=='V5': array='na' # or array=='new' 
    elif array.lower()=='ua' or array=='V6': array='ua' # or array=='upgrade' 
    else: 
        print("Array "+array+" not recognized! ")
        exit(1) # could return to continue code  

    # the .lower() can be wrong in Unicode, look into libc.strcasecmp()
    if atmosphere.lower()=='winter' or "21" in atmosphere: atmosphere=21
    if atmosphere.lower()=='summer' or "22" in atmosphere: atmosphere=22

    if zenith==10: zenith=00 # not indexed by 10 anyway though 

    if '.' in offset: offset=offset.replace('.','')
    
    if mode.upper()=='HFIT': hfitFlag='_HFit'
    else: hfitFlag='' # don't worry about other inputs, either hfit or not
    # this logic would cause a warning in C++ 

    simFile = simPathnameUCLA
    simFile = simFile.replace('{ARRAY}',array)
    simFile = simFile.replace('{ZENITH}',zenith)
    simFile = simFile.replace('{OFFSET}',offset)
    simFile = simFile.replace('{NOISE}',noise)
    
    return simFile # return simulation filename to getSimFileName(array,atmosphere,zenith,offset,noise,mode='std')


 
