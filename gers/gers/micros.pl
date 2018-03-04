#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#

use strict;
use warnings;

use Net::FTP;
use MIME::Lite;
use Getopt::Std;
use DBI;
use DBD::Oracle;

#*****************************************************************************
# Define Global Variables
#*****************************************************************************
#
our %opt;
our $files=0;
our $errors=0;
our $failure;
our $message;

our $sql = <<__SQL__;
SELECT p.store_cd, s.store_name, p.term_num
  FROM polling p,
       store s
WHERE UPPER(p.comments) LIKE '%MICRO%'
  AND p.rgstr_stat_cd = 'A'
  AND s.store_cd = p.store_cd
  AND NOT EXISTS 
   (
    SELECT 'Y' 
      FROM sa_stat s
    WHERE s.store_cd = p.store_cd 
      AND s.term_num = p.term_num
      AND trn_dt = (SELECT TO_CHAR(sysdate-1) FROM dual) 
      AND term_num > '00'
   )  
__SQL__

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
	getopts("dtS", \%opt);
}
#*****************************************************************************
# getSalesFiles
#*****************************************************************************
#
sub getSalesFiles
{
        our $ftp;

		printChronologicalMessage("Instantiating FTP Instance");
        if(!($ftp = Net::FTP->new("ftp1.tpscorp.theparadiesshops.com", Debug=>0, Passive=>0)))
        {
        	printChronologicalMessage("Failed to connect to FTP site");
            printChronologicalMessage("$@");
            exit 10;
        }

        if(!($ftp->login("tpsDiscovery",'M@g3ll@n')))
        {
        	printChronologicalMessage("Login to FTP failed");
            printChronologicalMessage($ftp->message);
            exit 10;
        }
        
        printChronologicalMessage("Changing Directory to /postec/sales");
        $ftp->cwd("/postec/sales") or die "Can't cwd\n";
		
		$message.="<P>Below is the recap of the Micro Sales Process.  All failures are highlighted in red and will requre appropriate followup actions to get sales posted accurately.</P><BR />";
		$message.="<TABLE WIDTH=\"100%\"";       
		$message.="<TR><TH WIDTH=\"15%\">Filename</TH><TH WIDTH=\"15%\">Status</TH><TH WIDTH=\"70%\">Comments</TH></TR>"; 
        printChronologicalMessage("Processing Files");
        my @files = $ftp->ls;
        foreach(@files)
        {
        	next if lc $_ eq "complete";
        	next if lc $_ eq "test";
        	
        	$files++;
        	$failure="";
        	        	
        	if(processFile($ftp, "$_"))
        	{
        		$message.="<TR><TD>$_</TD><TD>Success</TD></TR>";
        	}
        	else
        	{
        		$message.="<TR BGCOLOR=\"#FFCCCC\"><TD>$_</TD><TD>Failed</TD><TD>$failure</TD></TR>";
        	}
        }
        $message.="<TR><TD COLSPAN=3><BR />$files file(s) processed, $errors error(s) encountered</TD></TR>";
        $message.="</TABLE>";
        
		printChronologicalMessage("$files file(s) processed, $errors error(s) encountered");
		
        $ftp->quit;
        
        if($files > 0)
        {
        	if($errors==0)
	        {
	        	sendMailMessage(undef, $message)
	        }
	        else
	        {
	        	sendMailMessage("Micros Sales Processing Status [$errors error(s)]", $message)
	        }	
        }
}
#*****************************************************************************
# sendEmailMessage
#*****************************************************************************
#
sub processFile
{
	my $ftp=shift;
	my $fileName=shift;
	
	my $str=substr($fileName,0,3);
	my $storeNumber=substr($fileName,3,4);
	my $registerNumber=substr($fileName,7,1);
	my ($file, $extension)=split(/\./, $fileName);
	
	printChronologicalMessage("\tProcessing File: $_");
	
	if($str ne "str")
	{
		printChronologicalMessage("\t\tFilename error; file does not begin with 'str'");
		$failure="Filename error; file does not begin with 'str'";
		$errors++;
		return 0;
	}
	
	if(!($storeNumber =~ /^[+-]?\d+$/))
	{
		printChronologicalMessage("\t\tFilename error; store number is not numeric");
		$failure="Filename error; store number is not numeric";
		$errors++;
		return 0;
	}
	
	if($registerNumber ne "A" && $registerNumber ne "O")
	{
		printChronologicalMessage("\t\tFilename error; file does end with and A or an O");
		$failure="Filename error; file does end with and A or an O";
		$errors++;
		return 0;
	}
	
	#-------------------------------------------------------------------------------------
	# If in test mode, do not actually process the files
	#-------------------------------------------------------------------------------------
	#
	if(defined $opt{'t'})
	{
		return 1;	
	}
	
	printChronologicalMessage("\t\tGetting $fileName from FTP Server");
	if(!($ftp->get($fileName, "$file.asc")))
	{
		$errors++;
		printChronologicalMessage("\t\tFTP Get failed for file $fileName failed");
		printChronologicalMessage($ftp->message);
		$failure="FTP Get failed";
		return 0;
	}

	printChronologicalMessage("\t\tDeleting $fileName from FTP Server");
	if(!($ftp->delete($fileName)))
	{
		$errors++;
		printChronologicalMessage("\t\tFTP Delete of file $fileName failed");
		printChronologicalMessage($ftp->message);
		$failure="FTP Delete failed";
		return 0;
	}
	
	printChronologicalMessage("\t\tchowning $file.asc to ");
	if(!(executeCommand("chown genret:dba $file.asc")))
	{
		$errors++;
		printChronologicalMessage("\t\t\tchown of $file.asc failed");
		$failure="chown failed";
		return 0;
	}
	
	printChronologicalMessage("\t\tchmoding $file.asc to 666");
	if(!(executeCommand("chmod 666 $file.asc")))
	{
		$errors++;
		printChronologicalMessage("\t\t\tchmod of $file.asc failed");
		$failure="chmod failed";
		return 0;
	}

	printChronologicalMessage("\t\tBacking up $file.asc to /var/data/micros");
	if(!(executeCommand("cp /gers/genret/datafiles/$file.asc /var/data/micros/$file.asc.$extension")))
	{
		$errors++;
		printChronologicalMessage("\t\t\tcp of $file.asc to /var/data/micros failed");
		$failure="cp failed";
		return 0;
	}

	my $prepup="/gers/genret/opt/path/prepup /gers/genret/datafiles/$file.asc $storeNumber";
	my $callsiu="/gers/genret/opt/path/call_siu $storeNumber";
	
	printChronologicalMessage("\t\tExecuting prepup on $file.asc");
	if(!(executeCommand($prepup)))
	{
		$errors++;
		printChronologicalMessage("\t\t\t$prepup failed");
		$failure="prepup failed";
		return 0;
	}
	else
	{
		printChronologicalMessage("\t\tExecuting call_siu on $file.asc");
		if(!(executeCommand($callsiu)))
		{
			$errors++;
			printChronologicalMessage("\t\t\t$callsiu failed");
			$failure="call_siu failed";
			return 0;
		}	
	}
	
	return 1;
}

