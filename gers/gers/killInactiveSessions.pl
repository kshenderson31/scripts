#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
# Add status switch

use strict;
#kuse warnings;

use MIME::Lite;
use Getopt::Std;
use DBI;
use DBD::Oracle;

our %opt;

our $sql = <<__SQL__;
SELECT s.sid, s.serial#, s.username, s.status, s.osuser, s.terminal, s.machine, s.program, s.module, TO_CHAR(s.logon_time, 'YYYY-MM-DD HH:MI:SS'), s.last_call_et, CAST(s.last_call_et/60 AS INTEGER) AS min_since_last_sql, p.spid
  FROM v\$session s,
       v\$process p
WHERE s.status = 'INACTIVE'
  AND s.username NOT IN ('SYS', 'SYSTEM', 'DEV', 'OPS\$GENRET')
  AND CAST(s.last_call_et/60 AS INTEGER) > ?
  AND (s.program NOT LIKE 'RFMENU\@\%' OR s.program IS NULL) 
  AND p.addr = s.paddr
ORDER BY last_call_et DESC  
__SQL__

our $sessions=0;
our $ok=0;
our $no=0;
	
#********************************************************************************************************************************************************************
# Flush STDOUT buffer
#********************************************************************************************************************************************************************
#
$|=1;
#********************************************************************************************************************************************************************
# Execute main
#********************************************************************************************************************************************************************
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
	getopts("m:k", \%opt);
	
	$opt{'m'}=$opt{'m'} || 120;
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

	sendErrorMessage("Kill Inactive Sessions Database Error", $message);

	exit 1 if uc $abend eq "Y";
}
#********************************************************************************************************************************************************************
# Database Error
#********************************************************************************************************************************************************************
#
sub killSession
{
	our $pid=shift;
	our $yes=shift || "N";
	
	if($yes eq "Y")
	{
		if($pid != 1)
		{
			system("kill -9 $pid");
		}	
		else
		{
			printChronologicalMessage("PID $pid cannot be killed", "N");
		}
	}
	else
	{
		printChronologicalMessage("Session $pid skipped due to code", "N");
	}
}
#********************************************************************************************************************************************************************
# Database Error
#********************************************************************************************************************************************************************
#
sub grepSession
{
	our $pid=shift;
	our $print=shift || "N";
	our $search=shift || 'f60run';
	
	our $mypid;
	our $parent;
	our $text;
	
	our $command="ps -ef | grep $pid";
	$command.=" | grep $search" if defined $search;
	
	if(!(open(PS,"$command |"))) 
	{
		printChronologicalMessage("Ping execution failed", "N");
		exit 0;
	}
	
	while ( <PS> )
	{
		chomp($_);
		
		next if index(lc $_, "grep") >= 0;
		
		(undef, $mypid, $parent, undef, undef, undef, undef, $text)=split(" ", $_);
		
		next if $mypid != $pid;

		printChronologicalMessage("$_") if $print eq "Y";
	}
	return ($parent, $text);	
}
#********************************************************************************************************************************************************************
# Process Registers 
#********************************************************************************************************************************************************************
#
sub evaluateSession
{
	our $pid=shift;
	our $program=shift;
	our($prog, undef)=split(/\@/,$program);
	
	if(index($program, ".exe") >= 0 || index($program, "sqlplus") >= 0 || index($program, "JDBC") >= 0)
	{
		if(index(lc $program, "ap921") == -1 && index(lc $program, "sa921c") == -1) 
		{
			killSession($pid, "Y") if defined $opt{'k'};
			$ok++;
			printChronologicalMessage("Session $pid killed", "N");
			printChronologicalMessage(" ", "N");	
		}
		else
		{
			$no++;
			printChronologicalMessage("Session skipped", "N");
			printChronologicalMessage(" ", "N");			
		}
	}
	else
	{
		
		if(!(open(PS,"ps -ef | grep $pid |"))) 
		{
			printChronologicalMessage("Ping execution failed", "N");
			exit 0;
		}
		
		while ( <PS> )
		{
			chomp($_);
			
			next if index(lc $_, "grep") >= 0;
			
			our(undef, $mypid, $parent, undef, undef, undef, undef, $text)=split(" ", $_);
			
			next if $mypid != $pid;
			
			if(index(lc $text, "f60run") >= 0)
			{
				killSession($mypid, "Y") if defined $opt{'k'};
				$ok++;
				printChronologicalMessage("$_");
				printChronologicalMessage("Session $mypid killed");
				printChronologicalMessage(" ");
			}
			else
			{
				printChronologicalMessage("$_");
				our(undef, $string)=grepSession($parent, "Y", $prog);
				if(lc $string eq lc $prog)
				{
					if(lc $prog eq "rfmenu")
					{
						printChronologicalMessage("RFMENU found, skipping");
						printChronologicalMessage(" ");
					}
					else
					{
						killSession($parent, "Y") if defined $opt{'k'};
						$ok++;
						printChronologicalMessage("Session $parent killed") if defined $opt{'k'};
						printChronologicalMessage(" ");	
					}
				}
				else
				{
					if($string eq "f60run")
					{
						killSession($mypid, "Y") if defined $opt{'k'};
						$ok++;
						printChronologicalMessage("Session $mypid killed") if defined $opt{'k'};
						printChronologicalMessage(" ");	
					}
					else
					{
						$no++;
						printChronologicalMessage("Session $parent not killed, program mismatch [$string|$prog]");
						printChronologicalMessage(" ");
					}
				}
			}
		}	
	}
}	
#********************************************************************************************************************************************************************
# Process Registers 
#********************************************************************************************************************************************************************
#
sub findSessions
{
	our $databaseHandler=shift;
	our $sid;
	our $serial;
	our $username;
	our $status;
	our $osuser;
	our $terminal;
	our $machine;
	our $program;
	our $module;
	our $logon_time;
	our $lastcall;
	our $minutes;
	our $pid;
	our $statementHandler;
	
	printChronologicalMessage("Determining Sessions to Kill", "N");

	printChronologicalMessage(sprintf("%8s %8s %8s %30s %30s %-19s %5s %-48s", '=' x 8, "=" x 8, "=" x 8, "=" x 30, "=" x 30, "=" x 19, "=" x 5, "=" x 48));
	printChronologicalMessage(sprintf("%8s %8s %8s %-30s %-30s %-19s %5s %-48s", "SID", "Serial", "PID", "Oracle User", "OS User", "Logon Time", "MSINA", "Program [Machine]"));
	printChronologicalMessage(sprintf("%8s %8s %8s %30s %30s %-19s %5s %48s", "=" x 8, "=" x 8, "=" x 8, "=" x 30, "=" x 30, "=" x 19, "=" x 5, "=" x 48));
	
	if(!($statementHandler=$databaseHandler->prepare($sql)))
	{
		databaseError("Prepare failed in findSessions");
	}

	if(!($statementHandler->execute($opt{'m'})))
	{
		databaseError("Statement execution failed in findSessions");
	}

	$statementHandler->bind_columns(undef, \$sid, \$serial, \$username, \$status, \$osuser, \$terminal, \$machine, \$program, \$module, \$logon_time, \$lastcall, \$minutes, \$pid);

	while($statementHandler->fetch()) 
	{
		$sessions++;
		
		our $tag;
		
		$tag=$program || $module || "None";
		$tag.=" [$machine]";
		
		printChronologicalMessage(sprintf("%8d %8d %8d %-30s %-30s %-19s %5d %-48s", $sid, $serial, $pid, $username, $osuser, $logon_time, $minutes, $tag));
		
		evaluateSession($pid, $program);
	}
	$statementHandler->finish;
	
	printChronologicalMessage(sprintf("%8s %8s %8s %-30s %-30s %-19s %5s %48s", "-" x 8, "-" x 8, "-" x 8, "-" x 30, "-" x 30, "-" x 19, "-" x 5, "-" x 48));
	printChronologicalMessage("No sessions found") if $sessions==0;
	printChronologicalMessage("$sessions sessions identified; $ok sessions killed, $no sessions survived") if $sessions>0;
	printChronologicalMessage(sprintf("%8s %8s %8s %-30s %-30s %-19s %5s %48s", "-" x 8, "-" x 8, "-" x 8, "-" x 30, "-" x 30, "-" x 19, "-" x 5, "-" x 48));
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

	printChronologicalMessage("Establishing Connection to Database", "N");

	$ENV{LD_LIBRARY_PATH}="/opt/perl-5.10.1/instantclient/instantclient_11_2";

	if(!($connection=DBI->connect("dbi:Oracle:host=$host;sid=$sid;port=$port", $user, $pass, {RaiseError=>1, AutoCommit=>0})))
	{
		databaseError("Could not establish database connection to $host:$port:$sid");
	} 

	return $connection;	

}
#********************************************************************************************************************************************************************
# sendEmailMessage
#********************************************************************************************************************************************************************
#
sub sendMailMessage
{
	our $subject=shift || "[Success] Kill Inactive Sessions";
	our $body=shift;
	
    our $msg = MIME::Lite->new(
            From    => '"Kill Inactive Sessions Script"<noreply@paradies-na.com>',
            To      => 'kehenderson@paradies-na.com',
            Subject => $subject,
            Type    => 'text/html',
            Data    => $body
        );

	$msg->send('smtp','mail1.tpscorp.theparadiesshops.com', Debug=>0 );
}

#********************************************************************************************************************************************************************
# sendErrorMessage
#********************************************************************************************************************************************************************
#
sub sendErrorMessage
{
	our $subject=shift || "[Failure] Kill Inactive Sessions";
	our $body=shift;
	
    our $msg = MIME::Lite->new(
            From    => '"Kill Inactive Sessions Script"<noreply@paradies-na.com>',
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
# main
#********************************************************************************************************************************************************************
#
sub main
{
	getOptions();
	
	open(LOG, ">>/var/log/gers/sessions.".getFormattedDateAndTime("yyyy-MM-dd").".log");
	
	printChronologicalMessage("$0 Started");
	printChronologicalMessage("Reporting Mode, -k Option Not Used") if not defined $opt{'k'};
	
	our $connection=getDatabaseConnection("paradies", "genret", 1521, undef, undef);

	findSessions($connection);		
			
	printChronologicalMessage("$0 Ended");
	printChronologicalMessage(" ");
	
	close LOG;
}