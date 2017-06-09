#!/usr/bin/perl

# Take list of sources. Order by RA, list time over min elevation, last wobble.

# PERL MODULE WE WILL BE USING
use DBI;
use Astro::Time;
use Astro::Sunrise;
use Astro::MoonPhase;
use Getopt::Long;
# use Astro::Coord::ECI;
# use Astro::Coord::ECI::Moon;
# use warnings 'all';

my $db_source="";
my $db_list = 'primary_targets';
my $txt_list = "";

my $min_elevation = 60;
my $help=0;
my $verbose=0;
my $date="";

GetOptions ("elevation=i" => \$min_elevation,    # numeric
                    "targets=s"   => \$db_list,      # string
	        "source=s" => \$db_source,
	        "txt=s" => \$txt_list,
                    "help"  => \$help,  # flag
	        "nocuts" => \$verbose ,
	          "date=s"=> \$date ,
	    "printall"=> \$verbose);
                       
print "Script prints next wobble (assuming NSEW), source name, time when the source rises above min elevation, time & elevation/azimuth at culmination, and time when it sets below min elevation.\n";
if ($help) {

    print "Usage: eg. culminationTime.pl --elevation 60 --targets primary_targets --nocuts\n" ;
    print "Or culminationTime.pl --elevation 60 --source Crab --date 2014/05/25\n";
    print "Or culminationTime.pl --txt list.txt, where list.txt contains one sourcename per line. \n";
    print "Spelling/spaces must be the same as in the DB or the source won't be picked up!\n";
    print "Use --nocuts to print all sources including those that don't reach minimum elevation and those that culminate during the day.\n";
    print "Source collections in DB:\n";
    print "01observing\n02observing\n03observing\nprimary_targets\nsecondary_targets\nblazar_filler_targets\nmoonlight_bright\nmoonlight_targets\nblank_sky\npsf_stars\nyale_bright_star_5.0\n";
    print "More info: https://veritas.sao.arizona.edu/wiki/index.php/CulminationTime \n";
    exit;

}

if ($db_source ) {
    $verbose=1;
}

my $obs_lat = 31.675; 
my $obs_long = -110.952;# degrees

my ( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) ;

if ($date) {
    my @dates=split("/", $date, -1);
    $year=$dates[0]+0;
    $mon=$dates[1]+0;
    $mday=$dates[2]+0;
    $yday = cal2dayno($mday, $mon, $year);
}    
else {
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime();
    $year+=1900;
    $yday++;
    $mon++;
}

# die $year, "\t", $mon, "\t", $mday, "\t", $yday;


($tm_mday, $tm_mon, $tm_year) = tomorrow($mday, $mon, $year);
my ($td_sunrise, $td_sunset) = sunrise($year,$mon,$mday,$obs_long,$obs_lat,0,0,-15, 1);
my ($tm_sunrise, $tm_sunset) = sunrise($tm_year,$tm_mon,$tm_mday,$obs_long,$obs_lat,0,0,-15,1 );

my $sunrise = $td_sunrise;
my $sunset = $td_sunset ;

$sunrise_turns = str2turn($sunrise, "H");
$sunset_turns = str2turn($sunset, "H");

# print "\nApproximate sunset  on $year/$mon/$mday: $td_sunset (UTC)\n";
# print "Approximate sunrise on $tm_year/$tm_mon/$tm_mday: $tm_sunrise (UTC)\n\n";
print "\nApproximate sunset  on $year/$mon/$mday: $td_sunset (UTC)\n";
print "Approximate sunrise on $year/$mon/$mday: $td_sunrise (UTC)\n\n";



if( $db_source ) {
    print "Using source $db_source, min elevation $min_elevation degrees\n\n";
}
else {
    if( $txt_list ) {
	print "Using source list $txt_list, min elevation $min_elevation degrees\n\n";
    }
    else {
	print "Using source list $db_list, min elevation $min_elevation degrees\n\n";
    }
}

print "Times are in UTC, local times in brackets\n\n";
print "Source name             next wobble        rise time      culmination time        set time       culmination angle\n";
print "                                           UTC (local)         UTC (local)         UTC (local)\n\n";

# MySQL CONFIG VARIABLES
# CONFIG VARIABLES
my $platform = 'mysql';
my $database = 'VERITAS';
my $host = 'romulus.ucsc.edu';
my $user = 'readonly';
my $pw = '';


#DATA SOURCE NAME
my $dsn = "DBI:$platform:$database:$host";

# PERL MYSQL CONNECT
my $connect = DBI->connect($dsn, $user, $pw) || die "Could not connect to database: $DBI::errstr";
my $statement ;


