#!/usr/bin/python

# Script to convert list of stage 5 files to the format required by stage6 in vegas 2.5
# The first argument is the stage 5 run list file.
# The second argument is the reformatted output file.
#
# The script only identifies the number of tels, na/oa, and summer/winter.
# The user must still match up EA tags with the real
# EA files. The script doesn't know where you keep your set of EAs.
# The script also doesn't know about things like soft/med/hard or H vs HFit.  
#
# Contents of CONFIG blocks of each group are left blank. The user should add the desired
# cuts or configs (e.g., S6A_RingSize 0.17)
#
# Format assumed for stage 5 files is /path/to/file/<RUN ID>.stage5.root
#
# Winter atmosphere (ATM21) is from November through March
# Summer atmosphere (ATM22) is from April to October

import subprocess 
import argparse
import sys

class ListGen(object):
    
  def __init__(self):
    
    #Dates for array configs
    self.NA_date = "2009-09-01"
    self.UA_date = "2012-09-01"

    #Database information
    self.hostName = "romulus.ucsc.edu"
    self.portNum = 33060
    
    #define months for ATM21/ATM22 distinction
    self.spring_cutoff = 3  #ATM21 goes through this month 
    self.fall_cutoff = 11   #ATM22 goes up to this month (not including)

  def runSQL(self, execCMD, database):
    #runs the mysql command provided and returns the output list of results
    sqlOut = subprocess.Popen(["mysql","-h","%s" %(self.hostName),"-P","%s" %(self.portNum),"-u", "readonly", 
                               "-D","%s" %(database), "--execute=%s" %(execCMD)], stdout=subprocess.PIPE)
    query, err = sqlOut.communicate()
    #return query
    return query.rstrip().split("\n")[1]

  
  def get_tel_cut_mask(self, query):
    #parses query output for tel_cut_mask
    return query

  
  def get_tel_config_mask(self, query):
    #parses query output for config_mask
    return int(query.split("\t")[4])

  def get_tel_combo(self, tel_config_mask):
    #uses config mask to determine telescope participation
    config_mask_ref={0 : "xxxx",
                     1 : "1xxx",
                     2 : "x2xx",
                     3 : "12xx",
                     4 : "xx3x",
                     5 : "1x3x",
                     6 : "x23x",
                     7 : "123x",
                     8 : "xxx4",
                     9 : "1xx4",
                     10 : "x2x4",
                     11 : "12x4",
                     12 : "xx34",
                     13 : "1x34",
                     14 : "x234",
                     15 : "1234",
    }

    return config_mask_ref[tel_config_mask]

  def reconcile_tel_masks(self, tel_cut_mask, tel_config_mask):
    #when tel_cut_mask is present, checks it against tel_config_mask
    #and returns the result
    #!!! the case where the two do not match is not handled !!!
    tel_cut_ref_T1 = ["1","2","3","4","5","6","7","NULL","0"]
    tel_cut_ref_T2 = ["1","2","3","8","9","10","11","NULL","0"]
    tel_cut_ref_T3 = ["1","4","5","8","9","12","13","NULL","0"]
    tel_cut_ref_T4 = ["2","4","6","8","10","12","14","NULL","0"]
  
    config_ref_T1 = [1,3,5,7,9,11,13,15]
    config_ref_T2 = [2,3,6,7,10,11,14,15]
    config_ref_T3 = [4,5,6,7,12,13,14,15]
    config_ref_T4 = [8,9,10,11,12,13,14,15]
      
    tel_config = ""
    T1 = "x"
    T2 = "x"
    T3 = "x"
    T4 = "x"

    if str(tel_cut_mask) in tel_cut_ref_T1 and tel_config_mask in config_ref_T1:
      T1=1
      tel_config = str(T1)+str(T2)+str(T3)+str(T4)
      
    if str(tel_cut_mask) in tel_cut_ref_T2 and tel_config_mask in config_ref_T2:
      T2=2
      tel_config=str(T1)+str(T2)+str(T3)+str(T4)
      
    if str(tel_cut_mask) in tel_cut_ref_T3 and tel_config_mask in config_ref_T3:
      T3=3
      tel_config=str(T1)+str(T2)+str(T3)+str(T4)
      
    if str(tel_cut_mask) in tel_cut_ref_T4 and tel_config_mask in config_ref_T4:
      T4=4
      tel_config=str(T1)+str(T2)+str(T3)+str(T4)

    return tel_config


  def get_atm(self, query):
    #parses query result for month (day) and returns appropriate ATM (21 or 22)
    month = int(query.split("\t")[0])
    day = int(query.split("\t")[1]) #can define division for a specific day of month

    if month <= self.spring_cutoff or month >= self.fall_cutoff:
      return "ATM21"
    else:
      return "ATM22"

  def get_array_config(self, query):
    #parses query result for difference between run date & NA
    #and run date & UA and returns array config (OA, NA, or UA)
    date_diff_NA = int(query.split("\t")[2])
    date_diff_UA = int(query.split("\t")[3])
    
    #Choose upgrade, new, or old array
    if date_diff_UA >= 0:
      return "UA"
    elif date_diff_NA >= 0:
      return "NA"
    elif date_diff_NA < 0:
      return "OA"

  def print_runlist(self,groups,outfile):
    #takes dictionary of run groups and output file and
    #prints them according to the format required by v2.5.1+
    GROUPID = 0
    for config_code, group_runs in groups.iteritems():
      #handles first group that requires special formatting(not printing config)
      if GROUPID == 0:
        for l in group_runs:
          outfile.write( l+"\n" )
        outfile.write( "[EA ID: %s]\n" % (GROUPID) )
        outfile.write( config_code + "\n" )
        outfile.write( "[/EA ID: %s]\n" % (GROUPID) )
        GROUPID += 1
      #for all other groups
      else:
        outfile.write( "[RUNLIST ID: %s]\n" % (GROUPID) )
        for l in group_runs:
          outfile.write( l +"\n")
        outfile.write( "[/RUNLIST ID: %s]\n" % (GROUPID) )
        #prints out Effective Area blocks for each group
        #currently, it writes codes for EA file, which then
        #need to be replaced by the full EA paths
        #ADD AUTOMATCHING FUNCTIONALITY
        outfile.write( "[EA ID: %s]\n" % (GROUPID) )
        outfile.write( config_code +"\n")
        outfile.write( "[/EA ID: %s]\n" % (GROUPID) )
        outfile.write( "[CONFIG ID: %s]\n" % (GROUPID) )
        outfile.write( "[/CONFIG ID: %s]\n" % (GROUPID) )
        GROUPID += 1

