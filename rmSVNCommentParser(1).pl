#****************************************************************************************************************************************************************
# rmSVNCommentParser.pl
#****************************************************************************************************************************************************************
# svn log --verbose --xml -r {2014-03-01}:{2014-03-31} http://svn.apache.org/repos/asf/commons/proper 
#
#
# To Do List
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
#	Priority		Description
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
#	High			Add SVN Integration
#	High			Add Logging
#	High			Add Comments
#	High			Add Switches
#	Server			Install apache, mysql, logrotate
#	High			Error checking out the butt
#						Numeric check for requirements and defects
#						Validate format of the release number
#
# Maintenance History
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
#	Date			Author				Comments
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
#	3/7/2014		Ken Henderson		Initial Coding
#
#
#
use strict;
use warnings;

use DBI;
use Getopt::Std;
use MIME::Lite;
use XML::Simple;
use Log::Log4perl qw(get_logger :levels);
use Data::Dumper;
#****************************************************************************************************************************************************************
# Global Variables
#****************************************************************************************************************************************************************
#
our $debug=0;

our %opt;

our %commits;
our %message;

our $insertEvent=<<__EVENT__;
INSERT INTO event (eventID, eventRevisionNumber, eventTimeStamp, eventAuthor, eventReleaseID, eventReleaseNotes, eventCommitComment, eventStatusCode, repoID, audCreateTimeStamp, audCreateUserName, audUpdateTimeStamp, audUpdateUserName)
VALUES (DEFAULT, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, 'rmSVNCommentParser', NULL, NULL)
ON DUPLICATE KEY UPDATE audUpdateTimeStamp=CURRENT_TIMESTAMP, 
                        audUpdateUserName='rmSVNCommentParser' 
__EVENT__

our $insertContent=<<__CONTENT__;
INSERT INTO event_content (eventContentID, eventContentName, eventContentActionInd, eventContentType, eventID, audCreateTimeStamp, audCreateUserName, audUpdateTimeStamp, audUpdateUserName)
VALUES (DEFAULT, ?, ?, 'File', ?, CURRENT_TIMESTAMP, 'rmSVNCommentParser', NULL, NULL)
ON DUPLICATE KEY UPDATE audUpdateTimeStamp=CURRENT_TIMESTAMP, 
                        audUpdateUserName='rmSVNCommentParser'
__CONTENT__

our $insertRequirement=<<__REQUIREMENT__;
INSERT INTO event_requirement (eventRequirementID, eventRequirementType, eventRequirementNumber, eventID, audCreateTimeStamp, audCreateUserName, audUpdateTimeStamp, audUpdateUserName)
VALUES (DEFAULT, 'Req', ?, ?, CURRENT_TIMESTAMP, 'rmSVNCommentParser', NULL, NULL)
ON DUPLICATE KEY UPDATE audUpdateTimeStamp=CURRENT_TIMESTAMP, 
                        audUpdateUserName='rmSVNCommentParser'
__REQUIREMENT__

our $insertDefect=<<__DEFECT__;
INSERT INTO event_requirement (eventRequirementID, eventRequirementType, eventRequirementNumber, eventID, audCreateTimeStamp, audCreateUserName, audUpdateTimeStamp, audUpdateUserName)
VALUES (DEFAULT, 'Def', ?, ?, CURRENT_TIMESTAMP, 'rmSVNCommentParser', NULL, NULL)
ON DUPLICATE KEY UPDATE audUpdateTimeStamp=CURRENT_TIMESTAMP, 
                        audUpdateUserName='rmSVNCommentParser'
__DEFECT__

our $insertReviewer=<<__REVIEWER__;
INSERT INTO event_reviewer (eventReviewerID, eventReviewerName, eventID, audCreateTimeStamp, audCreateUserName, audUpdateTimeStamp, audUpdateUserName)
VALUES (DEFAULT, ?, ?, CURRENT_TIMESTAMP, 'rmSVNCommentParser', NULL, NULL)
ON DUPLICATE KEY UPDATE audUpdateTimeStamp=CURRENT_TIMESTAMP, 
                        audUpdateUserName='rmSVNCommentParser'
__REVIEWER__

