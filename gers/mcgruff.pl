#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
# Add status switch

use strict;
use warnings;

use Net::Ping;
use MIME::Lite;
use Getopt::Std;

our %opt;
our $ok=0;
our $no=0;
our $okLogin=0;
our $noLogin=0;

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
# Get Command Line Options 
#********************************************************************************************************************************************************************
#
sub getOptions
{
	#A-Alert
	#
	getopts("a:", \%opt);
	
}
#********************************************************************************************************************************************************************
# Process Registers 
#********************************************************************************************************************************************************************
#
sub processRegisters
{
	our $p=shift;
	our $record=shift;

	chomp($record);
	
	our ($phone, $store, $inside, $outside)=split(",", $record);
	our $isuccess=0;

	foreach(1..10)
	{
		if(!($isuccess))
		{
			if($p->ping($inside))
			{
				$isuccess=1;
			}	
		}
	}
	
	our $osuccess=0;

	foreach(1..10)
	{
		if(!($osuccess))
		{
			if($p->ping($outside))
			{
				$osuccess=1;
			}	
		}
	}
	
	printChronologicalMessage(sprintf("%-12s %-20s %-18s %-18s", $phone, $store, "$inside($isuccess)", "$outside($osuccess) "), "N", "N", "Y");
	printChronologicalMessage("***", "N", "N", "N") if $isuccess == 0 && $osuccess == 1;
	printChronologicalMessage(" ", "N", "Y", "N");
}
#*****************************************************************************
# Ping The Register
#*****************************************************************************
#
sub pingRegister
{
	our $ip=shift;
}
#*****************************************************************************
# sendEmailMessage
#*****************************************************************************
#
sub sendMailMessage
{
	our $subject=shift || "[Success] Micros Sales Processing Status";
	our $body=shift;
	
    our $msg = MIME::Lite->new(
            From    => '"Micros Sales Processor"<noreply@paradies-na.com>',
            To      => 'kehenderson@paradies-na.com',
            Subject => $subject,
            Type    => 'text/html',
            Data    => $body
        );

	$msg->send('smtp','mail1.tpscorp.theparadiesshops.com', Debug=>0 );
}

#*****************************************************************************
# sendErrorMessage
#*****************************************************************************
#
sub sendErrorMessage
{
	our $subject=shift || "[Failure] Micros Sales Processing Status";
	our $body=shift;
	
    our $msg = MIME::Lite->new(
            From    => '"Micros Sales Processor"<noreply@paradies-na.com>',
            To      => 'kehenderson@paradies-na.com',
            Subject => $subject,
            Type    => 'text/html',
            Data    => $body
        );

	$msg->send('smtp','mail1.tpscorp.theparadiesshops.com', Debug=>0 );
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
	
	printChronologicalMessage("Parsing Command Line Arguments");

	getOptions();
	
	our $p = Net::Ping->new("icmp", 1, 8);
	
	while(<DATA>)
	{
		chomp($_);
		processRegisters($p, $_);	
	}
		
	printChronologicalMessage("$0 Ended");
	printChronologicalMessage(" ");
}

__DATA__
404-956-7513,Store 1765 Philly,172.25.95.1,24.221.7.197
404-956-7386,Store 1760 Philly,172.25.94.97,24.221.7.189
404-956-7547,Store 1772 Philly,172.25.95.129,24.221.7.215
404-956-9284,Store 1776 Philly,172.25.96.1,24.221.13.128
404-593-7281,Store 0932 El Paso,172.25.12.33,68.25.58.253
404-441-5280,Store 0478 Phoenix,172.25.43.97,24.221.0.233
404-798-6827,Store 1771 Philly,172.25.95.129,24.221.133.111
404-956-6762,Store 1775 Philly,172.25.95.224,24.221.7.113
