# Information used by all python scripts:

## Variables
scratchDir = '/scratch/mbuchove'
# template for simulation files
simPathnameUCLA = '/veritas/upload/OAWG/stage2/vegas2.5/Oct2012_{ARRAY}_ATM{ATMOSPHERE}{HFITFLAG}/{ZENITH}_deg/Oct2012_{ARRAY}_ATM{ATMOSPHERE}_vegasv250rc5_7samples_{ZENITH}deg_{OFFSET}wobb_{NOISE}noise.root' 

## Functions

def getSimFileName(array,atmosphere,zenith,offset,noise,method):

    if array=='oa' or array=='old' or array=='V4': array='oa'
    if array=='na' or array=='new' or array=='V5': array='na'
    if array=='ua' or array=='upgrade' or array=='V6': array='ua'

