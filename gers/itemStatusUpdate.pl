
#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
# Add status switch

use strict;
use warnings;

use Net::Telnet;
use MIME::Lite;
use Getopt::Std;
use DBI;
use DBD::Oracle;

our %opt;
our %skip;

our $items=0;
our $skus=0;
our $exclusions=0;
our $inactive=0;

our $ok=0;
our $no=0;
our $okLogin=0;
our $noLogin=0;

our $itemQuery = <<__SQL__;
SELECT itm_cd
  FROM gm_itm
WHERE stat_cd IN ('NEW', 'ACT')
  AND itm_cd LIKE ?  
__SQL__

our $skuQuery = <<__SQL__;
SELECT sku_num
  FROM gm_sku
WHERE itm_cd = ?
__SQL__

our $activeQuery = <<__SQL__;
SELECT result
  FROM
    (
        SELECT DISTINCT 1 AS result
          FROM keyrec    k,
               keyrec_ln l,
               gm_po     p,
               gm_po_ln  q,
               sls_per   s,
               sls_per   t
        WHERE l.keyrec_num = l.keyrec_num
          AND p.po_num     = l.po_num 
          AND p.stat_cd    = 'RCVD'
          AND q.po_num     = p.po_num   
          AND q.sku_num    = ?   
          AND SYSDATE BETWEEN s.beg_dt AND s.end_dt
          AND t.yr         = s.yr - 2
          AND t.beg_wk     = s.beg_wk
          AND k.keyrec_dt >= t.beg_dt
        UNION
        SELECT DISTINCT 1
          FROM gm_sku      s,
               gm_itm      i,
               sh_sku_entp e
        WHERE s.sku_num     = ?
          AND i.itm_cd      = s.itm_cd 
          AND e.yr         >= (SELECT yr-1 FROM sls_per WHERE SYSDATE BETWEEN beg_dt AND end_dt)
          AND e.subclass_cd = i.subclass_cd
          AND e.sku_num = s.sku_num
    ) V
__SQL__
    
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
	getopts("m:", \%opt);
	
	$opt{'m'}=$opt{'m'} || '%';
}
#********************************************************************************************************************************************************************
#  
#********************************************************************************************************************************************************************
#
sub loadExclusions
{
	while(<DATA>)
	{
		chomp($_);
		$skip{$_}="Yes";
	}
}
#********************************************************************************************************************************************************************
# Database Error
#********************************************************************************************************************************************************************
#
sub databaseError
{
	our $message=shift;
	our $abend=shift || "Y";

	printChronologicalMessage("A database error has occurred");
	printChronologicalMessage(" ");
	printChronologicalMessage("$message");
	printChronologicalMessage(sprintf("Error Code: %s", $DBI::err));
	printChronologicalMessage(sprintf("State     : %s", $DBI::state));
	printChronologicalMessage(sprintf("Message   : %s", $DBI::errstr));

	$message.="\n\n";
	$message.="A database error has occurred.\n\n";
	$message.="The database error code is ".$DBI::err." and the database state is ".$DBI::state.".  The database message text is below.\n";
	$message.=$DBI::errstr;

	sendErrorMessage("Ping Registers Database Error", $message);

	exit 1 if uc $abend eq "Y";
}
#********************************************************************************************************************************************************************
# Process Items 
#********************************************************************************************************************************************************************
#
sub processItems
{
	our $databaseHandler=shift;
	our $itemNumber;
	
	our $statementHandler;
	our $active=0;
	
	printChronologicalMessage("Gathering data", "N");

	if(!($statementHandler=$databaseHandler->prepare($itemQuery)))
	{
		databaseError("Prepare failed in buildHashes");
	}

	if(!($statementHandler->execute($opt{'m'})))
	{
		databaseError("Statement execution failed in buildHashes");
	}

	$statementHandler->bind_columns(undef, \$itemNumber);

	printChronologicalMessage("Processing results", "N");

	while($statementHandler->fetch()) 
	{
		$items++;
		
		if(defined $skip{$itemNumber})
		{
			$exclusions++;
			printChronologicalMessage("Item Number $itemNumber will be skipped, explicitly excluded");
			next;
		}
		
		printChronologicalMessage("Processing Item $itemNumber");
		if(processSKUs($databaseHandler, $itemNumber))
		{
			printChronologicalMessage("\tItem Number $itemNumber is active, will not be discontinued", "N");
		}
		else
		{
			$inactive++;
			printChronologicalMessage("\tItem Number $itemNumber is NOT active, will be discontinued", "N");
		}
	}

	$statementHandler->finish;
	
	printChronologicalMessage(" ");
	printChronologicalMessage("Items($items)  SKUs($skus)  Inactive($inactive)  Exclusions($exclusions)", "N");
	printChronologicalMessage(" ");
}
#********************************************************************************************************************************************************************
# Process SKUs 
#********************************************************************************************************************************************************************
#
sub processSKUs
{
	our $databaseHandler=shift;
	our $itemNumber=shift;
	our $skuNumber;
	
	our $skuHandler;
	our $active=0;
	
	if(!($skuHandler=$databaseHandler->prepare($skuQuery)))
	{
		databaseError("Prepare failed in buildHashes");
	}

	if(!($skuHandler->execute($itemNumber)))
	{
		databaseError("Statement execution failed in buildHashes");
	}

	$skuHandler->bind_columns(undef, \$skuNumber);

	while($skuHandler->fetch()) 
	{
		$skus++; 
		
		next if $active == 1;
		
		printChronologicalMessage("\tProcessing SKU Number $skuNumber");
		
		$active=isSKUActive($databaseHandler, $skuNumber);
	}

	$skuHandler->finish;
	
	return $active;
}

#********************************************************************************************************************************************************************
# Process SKUs 
#********************************************************************************************************************************************************************
#
sub isSKUActive
{
	our $databaseHandler=shift;
	our $skuNumber=shift;
	
	our $activeHandler;
	our $active;
	
	if(!($activeHandler=$databaseHandler->prepare($activeQuery)))
	{
		databaseError("Prepare failed in buildHashes");
	}

	if(!($activeHandler->execute($skuNumber, $skuNumber)))
	{
		databaseError("Statement execution failed in buildHashes");
	}

	$activeHandler->bind_columns(undef, \$active);
	$activeHandler->fetch();
	$activeHandler->finish;
	
	return $active; 
}
#********************************************************************************************************************************************************************
# Get A Connection to the Database
#********************************************************************************************************************************************************************
#
sub getDatabaseConnection
{
	our $host=shift;
	our $sid=shift;
	our $port=shift || 1521;
	our $user=shift || 'system';
	our $pass=shift || 'genret';
	our $connection;

	printChronologicalMessage("Establishing connection to database", "N");

	$ENV{LD_LIBRARY_PATH}="/opt/perl-5.10.1/instantclient/instantclient_11_2";

	if(!($connection=DBI->connect("dbi:Oracle:host=$host;sid=$sid;port=$port", $user, $pass, {RaiseError=>1, AutoCommit=>0})))
	{
		databaseError("Could not establish database connection to $host:$port:$sid");
	} 

	return $connection;	

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
	
	loadExclusions();
	
	our $connection=getDatabaseConnection("paradies", "genret", 1521, undef, undef);

	processItems($connection);
		
	printChronologicalMessage("$0 Ended");
	printChronologicalMessage(" ");
}

__DATA__    