#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
# 
use strict;
use warnings;

use Net::Ping;
use MIME::Lite;
use Getopt::Std;
use DBI;
use DBD::Oracle;

our %opt;
#*****************************************************************************
# Flush STDOUT buffer
#*****************************************************************************
#
$|=1;
#*****************************************************************************
# Execute main
#*****************************************************************************
#
main();
exit 0;
#********************************************************************************************************************************************************************
# Process Registers 
#********************************************************************************************************************************************************************
#
sub validateAddresses
{
	our $databaseHandler=shift;
	our $location;
	our $storeNumber;
	our $terminalNumber;
	our $ipAddress;
	our $registerStatusCode;
	our $statementHandler;
	
	printChronologicalMessage("Gathering data", "N");


	while(<DATA>)
	{
		chomp($_);
		
		our $ip=$_;
		
		print "=" x 80 ."\n";
		print "$ip\n";
		print "=" x 80 ."\n";
		
		if(!(open(PS,"ping -c 10 -w 1 $ip |"))) 
		{
			printChronologicalMessage("Ping execution failed", "N");
			exit 0;
		}
		
		while ( <PS> )
		{
			chomp($_);
			printChronologicalMessage("$_", "N");
		}
		
		print " \n";
		
		if(!(open(PS,"traceroute $ip |"))) 
		{
			printChronologicalMessage("Ping execution failed", "N");
			exit 0;
		}
		
		while ( <PS> )
		{
			chomp($_);
			printChronologicalMessage("$_", "N");
		}
		
		print " \n";
		
		print "=" x 80 ."\n";
		print " \n";
	}
}
#********************************************************************************************************************************************************************
# Print Message with Date and Time
#********************************************************************************************************************************************************************
#
sub printChronologicalMessage
{
    my $msg = shift;
    my $log = shift || "Y";
    my $eol = shift || "Y";
    my $ts  = shift || "Y";

    print "[".getFormattedDateAndTime("mmmm dd, yyyy hr:mn:sc")."] " if uc $ts eq "Y";
    print $msg;
    print "\n" if uc $eol eq "Y";
}
#********************************************************************************************************************************************************************
# Get the date and time
#********************************************************************************************************************************************************************
#
sub getFormattedDateAndTime
{
	my $format     = shift;

	my @monthAbbr  = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
	my @monthNames = qw( January February March April May June July August September October November December );
	my @days       = qw( Sunday Monday Tuesday Wednesday Thursday Friday Saturday );
	my @daysAbbr   = qw( Sun Mon Tue Wed Thu Fri Sat );
	my %numbers;

	for my $number(0..60)
	{
		$numbers{$number} = sprintf("%02d", $number);
        if($number < 10)
        {
            my $n = sprintf("%02d", $number);
            $numbers{$n} = $n;
        }
	}

	my ($currSeconds, $currMinutes,$currHour, $currDay, $currMonth, $currYear, $currWeekDay, $currDayOfYear, $isdst) = localtime(time);	

	$currYear += 1900;
	$currMonth++;

	my $mthIndex = $currMonth - 1;
	my $return   = $format;
	my $yr       = substr($currYear,2,2);
	my $hrFmtd   = sprintf("%2d", $currHour);

	$currMonth = sprintf("%02d", $currMonth);
	$currDay   = sprintf("%02d", $currDay);
	$return =~ s/yyyy/$currYear/g;
	$return =~ s/yy/$yr/g;
	$return =~ s/mmmm/$monthNames[$mthIndex]/g;
	$return =~ s/mmm/$monthAbbr[$mthIndex]/g;
	$return =~ s/mm/$currMonth/g;
	$return =~ s/MM/$numbers{$currMonth}/g;
	$return =~ s/dd/$numbers{$currDay}/g;
	$return =~ s/d/$currDay/g;
	$return =~ s/www/$days[$currWeekDay]/g;
	$return =~ s/ww/$daysAbbr[$currWeekDay]/g;
	$return =~ s/hr/$numbers{$currHour}/g;
	$return =~ s/mn/$numbers{$currMinutes}/g;
	$return =~ s/sc/$numbers{$currSeconds}/g;
	$return =~ s/j/$currDayOfYear/g;

	return $return;
}
#*****************************************************************************
# main
#*****************************************************************************
#
sub main
{
	printChronologicalMessage("$0 Started");
	
	validateAddresses();
		
	printChronologicalMessage("$0 Ended");
	printChronologicalMessage(" ");
}

__DATA__
172.20.1.89
70.155.115.242
70.158.102.19
74.246.140.242
172.20.1.161
172.20.1.241
66.147.60.226
172.20.1.61
172.20.1.97
172.20.1.77
172.20.1.41
172.20.1.237
64.144.44.250
172.20.1.153
172.20.1.133
71.170.50.58
172.20.1.9
207.28.250.84
172.20.1.25
172.20.1.17
172.20.1.205
172.20.1.141
172.20.1.145
172.20.1.101
172.20.1.225
68.93.95.129
172.20.1.85
68.25.89.200
172.20.1.93
74.247.192.90
172.20.1.65
166.148.20.245
208.13.143.236
67.77.44.12
98.19.106.57
64.218.250.234
172.20.1.57
108.64.90.121
108.178.219.34
97.64.182.172
172.20.1.137
172.20.1.221 
68.153.210.82
68.157.80.154
70.155.44.242
71.242.122.146
172.20.1.37
172.20.1.69
172.20.1.109
172.20.1.129
64.233.127.138
172.20.1.73
69.33.189.2
172.20.1.21
69.109.26.217
172.20.1.81
69.69.15.24
71.2.224.40
172.20.1.49
65.160.187.6
172.20.1.149
172.20.1.29
216.9.106.159
216.9.107.74
172.20.1.5
166.239.25.155
67.135.118.33
67.135.118.36
67.135.118.40
172.20.1.105
172.20.1.157
172.20.1.45
68.167.157.194
66.14.182.80
70.91.117.81
172.20.1.33
216.187.237.157
166.143.251.194
24.221.17.237
216.232.84.159