import os
import sys
import argparse
import numpy
import math


# parse arguments, and default values  
parser = argparse.ArgumentParser(description="Check different fields of view for bright stars")
parser.add_argument('coordinates', type=float, nargs='*', help="coordinates for right ascension and declination, either in 2 or 6 parameters. not necessary if runID is specified")
parser.add_argument('--rad', action='store_true', help="coordinates entered are to be interpreted as in radians, default is degrees")
parser.add_argument('--runID', type=int, default=0, help="check the coordinates of a particular run, accounting for wobble")
parser.add_argument('--mag_thresh', type=float, default=6.5, help="the maximum magnitude, representing the least bright star, that will be reported")
parser.add_argument('--radius', type=float, default=1.0, 
                    help="the search radius within which to search for stars")
parser.add_argument('--offset', type=float, default=0.5, help="the wobble offset angle to test")

args = parser.parse_args()
#namSpc = argparse.Namespace()
#vars(args)

global distance, magnitude, ra_star, dec_star
distance = 0.0 
magnitude = 0.0 
ra_star = 0.0 
dec_star = 0.0 

# star catalog
stars_cat = open("/veritas/userspace2/mbuchove/BDT/data/Bright_stars_Hipparcos_MAG9_1997_reduced.dat", mode="r")

def printStar( ): 
    "This prints the parameters of the current star"
    print ( str ( distance )  + " " + str ( magnitude ) + " " + str ( ra_star ) + " " + str ( dec_star ) )
    return

def checkForStars( ra_check, dec_check ):
        stars_cat.seek(0)
        for line in stars_cat:
                star_line = line.split()
                ra_star = float ( star_line[0] )
                dec_star = float ( star_line[1] )
                magnitude = float ( star_line[3] )

                if magnitude <= args.mag_thresh:
                    # calculate the distance between star and the wobble pointing direction
                    # problems could arise near RA of 0 or 360 degrees, or DEC = +/- 90 degrees
                    distance = math.sqrt ( math.pow((ra_star - ra_check),2) + math.pow((dec_star - dec_check),2) )
                    if distance <= args.radius:
                        print ( str ( distance )  + " " + str ( magnitude ) + " " + str ( ra_star ) + " " + str ( dec_star ) )
                        #printStar()
                        
        return 

if args.runID != 0: 
    import MySQLdb
    connection = MySQLdb.connect ( host = "romulus.ucsc.edu", 
                                   user = 'readonly',  
                                   db = 'VERITAS',
                                   port = 3306 )
    cursor = connection.cursor()
    cursor.execute("SELECT a.ra, a.decl, b.offsetRA, b.offsetDEC FROM tblObserving_Sources a JOIN tblRun_Info b ON a.source_id = b.source_id WHERE b.run_id = %s", (args.runID))
    coords_query = cursor.fetchone()
    ra_source = 180 * coords_query[0] / math.pi
    dec_source = 180 * coords_query[1] / math.pi 
    ra_offset = 180 * coords_query[2] / math.pi
    dec_offset = 180 * coords_query[3] / math.pi 

    print ( "Run number: " + str(args.runID) ) 
    checkForStars( ra_source + ra_offset, dec_source + dec_offset )

else:
    # read in right ascension and declination in either explicit or expanded form
    if len(args.coordinates) == 2:
        ra_source = float ( args.coordinates[0] )
        dec_source = float ( args.coordinates[1] )
        if args.rad: # coordinates are listed in radians 
            ra_source = 180 * float ( ra_source ) / math.pi # convert radians to degrees
            dec_source = 180 * float ( ra_dec ) / math.pi

        elif len(args.coordinates) == 6:
            hours = float ( args.coordinates[0] )
            minutes = float ( args.coordinates[1] ) 
            seconds = float ( args.coordinates[2] )
            degrees = float ( args.coordinates[3] )
            arcmin = float ( args.coordinates[4] )
            arcsec = float ( args.coordinates[5] )
            ra_source = 15 * ( hours + minutes/60 + seconds / 3600 )
            if degrees >= 0:
                dec_source = degrees + arcmin/60 + arcsec/3600
            elif degrees < 0: # minutes and seconds generally not listed as negative 
                dec_source = degrees - arcmin/60 - arcsec/3600
            print ( "Source coordinates: " + str ( ra_source ) + "\t" + str( dec_source ) + os.linesep )

        else:
            print ( "Check your arguments! Must provide either runID or coordinates" )
            print ( "run with -h or --help to see usage!" ) 
            sys.exit(1) # failure

        print ( "checking for stars within " + str ( args.radius ) + " degrees of: " )
        #checkForStars( ra_source, dec_source )
		
        print ( " checking for stars in background regions for wobbles: " )

        print ( " N wobble: " )
        checkForStars( ra_source, ( dec_source + args.offset ) )
        print ( " S wobble: " ) 
        checkForStars( ra_source, ( dec_source - args.offset ) )
        print ( " E wobble: " ) 
        checkForStars( ( ra_source + args.offset ), dec_source )
        print ( " W wobble: " )
        checkForStars( ( ra_source - args.offset ), dec_source )

stars_cat.close()

sys.exit(0) # success!
