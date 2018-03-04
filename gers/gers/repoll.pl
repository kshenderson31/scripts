use strict;
use warnings;
use Getopt::Std;
use MIME::Lite;
use DBI;
use DBD::Oracle;

$ENV{MLINK}='/gers/mlink;/prod/mlink';

our %opt;
our %exception;
our $command;
our $site;
our $sql = <<__SQL__;
SELECT p.store_cd,
       CASE
         WHEN p.term_num = '01' THEN 'A'
         WHEN p.term_num = '02' THEN 'B'
         WHEN p.term_num = '03' THEN 'C'
         WHEN p.term_num = '04' THEN 'D'
         WHEN p.term_num = '05' THEN 'E'
         WHEN p.term_num = '06' THEN 'F'
         WHEN p.term_num = '07' THEN 'G'
         WHEN p.term_num = '08' THEN 'H'
         WHEN p.term_num = '09' THEN 'I'
         WHEN p.term_num = '10' THEN 'J'
         WHEN p.term_num = '11' THEN 'K'
         WHEN p.term_num = '12' THEN 'L'
         WHEN p.term_num = '13' THEN 'M'
         WHEN p.term_num = '14' THEN 'N'
         WHEN p.term_num = '15' THEN 'O'
         WHEN p.term_num = '16' THEN 'P'
         WHEN p.term_num = '17' THEN 'Q'
         WHEN p.term_num = '18' THEN 'R'
         WHEN p.term_num = '19' THEN 'S'
         WHEN p.term_num = '20' THEN 'T'
         WHEN p.term_num = '21' THEN 'U'
         WHEN p.term_num = '22' THEN 'V'
         WHEN p.term_num = '23' THEN 'W'
         WHEN p.term_num = '24' THEN 'X'
         WHEN p.term_num = '25' THEN 'Y'
         WHEN p.term_num = '26' THEN 'Z'
       END AS term_num  
  FROM polling_status p
WHERE p.polling_dt = TO_CHAR(SYSDATE-1)
  AND p.poll_stat_cd = 'ER'  
ORDER BY 1, 2
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
    
    print LOG "[".getFormattedDateAndTime("mmmm dd, yyyy hr:mn:sc")."] " if uc $ts eq "Y";
    print LOG $msg;
    print LOG "\n" if uc $eol eq "Y";
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
#********************************************************************************************************************************************************************
# Get Command Line Options 
#********************************************************************************************************************************************************************
#
sub getOptions
{
	getopts("R:", \%opt);

	$opt{'R'}=uc $opt{'R'} if defined $opt{'R'};
	
	printChronologicalMessage("Processing All Registers Not Polled") if not defined $opt{'R'};
	printChronologicalMessage("Processing Register $opt{'R'} Only") if defined $opt{'R'};
	
}
#********************************************************************************************************************************************************************
#  
#********************************************************************************************************************************************************************
#
sub loadExceptions
{
	
	while(<DATA>)
	{
		chomp($_);
	
		our ($register, $acmsite)=split(/\|/, $_);
		
		$exception{uc $register}=$acmsite;
	}
}

#********************************************************************************************************************************************************************
#  
#********************************************************************************************************************************************************************
#
sub repollRegisters
{
	our $databaseHandler=shift;
	our $store;
	our $terminal;
	our $statementHandler;
	
	printChronologicalMessage("Preparing Statement");
	if(!($statementHandler=$databaseHandler->prepare($sql)))
	{
		databaseError("Prepare failed in buildHashes");
	}

	printChronologicalMessage("Executing Statment");
	if(!($statementHandler->execute()))
	{
		databaseError("Statement execution failed in buildHashes");
	}

	$statementHandler->bind_columns(undef, \$store, \$terminal);

	printChronologicalMessage("Processing Result Cursor", "N");

	while($statementHandler->fetch()) 
	{
		next if defined $opt{'R'} && $opt{'R'} ne "$store$terminal";
		
		printChronologicalMessage("Repolling $store$terminal");
		
		$site="$store$terminal";
		$site=$exception{$site} if defined $exception{$site};
		
		#$command="mlink -h amdemand -r3 -p2 -v genret start $site A";
		$command="mlink -h amdemand -v genret start $site A";
		
		printChronologicalMessage("Invoking MLINK Command: $command");
		
		if(!(open(ACM,"$command |"))) 
		{
			printChronologicalMessage("MLINK Invocation Failed", "N");
			exit 0;
		}	
		
		while (<ACM>)
		{
			chomp($_);
			
			$_=~s/\n//g;
			
			printChronologicalMessage("$_");
		}
	}
	
	printChronologicalMessage(" ", "N");
	
	$statementHandler->finish;
}
#*****************************************************************************
# main
#*****************************************************************************
#
sub main
{
	open(LOG, ">>/var/log/gers/repoll.".getFormattedDateAndTime("yyyy-MM-dd").".log");
	
	printChronologicalMessage("$0 Started");
	
	printChronologicalMessage("Parsing Command Line Arguments");
	getOptions();
	
	our $connection=getDatabaseConnection("paradies", "genret", 1521, undef, undef);
	
	loadExceptions();
	repollRegisters($connection);
		
	printChronologicalMessage("$0 Ended");
	printChronologicalMessage(" ");	
	
	close LOG;
}
__DATA__
0033A|0033
0039A|0039
0048A|0048
0052A|0052
0062A|0062
0067A|0067
0070A|0070
0078A|0078
0084A|0084
0086A|0086
0093A|0093
0114A|0114
0133A|0133
0135A|0135
0136A|0136
0179A|0179
0192A|0192
0201A|0201
0203A|0203
0212A|0212
0214A|0214
0215A|0215
0224A|0224
0231A|0231
0233A|0233
0252A|0252
0253A|0253
0254A|0254
0257A|0257
0265A|0265
0277A|0277
0278A|0278
0280A|0280
0281A|0281
0286A|0286
0288A|0288
0289A|0289
0290A|0290
0304A|0304
0361A|0361
0364A|0364
0379A|0379
0380A|0380
0392A|0392
0394A|0394
0401A|0401
0410A|0410
0412A|0412
0413A|0413
0415A|0415
0433A|0433
0442A|0442
0444A|0444
0445A|0445
0454A|0454
0456A|0456
0458A|0458
0466A|0466
0467A|0467
0468A|0468
0486A|0486
0494A|0494
0501A|0501
0503A|0503
0510A|0510
0512A|0512
0515A|0515
0518A|0518
0541A|0541
0543A|0543
0544A|0544
0553A|0553
0555A|0555
0557A|0557
0558A|0558
0588A|0588
0619A|0619
0642A|0642
0644A|0644
0662A|0662
0666A|0666
0690A|0690
0695A|0695
0737A|0737
0743A|0743
0747A|0747
0759A|0759
0771A|0771
0772A|0772
0810A|0810
0812A|0812
0813A|0813
0821A|0821
0883A|0883
0884A|0884
0921A|0921
1773A|1773
1775A|1775
1777A|1777