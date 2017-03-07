#!/usr/bin/env python

import os, inspect 
import errno
import sys
import subprocess as sp
import argparse
import time
from common_functions import * # custom module 
import math 
import MySQLdb

#from pprint import pprint 



  #class status(Enum):
    #P = 1
    #S = 2
    #F = 3 

  

# declare classes 

#from enum import Enum
def enum(*args):
  """emulates the enum type in python 3.6"""
  enums = dict(zip(args, range(len(args))))
  return type('Enum', (), enums)

class job():
  """class for instances of jobs that are to be scheduled"""

  Status = enum('P', 'S', 'F')
  glob_id = 0 # running counter to ensure no 2 jobs have the same id

  def __init__(self, name, script):
    self.id = job.glob_id
    self.name = name 
    self.script = script 
    self.status = job.Status.P # pending 
    self.slurm_id = None
    job.glob_id += 1
    #self.scheduler = None

# should this go into job class? x
def submit_job(j):
  """submits job from jobArray via sbatch """
  
  #scripflip = '''<<EOF
#''' 
  #scripflip += j.script + '''
#EOF'''

  cmd = [batch_cmd] 
  proc = sp.Popen(cmd, stdout=sp.PIPE, stdin=sp.PIPE, shell=True)
  out = proc.communicate(j.script)[0]
  #Submitted batch job 3940647
  print out 
  if proc.returncode == 0:
    if batch_cmd == 'sbatch':
      j.slurm_id = int(out.split()[3])
    #print out


  j.status = job.Status.S # submitted status
  

  return proc.returncode



class job_scheduler():
  """keeps array of jobs, handles submissions"""


  def __init__(self):
    self.job_array = []
    #self.submitted_jobs = []
    self.jobID = 0 

  def add_job(self, job):
    self.job_array.append(job)
    self.jobID += 1 

  def print_jobs(self):
    for j in self.job_array:
      print j.id, j.name
      #print j.script
      
  def submit_next_job(self):
    return submit_job(self.job_array.pop())
    


# create hsi data pull script
def create_job_script(date_nums):
  """Create batch script for retrieving data file
  takes in a list of date/num tuple pairs
  returns a string """ # literal 
  
  if len(date_nums) < 1:
    raise ValueError("create_job_script needs at least one date/num tuple")

  
  hsi_cmd = '''hsi <<HERE
'''

  logFile = dataDir+"/data/log/hsi_"+date_nums[0][1]+"-"+date_nums[-1][1]+".log" 
  for date, num in date_nums:

    subpath = "data/d"+date+"/"+num+".cvbf"
    destPath = dataDir+"/"+subpath
    hsiPath = hsiDir+"/"+subpath

    destDir = os.path.dirname(destPath)
    #if not os.path.exists(directory):
    if not os.path.isdir(destDir):
      try:
        os.makedirs(destDir)
      except OSError as error:
        if error.errno != errno.EEXIST:
          raise


    copyCmd = "getDataFile data/d"+date+"/"+runNum+".cvbf"
    #print copyCmd 
  
    hsi_cmd = hsi_cmd + "get " + destPath + " : " + hsiPath + '''
'''

    # end for loop over run tuples 

  hsi_cmd = hsi_cmd + '''
HERE
'''

  # could call a common function to build script header, but this is somewhat of a special case 
  script = '''#!/bin/bash -l
#SBATCH -M esedison
#SBATCH -p xfer
#SBATCH -t 01:00:00
#SBATCH -J %s_hsi
#SBATCH -o %s

source %s

%s 


exitCode=$?
echo "hsi exit code: $exitCode"

if [ "$exitCode" -eq 0 ]; then 
    #md5sum file check 
    # mark job completed
    echo "success!"
else
   # mark as failed
   echo "failure!"
fi

exit $exitCode 
''' % (num, logFile, common_functions, hsi_cmd)


  return script 




# find the directory containing this script
scriptdir = os.path.dirname(os.path.abspath(inspect.getfile(inspect.currentframe()))) # script directory
filepath = inspect.getfile(inspect.currentframe()) # script filename (usually with path)
filepath_phys = os.path.realpath(__file__)

