#import matplotlib
#import pylab
import numpy
import math
import sys
import os

#star catalog
stars_fov = open("Bright_stars_Hipparcos_MAG9_1997_reduced.dat", mode="r")
mode = "wobble" # wobble or centered
offset = 0.5 # for wobble 

#background region intersection
pointing_dist = 0.6 # radius of background region, centered at pointing direction 
star_excl_rad = 0.35 # radius of exclusion region for bright stars
star_min_mag = 7 # minimum magnitude of stars to list

search_radius = 2.5 # degrees

def printStar( ):
        "This prints the parameters of the current star"
        print ( str ( distance )  + " " + str ( magnitude ) + " " + str ( ra_star ) + " " + str ( dec_star ) )
        return

def checkForStars( ra_check, dec_check ):
        stars_fov.seek(0)
        for line in stars_fov:
                co_stars = line.split()
                ra_star = float ( co_stars[0] )
                dec_star = float ( co_stars[1] )
                magnitude = float ( co_stars[3] )
#                print (magnitude)
                if magnitude <= star_min_mag:
                        #print ( "ra_star:" + str (ra_star) + " ra_check:" + str(ra_check) )
                        #print ( "dec_star:" + str(dec_star) + " dec_check:" + str(dec_check) )
# calculate the distance between star and the wobble pointing direction
# problems could arise near RA of 0 or 360 degrees, or DEC = +/- 90 degrees
                        distance = math.sqrt ( math.pow((ra_star - ra_check),2) + math.pow((dec_star - dec_check),2) )
                        #print ( distance )
                        if distance <= ( pointing_dist + star_excl_rad ):
#                                printStar()
                                print("magnitude: "+str(magnitude)+
                                      " distance: "+str(distance)+
                                      " RA: "+str(ra_star)+
                                      " DEC: "+str(dec_star)+os.linesep)

# read in right ascension and declination in either explicit or expanded form
print ( sys.argv )

if sys.argv.__len__() == 3:
        ra_source = float ( sys.argv[1] )
        dec_source = float ( sys.argv[2] )
elif sys.argv.__len__() == 7:
        hours = float ( sys.argv[1] )
        minutes = float ( sys.argv[2] ) 
        seconds = float ( sys.argv[3] )
        degrees = float ( sys.argv[4] )
        arcmin = float ( sys.argv[5] )
        arcsec = float ( sys.argv[6] )
        ra_source = 15 * ( hours + minutes/60 + seconds / 3600 )
        if degrees >= 0:
                dec_source = degrees + arcmin/60 + arcsec/3600
        elif degrees < 0:
                dec_source = degrees - arcmin/60 - arcsec/3600
elif sys.argv[3] == "radians":
        ra_source = 180 * float ( sys.argv[1] ) / math.pi # convert radians to degrees
        dec_source = 180 * float ( sys.argv[2] ) / math.pi

else:
        print ( "not the right number of arguments!" )
        usage ()
        sys.exit(1) # failure

print ( "Source coordinates: " )
print ( "right ascension: " + str ( ra_source ) )
print ( "declination: " + str ( dec_source ) )
print 




#if mode == "centered":
print ( "checking for stars within " + str ( search_radius ) + " degrees of: " )
for line in stars_fov:
	co_stars = line.split()
	ra_star = float ( co_stars[0] )
	dec_star = float ( co_stars[1] )
	distance = math.sqrt ( (ra_star - ra_source) * (ra_star - ra_source) + (dec_star - dec_source) * (dec_star - dec_source)  ) 
	if numpy.abs( distance ) <= search_radius:
		magnitude = float ( co_stars[3] )
		printStar()
		

print ( " checking for stars in background regions for wobbles: " )
print 

print ( " N wobble: " )
checkForStars( ra_source, ( dec_source + offset ) )
print ( " S wobble: " ) 
checkForStars( ra_source, ( dec_source - offset ) )
print ( " E wobble: " ) 
checkForStars( ( ra_source + offset ), dec_source )
print ( " W wobble: " )
checkForStars( ( ra_source - offset ), dec_source )

stars_fov.close()

sys.exit(0) # success!