our $insertError=<<__ERROR__;
INSERT INTO event_error (eventErrorID, eventErrorMessage, eventID, audCreateTimeStamp, audCreateUserName, audUpdateTimeStamp, audUpdateUserName)
VALUES (DEFAULT, ?, ?, CURRENT_TIMESTAMP, 'rmSVNCommentParser', NULL, NULL)
ON DUPLICATE KEY UPDATE audUpdateTimeStamp=CURRENT_TIMESTAMP, 
                        audUpdateUserName='rmSVNCommentParser'
__ERROR__
#****************************************************************************************************************************************************************
# Global Setup
#
# This section instantiates the log4perl logging mechanism.  
#****************************************************************************************************************************************************************
#
our $logger=get_logger();
our $layout = Log::Log4perl::Layout::PatternLayout->new("%d [%-5p] %M{1}(%L) %m [%09r]%n");

our $fileAppender=Log::Log4perl::Appender->new("Log::Dispatch::File", filename=>"$0.log", mode=>"append");
$fileAppender->layout($layout);

our $scrnAppender = Log::Log4perl::Appender->new("Log::Log4perl::Appender::Screen", name => 'dumpy');
$scrnAppender->layout($layout);

$logger->add_appender($fileAppender);
$logger->add_appender($scrnAppender);

$logger->level($DEBUG);