#*****************************************************************************
# sendEmailMessage
#*****************************************************************************
#
sub executeCommand
{
	my $command=shift;
	
	printChronologicalMessage("\t\tExecuting: $command");
	
	system($command);
	if ( $? >> 8 != 0 )
	{
		printChronologicalMessage("\t\t\t$command failed");
		printChronologicalMessage("\t\t\t$!");
	  	return 0;
	}
	else
	{
		printChronologicalMessage(sprintf("\t\t\tCommand completed, return code %d", $? >> 8));
		printChronologicalMessage("\t\t\t$!");
	  	return 1;
	}
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

	sendErrorMessage("Micros Sales Process Database Error", $message);

	exit 1 if uc $abend eq "Y";
}
#********************************************************************************************************************************************************************
# Print Message with Date and Time
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
#*****************************************************************************
# Process Sales Files
#*****************************************************************************
#
sub processSalesFiles
{
	printChronologicalMessage("Moving to /gers/genret/datafiles for processing");
		chdir("/gers/genret/datafiles");
	my $dir=`pwd`;
	chomp($dir);
	
	printChronologicalMessage("Working directory is $dir");
	
	if($dir ne "/gers/genret/datafiles")
	{
		printChronologicalMessage("\tWorking directory is not correct, exiting");
		sendErrorMessage(undef, "The Micros Sales Process could not change directories to /gers/genret/datafiles.");
		exit;
	}
	
	printChronologicalMessage("Processing Sales Files");
	getSalesFiles();	
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
# Get Status of Micros Stores in GERS for Prior Day
#********************************************************************************************************************************************************************
#
sub getMicrosStatus
{
	our $databaseHandler=shift;
	our $storeNumber;
	our $storeName;
	our $terminalNumber;
	our $statementHandler;
	our $body;
	
	printChronologicalMessage("Gathering Status Information", "N");

	if(!($statementHandler=$databaseHandler->prepare($sql)))
	{
		databaseError("Prepare Failed in getMicroStatus()");
	}

	if(!($statementHandler->execute()))
	{
		databaseError("Statement Execution Failed in getMicrosStatus()");
	}

	$statementHandler->bind_columns(undef, \$storeNumber, \$storeName, \$terminalNumber);

	printChronologicalMessage("Processing results", "N");

	$body.="<P></P><BR />";
	$body.="<TABLE WIDTH=\"100%\">";
	$body.="<TR><TH WIDTH=\"15%\">Store Number</TH><TH WIDTH=\"70%\">Store Name</TH><TH WIDTH=\"15%\">Register Number</TH></TR>";
	
	our $idx=0;
	while($statementHandler->fetch()) 
	{
		$body.="<TR><TD ALIGN=\"CENTER\">$storeNumber</TD><TD>$storeName</TD><TD ALIGN=\"CENTER\">$terminalNumber</TD></TR>";
		printChronologicalMessage("Sales have not posted for $storeNumber-$terminalNumber  $storeName", "N", "N");
		$idx++;
	}
	
	$body.="</TABLE>";
	
	if($idx > 0)
	{
		sendMailMessage("Micros Missing Sales Files [$idx registers missing]", $body)
	}
	else
	{
		sendMailMessage("Micros Sales Posted", "Sales for all Micros registers has been posted")
	}
	
	$statementHandler->finish;
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
	
	if(defined $opt{'S'})
	{
		our $connection=getDatabaseConnection("paradies", "genret", 1521, undef, undef);
		getMicrosStatus($connection);
	}
	else
	{
		processSalesFiles();
	}

	printChronologicalMessage("$0 Ended");
}