def main():

  #parsing arguments
  parser = argparse.ArgumentParser(description='Takes an input file with paths to stage5 files and generates a runlist for stage6. Note: the runlist still needs to be manually edited to input the proper paths to EA files and fill out the Config blocks with desired cuts/configs.')
  parser.add_argument('infile', nargs='?', type=argparse.FileType('r'), default=sys.stdin)
  parser.add_argument('outfile', nargs='?', type=argparse.FileType('w'), default=sys.stdout) 
  args = parser.parse_args()

  #Define a ListGen object
  runsobj = ListGen() 
  
  #Dictionary to keep track of groups
  groups = {}
  
  #Read stage5 file paths into a list
  lines = args.infile.read().rstrip().split('\n') 
 
  print "Using observer reported tel participation, unless DQM info is available"
  #Loop through file and execute for each run
  for run in lines:
    runID = run[-17:-12]
    print "Querying",runID, "..."
  
    #Do mySQL queries through command line, using subprocess module 
    execCMD_TCM = "select tel_cut_mask from tblRun_Analysis_Comments where run_id='%s'" %(runID)
    
    execCMD_all = "select MONTH(data_start_time),DAY(data_start_time),DATEDIFF(data_start_time,'%s'),DATEDIFF(data_start_time,'%s'),config_mask from tblRun_Info where run_id='%s'" %(runsobj.NA_date,runsobj.UA_date,runID)
    
    #Retrieve query results
    q_tcutmask = runsobj.runSQL(execCMD_TCM,'VOFFLINE')
    q_all = runsobj.runSQL(execCMD_all,'VERITAS')
    
    #use query results to determine parameters required for grouping runs
    tcutmask = runsobj.get_tel_cut_mask(q_tcutmask)
    ac = runsobj.get_array_config(q_all)
    atm = runsobj.get_atm(q_all)
    tconfigmask = runsobj.get_tel_config_mask(q_all)
  
    #Choose telescope combination
    if tcutmask == "NULL":
      #print "No DQM info exists, using observer reported tel-config"
      telcombo = runsobj.get_tel_combo(tconfigmask)
    #if TEL_CUT_MASK does exist, crosschecking with CONFIG_MASK
    else:      
      print "DQM info available, cross-checking with observer-reported tel participation"
      telcombo = runsobj.reconcile_tel_masks(tcutmask, tconfigmask)
     
    #combined configuration code for identifying runs with groups
    fullConfig = ac + "_"+ atm +"_"+ "T" + telcombo 
    
    #check to see if a group already exists for a given config and add run to group
    #otherwise, create a new group and add run to group
    if fullConfig in groups:
      groups[fullConfig].append(run)
    else:
      groups[fullConfig] = [run]

  #prints the runlist
  runsobj.print_runlist(groups,args.outfile)
  
if __name__ == '__main__':
  main()
