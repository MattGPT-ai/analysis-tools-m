from __future__ import print_function
import sys
import os 

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)
    

def mkdirs(directory):
    if not os.path.isdir(directory):
        try:
            os.makedirs(directory)
        except OSError as error:
            if error.errno != errno.EEXIST:
                raise


#def debugprint(msg):
#if debug:
#print(msg)
