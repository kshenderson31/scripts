use strict;
use warnings;

use MIME::Lite;
use Number::Format;
use Getopt::Std;

printChronologicalMessage("DWM Monitor Started", "N");

our $processes=getInstances();

if($processes == 0)
{
	dwmRestart();
}
else
{
	if($processes > 1)
	{
		printChronologicalMessage("DWM Monitor: Multiple Instances Found($processes)", "N");
		my $message="There are $processes instances of DWM currently running. Please execute the appropriate GERS Data Warehouse Manager procedures for addressing multiple instances of Data Warehouse Manager.\n";
		sendMailMessage('[GERS DWM] Multiple Instances Running', $message);	
		killMultipleProcesses();
	}
	else
	{
		printChronologicalMessage("DWM is up", "N");
	}
}
 
printChronologicalMessage("DWM Monitor Ended", "N");

exit 0;


#********************************************************************************************************************************************************************
# Get 
#********************************************************************************************************************************************************************
#
sub getInstances
{
	our $instances=0;
	
	if(!(open(PS,"ps -ef | grep DWM | grep -e com.gers |"))) 
	{
		printChronologicalMessage("DWM Monitor: Failed to Process ps -ef", "N");
		my $message="Failed to open ps -ef\n$!";
		sendMailMessage('[GERS DWM] Failed To Process ps-ef', $! || " ");	
		exit 0;
	}
	
	while ( <PS> )
	{
		
		$instances++
	}

	return $instances;	
}

#********************************************************************************************************************************************************************
# Restart the DWM
#********************************************************************************************************************************************************************
#
sub dwmRestart
{
	my $message="No active instances of DWM were found, restart attempted\n";
	
	printChronologicalMessage("DWM Monitor: No Active Instances, Attempting Restart", "N");
	system("/gers/genret/menu/sup/mac/dwm.watchdog bounce");
	
	if ( $? == -1 )
	{
		printChronologicalMessage("DWM Monitor: Restart Failed", "N");
		printChronologicalMessage("$!", "N");
		$message.="Restart failed: $!\n";
	}
	else
	{
		printChronologicalMessage("DWM Monitor: Restart Command Ended Successfully", "N");
		$message.="Restart successful, please verify DWM is running\n";
	}	
	
	sendMailMessage('[GERS DWM] No Instances Running', $message);
	
	printChronologicalMessage("DWM Monitor: Validating Restart", "N");
	
	sleep(30);
	
	if(getInstances==1)
	{
		printChronologicalMessage("DWM Monitor: Restart Attempt Successful", "N");
		sendMailMessage('[GERS DWM] Restart Successful', 'The restart of DWM was successful and an instance is currently running');
	}
	else
	{
		printChronologicalMessage("DWM Monitor: Restart Attempt Failed", "N");
		sendMailMessage('[GERS DWM] Restart Not Successful', 'The restart of DWM was not successful, please research this now');
	}
}
#********************************************************************************************************************************************************************
# Kill Multiple Processes
#********************************************************************************************************************************************************************
#
sub killMultipleProcesses
{
	if(!(open(PS,"ps -ef | grep DWM | grep -e com.gers |"))) 
	{
		printChronologicalMessage("DWM Monitor: Failed to Process ps -ef", "N");
		my $message="Failed to open ps -ef\n$!";
		sendMailMessage('[GERS DWM] Failed To Process ps-ef', $! || " ");	
		exit 0;
	}
	
	while ( <PS> )
	{
		my ($owner, $pid, $parent)=split(" ", $_);
		printChronologicalMessage("Killing process $pid", "N");
		system("kill -9 $pid");
	}
	
	printChronologicalMessage("Sleeping for 30 seconds", "N");
	sleep(30);
	
	printChronologicalMessage("Restarting Data Warehouse Manager", "N");
	dwmRestart();
	
}

#********************************************************************************************************************************************************************
# Send Email
#********************************************************************************************************************************************************************
#
sub sendMailMessage
{
	our $subject=shift;
	our $msg=shift;

	printChronologicalMessage("Sending email message", "N");

	$msg = MIME::Lite->new(	From=>'"Data Warehouse Manager"<itservicecenter@paradies-na.com>',
    	    				To=>'itservicecenter@paradies-na.com',
    	    				Cc=>'kehenderson@paradies-na.com',
       						Subject=>$subject,
        					Type=>'text/html',
        					Data=>$msg
    					);

	$msg->send('smtp','mail1.tpscorp.theparadiesshops.com', Debug=>0 );

}
#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
sub printChronologicalMessage
{
    my $msg = shift;
    my $log = shift || "Y";

    print "[".getFormattedDateAndTime("mmmm dd, yyyy hr:mn:sc")."] $msg\n";
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