# parse arguments 
parser = argparse.ArgumentParser(description="Creates a job scheduler that submits data retrieval jobs at an adjustable rate \
for use on NERSC, it copies data files from hsi to a local directory, typically scratch")
parser.add_argument('loggenfile', type=argparse.FileType('r'), help="loggen file that contains the runs \
for which you want to retrieve data")
parser.add_argument('--submit','-q', action='store_true', help="run and submit jobs, rather than do a dry run")
parser.add_argument('--run', dest='batch_cmd', help="the runmode")
parser.add_argument('--dir', default=os.environ['CSCRATCH'], help="the destination directory for files. defaults to $CSCRATCH")
parser.add_argument('--env','-e', help="environment file defining your system and data directories \
this is currently not necessary. either source environment file before running or supply --dir argument ")
args = parser.parse_args()

### variables needed, either from environment or arguments
dataDir = args.dir
if not os.path.isdir(dataDir):
  eprint("Destination directory " + dataDir + "does not exist! ")
  sys.exit(1)


# set defaults 
if args.submit:
  args.batch_cmd = 'sbatch' 

if args.batch_cmd:
  batch_cmd = args.batch_cmd


nJobs = 5 # number of simultaneous jobs 
#nJobs = 10 # this should probably be the max 
common_functions = scriptdir + "/common_functions.sh"
hsiDir = "/home/projects/m1304"
datenumarray = [] # tracks every run number that has been added in this script 


# import the environment 

if args.env:
  proc = sp.Popen(['bash', '-c', 'source %s && env' % args.env], stdout=sp.PIPE)
  out = proc.communicate()[0]
  #source_env = {tup[0].strip(): tup[1].strip() for tup in map(lambda s: s.strip().split('=', 1), out)}

  print map(lambda s: s.strip().split('=', 1), out)
  for line in out:
    print line

#pprint.pprint(dict(os.environ))

logdir = dataDir + "/data/log"
mkdirs(logdir)


sched = job_scheduler()

conn = MySQLdb.connect(host='romulus.ucsc.edu', user='readonly', db='VERITAS', passwd='')
cursor = conn.cursor()

### fill the job array ###
for line in args.loggenfile:
  line = line.split()
  
  date = line[0]
  runNum = line[1]
  fullDir = dataDir + "/d" + date 

  for laser in line[2:5]:
    if laser != '--' and laser not in [t[1] for t in datenumarray]:      
      query = "SELECT data_end_time FROM tblRun_Info WHERE run_id="+laser
      cursor.execute(query)
      # there should only be one row and one entry, which is the date 
      dt = cursor.fetchall()[0][0]
      laserdate = dt.strftime("%Y%m%d")
      datenumarray.append((laserdate,laser))
      
  scratchPath = fullDir + "/" + runNum + ".cvbf" 
  if not os.path.isfile(scratchPath) and runNum not in [t[1] for t in datenumarray]:
    datenumarray.append((date,runNum))
  #else continue 
  

  #jobarray[runNum] = create_job_script(date, runNum)

    
n_per_job = math.ceil(float(len(datenumarray) / nJobs))
job_list = [] # list of runs to go into job, with corresponding date

# rewrite 
### loop over lines, then add remaining jobs: 
print datenumarray
n = 0 
for dn in datenumarray:
  job_list.append(dn)

  if len(job_list) > n_per_job:
    j = job(n, create_job_script(job_list))
    job_scheduler.add_job(sched, j)
    job_list = []
    n += 1 


if len(job_list) > 0:
  j = job(n+1, create_job_script(job_list))
  job_scheduler.add_job(sched, j)


sched.print_jobs()
#pprint(jobArray)


# submit and monitor jobs until all jobs have completed 
n = 0 
if args.batch_cmd:
  for j in sched.job_array:
    
    print "submitting job, n = " + str(n)
    exitCode = sched.submit_next_job()
    if exitCode == 0:
      n += 1 
    
  # end loop over jobs for submission 
# if batch command is specified 


#while len(sched.job_array) > 0:
  #cmd = ['squeue', '-u', '$(whoami)', '-M', 'esedison']

  #if n >= n_per_job:
      #time.sleep(180)
  #n = 0 
    
    #else:


sys.exit(0) # great success 
