#!/usr/bin/perl

use strict;

use CGI qw(header path_info);
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use File::Temp;
use DateTime;
use DateTime::Format::MySQL; # requires libdatetime-format-mysql-perl 

my @ARGS = split(/&/,$ENV{QUERY_STRING});
my $input = @ARGS[1];

#check the sources
if($input eq ""){
    die "No sources listed";
}
my @sources = split(/:/,$input);

#check the date
my $datetime = @ARGS[0];
my $tempdt = @ARGS[0];
if($datetime eq ""){
    die "No date listed";
}
my @DT = split(/z/, $datetime);
my $date = @DT[0];
$datetime = @DT[0]." ".@DT[1];


#need to fix the midnight bug
my @HMS = split(/:/, @DT[1]);
my @YMD = split(/-/, @DT[0]);
my $dt_temp = DateTime->new( year => @YMD[0],
			     month => @YMD[1],
			     day => @YMD[2],
			     hour => @HMS[0],
			     minute => @HMS[0],
			     second => @HMS[0],
			     );
if($dt_temp->hour < 12){
  $dt_temp->subtract(hours => 24);
  $date = $dt_temp->ymd;
}

my $size = @ARGS[2];
#check for the size
my $GP_COLORS = "x000000 xffffff xffffff";
my $GP_TERM = "";
my $GP_SIZE = "";
my $GP_XLABEL = "";
my $GP_XTICS = "";
my $GP_X2TICS = "";
my $GP_YTICS = "";
if($size eq "tiny"){
    $GP_TERM = "set term png small $GP_COLORS";
    $GP_SIZE = "set size 0.68,0.73";
    $GP_XTICS = "set xtics 21600";
    $GP_X2TICS = "set x2tics 21600";
    $GP_YTICS = "set ytics 20";
}
elsif ($size eq "large"){
    $GP_TERM = "set term png small $GP_COLORS";
}
else{
    die "size incorrect: $size";
}


my $GNUPlot = '/usr/bin/gnuplot';
my $PLOT_LINE = "";
my $outfile = "";

#create a temporary file for the data
my $tmp = new File::Temp();
if(!defined $tmp){die "error: failed to create temporary file\n"};

#create a temporary file for the image
my $image = new File::Temp();
if(!defined $image){die "error: failed to create temporary file\n"};


my $itr = 0;
my $source = "";
my $name = "";
my $output = "";
my $cmd = "";
my @data = "";
my @lines = "";
my $line = "";
foreach $source(@sources){
    # vp 080515 - attempt to cover the GRB alert case... not working yet
    #if(length $source < 3){
	#next;
    #}elsif($source =~ m/FERMI/ || $source =~ m/SWIFT/ || $source =~ m/INTEGRAL/ || $source =~ m/MAXI/){
	#next;
    #}else{
	#if($source =~ m/GRB 201/){
	    #$source = @sources[$itr].":".@sources[$itr+1].":".@sources[$itr+2];
	#}

    split(/,/,$source);   
    $name = @_[0];
    $name =~ s/%20/ /;
    $cmd = "one_src $date --RA @_[1] --DEC @_[2] --radians true --verbose 0";
    $output = `$cmd`;
    if($itr < 1){
	@data = split(/\n/,$output);
	my $itr2 = 0;
	foreach $line (@data){
	    split(/ /,$line);
	    my $dt = DateTime::Format::MySQL->parse_datetime(@_[0]." ".@_[1]);
	    $dt->add(hours => 7);
	    @data[$itr2] = @_[0]." ".@_[1]." ".DateTime::Format::MySQL->format_datetime($dt)." ".@_[2];
	    $itr2++;
	}
    }else{
	@lines = split(/\n/,$output);
	my $itr3 = 0;
	foreach $line (@lines){
	    split(/ /,$line);
	    @data[$itr3] .= " @_[2]";
	    $itr3++;
	}
    }
	
    #generate the plot command here
    if($itr < 1){
	$PLOT_LINE = "p [] [0:90] \'".$tmp->filename()."\' u 1:5 w l axis x1y1 notitle";
	$PLOT_LINE .= ",\'".$tmp->filename()."\' u 3:5 w l axis x2y1 t \"".$name."\"";
    } else {
	my $row = $itr + 5;
	$PLOT_LINE .= ",\'".$tmp->filename()."\' u 1:".$row." w l t \"".$name."\"";
    }
    
    #generate the outfile name
    $outfile .= $name;
    
    $itr++;	
    #}
}

#get the outfile name
my $outfile = $image->filename();

#print the data to the temporary file
foreach(@data){
    print $tmp $_."\n";
}

#Get the start/stop times
$cmd = "html_times $date $date --verbose 0";
$output = `$cmd`;
@data = split(/\t/,$output);
my $startdate = @data[0];
my $stopdate = @data[1];

#Run the gnuplot stuff
open ( GNUPLOT, "|$GNUPlot");
print GNUPLOT <<GCMD;
$GP_TERM
$GP_SIZE
set output "$outfile"
set key below
set ylabel "Elevation (degrees)"
set xlabel "$tempdt"
set x2label "UTC"
set xtics nomirror
set x2tics nomirror
set xdata time
set x2data time
set autoscale xfix
set autoscale x2fix
set format x "%H:%M"
set format x2 "%H:%M"
set timefmt "%Y-%m-%d %H:%M:%S"
set arrow from "$startdate",0 to "$startdate",90 nohead
set arrow from "$stopdate",0 to "$stopdate",90 nohead
set arrow from "$datetime",0 to "$datetime",90 nohead lt 9
set grid
$GP_XLABEL
$GP_XTICS
$GP_X2TICS
$GP_YTICS
$PLOT_LINE
GCMD
close (GNUPLOT);

#print the header
print header(-type => 'image/png');

#display the image
open(IMAGE, $outfile);
print <IMAGE>;
close(IMAGE);