#****************************************************************************************************************************************************************
# Main processing
#****************************************************************************************************************************************************************
#
main();
exit 0;
#****************************************************************************************************************************************************************
# stripSpaces
#****************************************************************************************************************************************************************
#
sub stripSpaces
{
	our $data=shift;
	our $leading=shift || "Y";
	our $trailing=shift || "Y";
	
	return if not defined $data;
	return if length($data) == 0;
	
	$data =~ s/^\s+// if uc $leading eq "Y";
	$data =~ s/\s+$// if uc $trailing eq "Y";
	
	return $data;
}	
#****************************************************************************************************************************************************************
# sendMailMessage
#****************************************************************************************************************************************************************
#
sub sendMailMessage
{
	our $data=shift;
	our $leading=shift || "Y";
	our $trailing=shift || "Y";
	
	$data =~ s/^\s+// if uc $leading eq "Y";
	$data =~ s/\s+$// if uc $trailing eq "Y";
	
	return $data;
}
#****************************************************************************************************************************************************************
# 
#
#****************************************************************************************************************************************************************
#
sub getDatabaseConnection
{
	our $conn;
	
	$logger->info("Establishing Database Connection");
	
	if($conn=DBI->connect('DBI:mysql:rm;host=localhost', 'rm', 'R3l3@$3M3', { RaiseError => 1 }))
	{
		$logger->info("Database Connection Established");
		return $conn
	}
	else
	{
		$logger->error("Database Connection Failed");
		$logger->error($DBI::errstr);
		exit 1;
	}
}
#****************************************************************************************************************************************************************
# 
#
#****************************************************************************************************************************************************************
#
sub insertEvent
{
	our $conn=shift;
	our $revision=shift;
	
	$commits{$revision}{date}=~s/T/ /g;
	$commits{$revision}{date}=~s/Z//g;
	
	$commits{$revision}{notes}=~s/\n/\r\n/g;
	
	our $handle=$conn->prepare($insertEvent);

	$conn->do("DELETE FROM event WHERE eventRevisionNumber=".$revision);
	
	$handle->execute($revision, $commits{$revision}{date}, $commits{$revision}{author}, $commits{$revision}{release}, $commits{$revision}{notes}, $commits{$revision}{msg}, $commits{$revision}{status}, 1);
	
	#----------
	# Get the ID of the row inserted above
	#----------
	#
	$handle=$conn->prepare("SELECT LAST_INSERT_ID()");
	$handle->execute();
	my @result=$handle->fetchrow_array();
	#----------
	# Insert the event contents
	#----------
	#
	our @contents=split(/\n/, $commits{$revision}{files});
	foreach(@contents)
	{
		$handle=$conn->prepare($insertContent);
		$handle->execute(substr($_, 4), substr($_, 1, 1), $result[0]);
	}
	#----------
	# Insert the event requirements
	#----------
	#
	our @requirements=split(/\n/, $commits{$revision}{requirements});
	foreach(@requirements)
	{
		$handle=$conn->prepare($insertRequirement);
		$handle->execute($_, $result[0]);
	}
	
	our @defects=split(/\n/, $commits{$revision}{defects});
	foreach(@defects)
	{
		$handle=$conn->prepare($insertDefect);
		$handle->execute($_, $result[0]);
	}
	#----------
	# Insert the event reviewers
	#----------
	#	
	our @reviewers=split(/\n/, $commits{$revision}{reviewers});
	foreach(@reviewers)
	{
		$handle=$conn->prepare($insertReviewer);
		$handle->execute($_, $result[0]);
	}
	#----------
	# Insert the event errors
	#----------
	#	
	our @errors=split(/\n/, $commits{$revision}{errors});
	foreach(@errors)
	{
		$handle=$conn->prepare($insertError);
		$handle->execute($_, $result[0]);
	}
#	$commits{$key}{status}="OK";
#		$commits{$key}{author}=$xml->{logentry}{$key}->{author};
#		$commits{$key}{date}=$xml->{logentry}{$key}->{date};
#		$commits{$key}{msg}=$xml->{logentry}{$key}->{msg};
#		$commits{$key}{files}=$files;
#	, $dt, $auth, 'REL', $commits{$key}{notes}, 1
#	$commits{$revision}{release}=$release;
#	$commits{$revision}{requirements}=$requirements;
#	$commits{$revision}{defects}=$defects;
#	$commits{$revision}{reviewers}=$reviewers;
#	$commits{$revision}{notes}=$notes;
	
}
#****************************************************************************************************************************************************************
# 
#
#****************************************************************************************************************************************************************
#
sub closeDatabaseConnection
{
	our $conn=shift;
	
	$logger->info("Closing Database Connection");
	if(!($conn->disconnect()))
	{
		$logger->error("Closing Database Connection Failed");
		$logger->error($DBI::errstr);
	}
}
#****************************************************************************************************************************************************************
# 
#
#****************************************************************************************************************************************************************
#
sub generateActivityReport
{
	
}
#****************************************************************************************************************************************************************
# 
#
#****************************************************************************************************************************************************************
#
sub generateViolationReport
{
	
}
#****************************************************************************************************************************************************************
# parseRelease
#
#****************************************************************************************************************************************************************
#
sub parseRelease
{
	our $line=shift;
	our $return=shift;
	our $rl;
	
	(undef, $rl)=split(/\=/, $line);
	
	$rl=stripSpaces($rl);
	
	$return.=$rl;
			
	return $return;	
}	
#****************************************************************************************************************************************************************
# parseRequirements
#
# This subroutine will pasre the requirements lines from the Subversion commit comment.
#
# The comment line should be in the format of R=n,n,n.  If this format is found, the requirements will be parsed and stored for reporting later in the process
#****************************************************************************************************************************************************************
#
sub parseRequirements
{
	our $line=shift;
	our $return=shift;
	our $reqs;
	our @rqmt;
	
	(undef, $reqs)=split(/\=/, $line);
	
	if(defined $reqs)
	{
		@rqmt=split(/\,/, $reqs);
	
		foreach(@rqmt)
		{
			our $rq=$_;
			
			$rq=stripSpaces($rq);
			$rq=stripSpaces($rq);
			
			$return.="$rq\n";
		}	
	}
	
	return $return;	
}
#****************************************************************************************************************************************************************
# parseDefects 
#****************************************************************************************************************************************************************
#
sub parseDefects
{
	our $line=shift;
	our $return=shift;
	our $defs;
	our @dfct;
	
	(undef, $defs)=split("\=", $line);
	
	if(defined $defs)
	{
		@dfct=split("\,", $defs);
		
		foreach(@dfct)
		{
			our $df=$_;
			
			$df=stripSpaces($df);
			$df=stripSpaces($df);
			
			$return.="$df\n";
		}
	}
	return $return;
}
#****************************************************************************************************************************************************************
# parseReviewer
#****************************************************************************************************************************************************************
#
sub parseReviewer
{
	our $line=shift;
	our $return=shift;
	our @rvwrs;
	
	@rvwrs=split("\,", $line);
	
	foreach(@rvwrs)
	{
		our $rvwr=$_;
		
		$rvwr=stripSpaces($rvwr);
		$rvwr=stripSpaces($rvwr);
		
		$return.="$rvwr\n";
	}
	return $return;
}
#****************************************************************************************************************************************************************
# 
#****************************************************************************************************************************************************************
#
sub parseReleaseNotes
{
	our $line=shift;
	our $return=shift;	
	
	$return.="$line\n";
}
#****************************************************************************************************************************************************************
# 
#****************************************************************************************************************************************************************
#
sub parseCommitComments
{
	our $revision=shift;
	our $comments=shift;
	
	our @message=split("\n", $comments);
	
	our $phase="XXX";
	our $release="";
	our $requirements="";
	our $defects="";
	our $reviewers="";
	our $notes="";
	our $error=0;
	our @errors;
	
	
	foreach(@message)
	{
		chomp($_);
		
		my $data=$_;
		
		$data=stripSpaces($data);
		
		next if not defined $data;
		next if length($data) == 0;
		
		if(index(uc $_, "*PRO") >= 0)
		{
			$phase="PRO";
			next;
		}
		else
		{
			if(index(uc $_, "*BRE") >= 0 || index(uc $_, "*SRE") >= 0)
			{
				$phase="REQ";
				next;
			}
			else
			{
				if(index(uc $_, "*DEF") >= 0)
				{
					$phase="DEF";
					next;
				}
				else
				{
					if(index(uc $_, "*REV") >= 0)
					{
						$phase="REV";
						next;
					}
					else
					{
						if(index(uc $_, "*REL") >= 0)
						{
							$phase="REL";
							next;
						}
					}
				}	
			}
			
		}
		
		$release=parseRelease($_, $release) 				if defined $phase && $phase eq "PRO";
		$requirements=parseRequirements($_, $requirements) 	if defined $phase && $phase eq "REQ";
		$defects=parseDefects($_, $defects) 				if defined $phase && $phase eq "DEF";
		$reviewers=parseReviewer($_, $reviewers) 			if defined $phase && $phase eq "REV";
		$notes=parseReleaseNotes($_, $notes) 				if defined $phase && $phase eq "REL";
		
	} # End while
	
	$logger->debug("Release") 		if $debug;
	$logger->debug($release) 		if $debug && defined $release;
	
	if(defined $release)
	{
		if(length($release) == 0)
		{
			$error=1;
			$commits{$revision}{errors}.="No release found in commit comments\n";
			$logger->warn("[$revision $commits{$revision}{author}] No release found in commit comments");
			$commits{$revision}{status}="No";
		}	
	}
	else
	{
		$error=1;
		$commits{$revision}{errors}.="No release found in commit comments\n";
		$logger->warn("[$revision $commits{$revision}{author}] No release found in commit comments");
		$commits{$revision}{status}="No";
	}
	
	$logger->debug("Requirements") 	if $debug;
	$logger->debug($requirements) 	if $debug && defined $requirements;
	
	$logger->debug("Defects") 		if $debug;
	$logger->debug($defects) 		if $debug && defined $defects;
		
	our $reqError=1;
	
	if(defined $requirements)
	{
		if(length($requirements) > 0)
		{
			$reqError=0;
		}
	}
	
	if(defined $defects)
	{
		if(length($defects) > 0)
		{
			$reqError=0;
		}
	}
	
	if($reqError)
	{
		$error=1;
		$commits{$revision}{errors}.="No requirements or defects found in commit comments\n";
		$logger->warn("[$revision $commits{$revision}{author}] No requirements or defects found in commit comments");
		$commits{$revision}{status}="No";
	}
	
	$logger->debug("Reviewers") 	if $debug;
	$logger->debug($reviewers) 		if $debug && defined $reviewers;
	
	if(defined $reviewers)
	{
		if(length($reviewers) == 0)
		{
			$error=1;
			$commits{$revision}{errors}.="No reviewers found in commit comments\n";
			$logger->warn("[$revision $commits{$revision}{author}] No reviewers found in commit comments");
			$commits{$revision}{status}="No";
		}	
	}
	else
	{
		$error=1;
		$commits{$revision}{errors}.="No reviewers found in commit comments\n";
		$logger->warn("[$revision $commits{$revision}{author}] No reviewers found in commit comments");
		$commits{$revision}{status}="No";
	}
	
	$logger->debug("Notes") 		if $debug;
	$logger->debug($notes) 			if $debug && defined $notes;
	
	if(defined $notes)
	{
		if(length($notes) == 0)
		{
			$error=1;
			$commits{$revision}{errors}.="No release notes found in commit comments\n";
			$logger->warn("[$revision $commits{$revision}{author}] No release notes found in commit comments");
			$commits{$revision}{status}="No";
		}	
	}
	else
	{
		$error=1;
		$commits{$revision}{errors}.="No release notes found in commit comments\n";
		$logger->warn("[$revision $commits{$revision}{author}] No release notes found in commit comments");
		$commits{$revision}{status}="No";
	}
	
	$commits{$revision}{release}=$release;
	$commits{$revision}{requirements}=$requirements;
	$commits{$revision}{defects}=$defects;
	$commits{$revision}{reviewers}=$reviewers;
	$commits{$revision}{notes}=$notes;
}
#****************************************************************************************************************************************************************
# parseLogFile
#****************************************************************************************************************************************************************
#
sub parseLogFile
{
	our $path=shift;
	our $conn=shift;
	
	our $xml = XMLin($path, KeyAttr => { logentry => 'revision', path=>'content' }, ForceArray => [ 'path' ]);
	our $rev;
	our $auth;
	our $msg;
	our $dt;
	our $files;
	our $revs=0;
	
	print Dumper($xml) if defined $opt{'D'} && uc $opt{'D'} eq 'Y';
	#----------
	#
	#----------
	#
	foreach our $key(sort keys %{$xml->{logentry}})
	{
		next if $revs >= $opt{'c'};
		
		$revs++;
		
		$rev=$key;
		$auth=$xml->{logentry}{$key}->{author};
		$dt=$xml->{logentry}{$key}->{date};
		$msg=$xml->{logentry}{$key}->{msg};
		
		#----------
		#
		#----------
		#
		undef $files;
		foreach our $fkey(keys %{$xml->{logentry}{$key}->{paths}->{path}})
		{
			
			our $svnPath=substr($fkey, 0, rindex($fkey, "/"));
			our $svnFile=substr($fkey, rindex($fkey, "/")+1, length($fkey)-rindex($fkey, "/"));
			####print "$fkey $svnPath $svnFile\n";
			$files.="[";
			$files.=$xml->{logentry}{$key}->{paths}->{path}{$fkey}->{action};
			$files.="] ";
			$files.="$fkey\n"
		}
		
		$commits{$key}{status}="Ok";
		$commits{$key}{author}=$xml->{logentry}{$key}->{author};
		$commits{$key}{date}=$xml->{logentry}{$key}->{date};
		$commits{$key}{msg}=$xml->{logentry}{$key}->{msg};
		$commits{$key}{files}=$files;
		
		$logger->info("Parsing Revision $key");
		parseCommitComments($key, $xml->{logentry}{$key}->{msg});
		
		$logger->info("Committing Revision $key to Database");
		insertEvent($conn, $key);
		$logger->info("Database Updated Successfully"); 
		
	}
}
#****************************************************************************************************************************************************************
# 
#****************************************************************************************************************************************************************
#
sub parseLogEntries
{
	our $dir=shift || "/var/vzt/rm/svn";
	our $conn=shift;
	
	opendir(DIR, $dir) || die;
	
    while(our $file=readdir DIR) 
    {
    	next if -d $file;
    	$logger->info("Processing $file");
    	parseLogFile("$dir/$file", $conn);
    }
    
    closedir DIR;	
}
#****************************************************************************************************************************************************************
# 
#****************************************************************************************************************************************************************
#
sub getOptions
{
	getopt('c:dD', \%opt);
	
	$opt{'c'}=$opt{'c'} || 9999999;
	
	$debug=1 										if defined $opt{'d'} && uc $opt{'d'} eq 'Y';
	$logger->debug("Debug has been activated") 		if $debug;	
}
#****************************************************************************************************************************************************************
# 
#****************************************************************************************************************************************************************
#
sub main
{
	$logger->info(" ");
	$logger->info("$0 process started");
	
	getOptions();
	
	our $dbConnection=getDatabaseConnection();

	parseLogEntries("/var/vzt/rm/svn", $dbConnection);
	
	generateViolationReport($dbConnection);
	generateActivityReport($dbConnection);
	
	closeDatabaseConnection($dbConnection);
	
	$logger->info("$0 process ended");
	
	print Dumper(%commits) if defined $opt{'D'} && uc $opt{'D'} eq 'Y';
}