if( $db_source ) {
    $statement=qq{select tblObserving_Sources.ra, tblObserving_Sources.decl, tblObserving_Sources.source_id from tblObserving_Sources where tblObserving_Sources.source_id LIKE \"$db_source\" order by tblObserving_Sources.ra };
}


else {
    if ($txt_list ) {
	my $sourceOR = "( " ;

	open(LIST, $txt_list) or die("Could not open file $txt_list.");

	foreach $line (<LIST>)  {  
	    chomp($line); 
	    $sourceOR = $sourceOR." TRIM(source_id) = TRIM(\"$line\") OR ";     
	}
	$sourceOR = $sourceOR."source_id LIKE \"bla\" )";
	close(LIST);
#print $sourceOR, "\n";

	$statement = qq{select tblObserving_Sources.ra, tblObserving_Sources.decl, tblObserving_Sources.source_id from tblObserving_Sources where $sourceOR order by ra } ;
    }


    else {
	$statement = qq{select tblObserving_Sources.ra, tblObserving_Sources.decl, tblObserving_Sources.source_id from tblObserving_Sources, tblObserving_Collection where tblObserving_Sources.source_id=tblObserving_Collection.source_id &&  tblObserving_Collection.collection_id = \"$db_list\" order by tblObserving_Sources.ra };
    }
}

my $query_handle = $connect->prepare($statement); 

$query_handle->execute() or die "\n ($DBI::err): $DBI::errstr\n"; 

$query_handle->bind_columns(undef,\$source_ra,\$source_dec,\$source_id );

while ($query_handle->fetch()) { 

    my ($lst_rise, $lst_set) = rise(rad2turn($source_ra), rad2turn($source_dec), deg2turn($obs_lat), deg2turn($min_elevation));
    my ( $time_rise, $time_set, $local_rise, $local_set, $is_circumpolar, $ut_rise, $ut_set );

    #rise returns undef if source never rises, 'Circumpolar' if it never sets.
    if ( ! defined $lst_rise || ! defined $lst_set) {
	$time_rise="";
	$time_set="";
	$local_set="";
	$local_rise="";
	$ut_rise=-999;
	$ut_set=-999;
	   
    }
    else {
	my $mjd_rise = lst2mjd($lst_rise, $yday, $year, deg2turn($obs_long));
	my $mjd_set = lst2mjd($lst_set, $yday, $year, deg2turn($obs_long));  
	    
	($day_r, $month_r, $year_r, $ut_rise) = mjd2cal($mjd_rise);
	($day_s, $month_s, $year_s, $ut_set) = mjd2cal($mjd_set);

	  
	# round to full minutes = 1/(24*60)th of a turn:
	$ut_rise = (sprintf "%.0f", (24*60*$ut_rise)) / (24*60);
	$ut_set = (sprintf "%.0f", (24*60*$ut_set)) / (24*60);
	    
	$time_rise = turn2str($ut_rise, "H",0);
	$time_set = turn2str($ut_set, "H", 0);

	#remove second digits
	substr($time_rise, -3)="";
	substr($time_set, -3)="";

	$local_rise="(".turn2str(($ut_rise>7.0/24) ? $ut_rise-7.0/24: $ut_rise+17.0/24, "H",0);
	$local_set="(".turn2str(($ut_set>7.0/24 )? $ut_set-7.0/24 : $ut_set+17.0/24, "H",0);

	substr($local_rise, -3)=")";
	substr($local_set, -3)= ")";
	       

    }

    my $mjd_transit = lst2mjd( rad2turn( $source_ra ), $yday, $year, deg2turn($obs_long));

    my ($day_t, $month_t, $year_t, $ut_transit) = mjd2cal($mjd_transit);
    $ut_transit = sprintf( "%.0f", (24*60*$ut_transit))/(24*60);
    my $time_transit = turn2str($ut_transit, "H",0);
    substr($time_transit, -3)="";

    my $local_transit = "(".turn2str( ($ut_transit > 7.0/24) ? $ut_transit-7.0/24 : $ut_transit+17.0/24, "H",0);
    substr($local_transit, -3) = ")";

    my $el_transit = 90 - abs( rad2deg($source_dec) - $obs_lat );
    my $az_transit = ( rad2deg($source_dec) > $obs_lat ) ? "N" : "S" ;

       
    if($el_transit > $min_elevation && $time_rise eq "") {
	$is_circumpolar=1;
    }
    else{
	$is_circumpolar=0;
    }

    # print $verbose;
    # print $is_circumpolar;
    # print ( $ut_rise > $sunset_turns && $ut_rise < $sunrise_turns - deg2turn(7) );
    # print ( $ut_set > $sunset_turns + deg2turn(7) && $ut_set < $sunrise_turns );
    # print ( $ut_rise < $sunset_turns && $ut_set> $sunrise_turns );

    if( $verbose || $is_circumpolar || 
	    ( $ut_rise > $sunset_turns && $ut_rise < $sunrise_turns - deg2turn(7) ) ||
	    ( $ut_set > $sunset_turns + deg2turn(7) && $ut_set < $sunrise_turns ) ||
	    ( $ut_rise < $sunset_turns && $ut_set> $sunrise_turns )
	) {

	printf "%-30s %-8s  %5s %7s       %5s %7s       %5s %7s       %.1f° %s\n" , $source_id, &nextWobble( $source_id ), $time_rise,$local_rise, $time_transit, $local_transit, $time_set, $local_set, $el_transit, $az_transit;
    }
}



sub nextWobble {
    my $source_id = $_[0] ;

    my $angle;
    my $distance;

#my @wobblelist = ( "N", "E", "S", "W" );
    my @nextwobblelist = ( "S", "W", "E", "N" );
    
    # MySQL CONFIG VARIABLES
    # CONFIG VARIABLES
    my $platform = 'mysql';
    my $database = 'VERITAS';
    my $host = 'romulus.ucsc.edu';
    my $user = 'readonly';
    my $pw = '';


    #DATA SOURCE NAME
    my $dsn = "DBI:$platform:$database:$host";

    # PERL MYSQL CONNECT
    my $connect = DBI->connect($dsn, $user, $pw) || die "Could not connect to database: $DBI::errstr";

    # EXECUTE THE QUERY FUNCTION

    my $statement = qq{select offset_angle, offset_distance from tblRun_Info where source_id=\"$source_id\" && (run_status = 'ended' || run_status = 'manually_ended' ) and duration > "00:10:00" order by run_id desc limit 1 };

    my $query_handle = $connect->prepare($statement); 

    $query_handle->execute() or die "\n ($DBI::err): $DBI::errstr\n"; 

    $query_handle->bind_columns(undef,\$angle,\$distance);

    $query_handle->fetch();

    $query_handle->finish();
    $connect->disconnect;
 

    if( $distance && $distance>0) {
	"".$distance.@nextwobblelist[$angle/90];
    }
    else {
	"n/a";
    }
}
