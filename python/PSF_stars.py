#!/usr/bin/env python
# written for python2 - python3 will require editing of print statements  
# e.g. print("text"), -> print("text",end="")

#script that takes an optional argument for the date and target collection and calculates angular separation and elevation of each target from the moon. 

import sys, operator, argparse
import ephem, subprocess
from math import ceil 
#import inspect

#host & port info 
#hostName="veritase.sao.arizona.edu"
hostName="romulus.ucsc.edu"
portNum=''

#setting up ephem observer object for veritas
veritas = ephem.Observer()
veritas.lat = '31:40.51'
veritas.lon = '-110:57.132'
veritas.elevation = 1268

minElevation = 20 # the lowest elevation stars to look at

#argument parser
parser = argparse.ArgumentParser(description='Takes optional arguments to specify date and source collection, and min / max moon distances. If no arguments are specified, will choose from all psf stars to make an ordered list appropriate for taking a PSF measurement. For a more general look at elevation and moon distance, see moonDist.py..')

parser.add_argument('--date',default=veritas.date, help='specify DATE (in UT) in the format "YYYY/MM/DD HH:MM"   don\'t forget the quotation marks')

parser.add_argument('--minMoonDist',default='10',help="the minimum distance in degrees that a star should be from the moon to include it in the list") 

parser.add_argument('--maxMoonDist',default='90',help="the maximum distance in degrees that a star should be from the moon, to prevent backlighting and arm shadows")

parser.add_argument('--targets',default='psf_stars',help='specifies collection of targets. Allowed values for TARGETS: psf_stars, yale_bright_star, yale_bright_stars_5.0 -- or any valid VERITAS source collection') 
# moonlight_targets, moonlight_bright, primary_targets, secondary_targets, blazar_filler_targetsGRB, filler_targets, blank_sky, next_day_analysis, lat_highe, reduced_HV_targets, snapshot_targets, survey_crab, survey_cygnus, UV_filter_targets, all

args = parser.parse_args()

#setting date/time to user-spefied value (or default to current date/time)
veritas.date = args.date
#letting user know the date and target collection used.
print
print "Date and time used (in UT): %s" %veritas.date
print "Calculating angular distances from the Moon for targets in %s collection..." %args.targets

#MySQL command, runs on command line through subprocess
execCMD = "SELECT tblObserving_Collection.source_id,ra,decl,epoch FROM tblObserving_Sources JOIN tblObserving_Collection ON tblObserving_Sources.source_id = tblObserving_Collection.source_id WHERE tblObserving_Collection.collection_id='%s'" %args.targets

sqlOut = subprocess.Popen(["mysql","-h","%s" %(hostName),"-P","%s" %(portNum),"-u", "readonly", "-D","VERITAS", "--execute=%s" %(execCMD)], stdout=subprocess.PIPE)

#stores query results
QUERY, err = sqlOut.communicate()
if QUERY == "":
  print
  print "Query result is empty. Make sure date and target collection provided are valid. Going to crash now :("

#dict for sorting/writing stars and their info 
moonlightSources = {}
maxNameLength = 0 
#loop through all objects in the bright moonlight list
#calculating and printing out angular separation from moon
for count,source in enumerate(QUERY.rstrip().split("\n")):
  #skip header in query results
  if count == 0:
    continue
  #parsing through query results
  sourceName=source.split("\t")[0]
  sourceRA=source.split("\t")[1]
  sourceDEC=source.split("\t")[2]
  sourceEpoch=source.split("\t")[3]

  if len(sourceName) > maxNameLength:
    maxNameLength = float(len(sourceName))

  #makes sure same epoch is used
  veritas.epoch = float(sourceEpoch)

  #Define ephem moon object and calculate position (ra, dec) and phase
  TheMoon = ephem.Moon(veritas)
  TheMoon.compute(veritas)
  illum = TheMoon.moon_phase*100.

  moonReflection = ephem.FixedBody(TheMoon.ra,TheMoon.dec)

  #Get angular separation of moon and target
  degFromMoon = 180./ephem.pi * ephem.separation((TheMoon.ra,TheMoon.dec),(float(sourceRA),float(sourceDEC)))

  #Define ehpem object for source, to get elevation
  sourceObj = ephem.FixedBody()
  sourceObj._ra = float(sourceRA)
  sourceObj._dec = float(sourceDEC)
  sourceObj.compute(veritas)
  
  sourceEl = sourceObj.alt*180./ephem.pi # elevation of source
  sourceAz = sourceObj.az*180./ephem.pi # azimuth of source 

  moonlightSources[sourceName]=[(sourceEl, sourceAz, degFromMoon)]
#end of for loop

sorted_sources = sorted(moonlightSources.iteritems(), key=operator.itemgetter(1), reverse=True)

#fbdy = ephem.FixedBody()
#l = dir(fbdy)
#print l 

# for first column 
columnTitle = "Source"
columnTabs = int( ceil( (ceil(maxNameLength/8.)*8.-len(columnTitle))/8.) )
print()
#sys.stdout.write( columnTitle )
print(columnTitle),
for x in range(0, columnTabs):
  print('\t'),
print("Elevation\tAzimuth\t\tDegrees\t\tExposure")
print("----------------------------------------------------------------------------------------")
#print sorted_sources
for source in sorted_sources:
  name = source[0] 
  magnitude =  name.split()[1]
  el = source[1][0][0] # distance from moon 
  az = source[1][0][1] # azimuth 
  dist = source[1][0][2] # elevation 
  if el > minElevation: # and dist > args.minMoonDist and dist < args.maxMoonDist:
    exposure = 1.5 # recommended time for exposure 
    length = len(name)
    numTabs = int( ceil( ( ceil(maxNameLength/8.)*8.-length-1)/8. ) ) 
    print(name),
    for i in range (0, numTabs):
      print("\t"),
    print("%0.3f\t\t%0.3f\t\t%0.3f\t\t%0.1f" %(el, az, dist, exposure))

print("----------------------------------------------------------------------------------------")
print("The Moon is %0.2f%% illuminated" % illum)
print(TheMoon.dec) 
exit(0) # great job 
