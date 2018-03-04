#****************************************************************************************************************************************************************
# rmSVNCommentParser.pl
#****************************************************************************************************************************************************************
# svn log --verbose --xml -r {2014-03-01}:{2014-03-31} http://svn.apache.org/repos/asf/commons/proper 
#
# Change the key to date, revision number and author to allow same revision number across repositories.
#
# To Do List
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
#	Priority		Description
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
#	High			Add Comments
#	High			Add Switches
#	High			Add lockfile Capability
#	Server			Install apache, mysql, logrotate
#	High			Error checking out the butt
#						Numeric check for requirements and defects
#						Validate format of the release number  [Done]
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
use POSIX;
use Getopt::Std;
use XML::Simple;
use File::Slurp;
use File::Copy;
use Email::Send;  
use Email::Simple::Markdown;

use Log::Log4perl qw(get_logger :levels); 
use Data::Dumper;
#****************************************************************************************************************************************************************
# Global Variables
#****************************************************************************************************************************************************************
#
our $debug=0;

our %opt;

our %commits;
our %repo;
our %message;

our %rptSummary;
our %rptActivity;
our %rptErrors;

our $deleteEvent=<<__DELETE__;
DELETE FROM event 
  WHERE eventRevisionNumber=?
    AND eventTimeStamp=?
    AND eventAuthor=?
__DELETE__

our $selectEvent=<<__SELECT__;
SELECT eventID FROM event 
  WHERE eventRevisionNumber=?
    AND eventTimeStamp=?
    AND eventAuthor=?
__SELECT__

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
INSERT INTO event_requirement (eventRequirementID, eventRequirementType, eventRequirementNumber, isDefectFlag, eventID, audCreateTimeStamp, audCreateUserName, audUpdateTimeStamp, audUpdateUserName)
VALUES (DEFAULT, ?, ?, 0, ?, CURRENT_TIMESTAMP, 'rmSVNCommentParser', NULL, NULL)
ON DUPLICATE KEY UPDATE audUpdateTimeStamp=CURRENT_TIMESTAMP, 
                        audUpdateUserName='rmSVNCommentParser'
__REQUIREMENT__

our $insertDefect=<<__DEFECT__;
INSERT INTO event_requirement (eventRequirementID, eventRequirementType, eventRequirementNumber, isDefectFlag, eventID, audCreateTimeStamp, audCreateUserName, audUpdateTimeStamp, audUpdateUserName)
VALUES (DEFAULT, 'QC', ?, 1, ?, CURRENT_TIMESTAMP, 'rmSVNCommentParser', NULL, NULL)
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
our $today=strftime "%Y-%m-%d", localtime;
our $logger=get_logger();
our $layout = Log::Log4perl::Layout::PatternLayout->new("%d [%-5p] %M{1}(%L) %m [%09r]%n");

our $fileAppender=Log::Log4perl::Appender->new("Log::Dispatch::File", filename=>"$0-$today.log", mode=>"append");
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
	our $from=shift;
	our $to=shift;
	our $subj=shift;
	our $body=shift;
	
	
	$logger->info("Sending $subj Message");
	# atlexcpo04c.hughestelematics.net
	our $mail=Email::Simple::Markdown->create(header=>[From=>$from, To=>$to, Subject=>$subj,], body=>$body);
  	our $mailer = Email::Send->new(
      				{   
      					mailer      => 'SMTP',
          				mailer_args => [Host=>'atlexcpo04c.hughestelematics.net']
      				}
  	);
  	
  eval { $mailer->send($mail) };
  die "Error sending email: $@" if $@;
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
	
	if($conn=DBI->connect('DBI:mysql:rm;host=localhost', 'rm', 'R3l3@$3M3', {RaiseError=>0, PrintError=>0 }))
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

	#----------
	# Delete to avoid duplicate inserts
	#----------
	#
	our $handle=$conn->prepare($deleteEvent);
	if(!($handle->execute($revision, $commits{$revision}{date}, $commits{$revision}{author})))
	{	
		$logger->error("Delete of revision $revision failed");
		$logger->error($DBI::errstr);
		exit 1;
	}
	
	$handle=$conn->prepare($insertEvent);
	if(!($handle->execute($revision, $commits{$revision}{date}, $commits{$revision}{author}, $commits{$revision}{release}, $commits{$revision}{notes}, $commits{$revision}{msg}, $commits{$revision}{status}, 1)))
	{
		$logger->error("Insert into rm.event failed for revision $revision");
		$logger->error($DBI::errstr);
		exit 1;
	}
	
	
	if(!(defined $conn->{mysql_insertid}))
	{
		$logger->error("Last INSERTID is not available");
		$logger->error($DBI::errstr);
		exit 1;
	}
	
	my $lastEventID=$conn->{mysql_insertid};
	#----------
	# Insert the event contents
	#----------
	#
	our @contents=split(/\n/, $commits{$revision}{files});
	foreach(@contents)
	{
		$handle=$conn->prepare($insertContent);
		if(!($handle->execute(substr($_, 4), substr($_, 1, 1), $lastEventID)))
		{
			$logger->error("Insert into rm.event_content for revision $revision failed");
			$logger->error($DBI::errstr);
			exit 1;
		}
	}
	#----------
	# Insert the event requirements
	#----------
	#
	our @requirements=split(/\n/, $commits{$revision}{requirements});
	foreach(@requirements)
	{
		our ($type, $reqmt)=split(/\./, $_);
		$handle=$conn->prepare($insertRequirement);
		if(!($handle->execute($type, $reqmt, $lastEventID)))
		{
			$logger->error("Insert into rm.event_requirement for revision $revision failed");
			$logger->error($DBI::errstr);
			exit 1;
		}
	}
	
	our @defects=split(/\n/, $commits{$revision}{defects});
	foreach(@defects)
	{
		$handle=$conn->prepare($insertDefect);
		if(!($handle->execute($_, $lastEventID)))
		{
			$logger->error("Insert into rm.event_requirement for revision $revision failed");
			$logger->error($DBI::errstr);
			exit 1;
		}
	}
	#----------
	# Insert the event reviewers
	#----------
	#	
	our @reviewers=split(/\n/, $commits{$revision}{reviewers});
	foreach(@reviewers)
	{
		$handle=$conn->prepare($insertReviewer);
		if(!($handle->execute($_, $lastEventID)))
		{
			$logger->error("Insert into rm.event_reviewer for revision $revision failed");
			$logger->error($DBI::errstr);
			exit 1;
		}
	}
	#----------
	# Insert the event errors
	#----------
	#	
	our @errors=split(/\n/, $commits{$revision}{errors});
	foreach(@errors)
	{
		$handle=$conn->prepare($insertError);
		if(!($handle->execute($_, $lastEventID)))
		{
			$logger->error("Insert into rm.event_error for revision $revision failed");
			$logger->error($DBI::errstr);
			exit 1;
		}
	}
#	$commits{$key}{status}="OK";
#		$commits{$key}{author}=$xml->{logentry}{$key}->{author};
#		$commits{$key}{date}=$xml->{logentry}{$key}->{date};
#		$commits{$key}{msg}=$xml->{logentry}{$key}->{msg};
#		$commits{$key}{files}=$files;
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
sub generateSummaryReport
{
	our $conn=shift;
	our $body;
	our $c1=0;
	our $c2=0;
	
	$body.="</p>This report is a summary of the SVN parsing that occurred this morning. Please review the information below....</p><br/><br/>";
	
	$body.="<table width=\"100%\">";
	$body.="<tr><th width=\"45%\" align=\"left\">Filename</th><th width=\"45%\" align=\"left\">Application</th><th width=\"10%\" align=\"center\">Commits</th></tr>";
	foreach our $key(keys %{$rptSummary{files}})
	{
		next if $key eq "total";
		$c1++;
		$c2=$c2+$rptSummary{files}{$key}{revisions};
				
		$body.=sprintf("<tr><td valign=\"top\" align=\"left\">%s</td><td valign=\"top\" align=\"left\">%s</td><td valign=\"top\" align=\"center\">%d</td></tr>",$key, 'Application', $rptSummary{files}{$key}{revisions});
	}
	
	$body.="<tr><td colspan=2><br/>$c1 file(s) processed, $c2 commit(s) processed.</td></tr>";
	$body.="</table><br/><br/>";
	
	$body.="<table width=\"100%\">";
	$body.="<tr><th width=\"50%\">Repository Summary</th><th width=\"50%\" align=\"center\">Developer Summary</th></tr>";
	
	$body.="<tr><td>";
	
	$body.="<table width=\"100%\">";
	$body.="<tr><th width=\"70%\" align=\"left\">Repository</th><th width=\"15%\">Commits</th><th width=\"15%\">Issues</th></tr>";
	
	foreach(1..10)
	{
		$body.="<tr><td align=\"left\">Repository Name</td><td align=\"center\">10</td><td align=\"center\">2</td></tr>";
	}
	
	$body.="</table>";
	
	$body.="</td><td>";
	
	$body.="<table width=\"100%\">";
	$body.="<tr><th width=\"70%\" align=\"left\">Associate</th><th width=\"15%\">Commits</th><th width=\"15%\">Issues</th></tr>";

	foreach(1..10)
	{
		$body.="<tr><td align=\"left\">Associate Name</td><td align=\"center\">10</td><td align=\"center\">2</td></tr>";
	}
	
	$body.="</table>";
	
	$body.="</td></tr>";
	$body.="</table><br/>";
	
	$body.="<br/></p>Closing paragraph</p>";
	
	sendMailMessage('noreply@verizon.com','kenneth.s.henderson@gmail.com','Subversion Daily Summary', $body);
	
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
	our $conn=shift;
	our $body="";
	our $problems=0;
	
	$body.="</p>This report is a details the voliations to an established SVN checkin policy...</p><br/><br/>";
	
	foreach our $repository(sort keys %repo)
	{
		our $total=0;
		our $probs=0;
	
		$body.="<b>Repository: $repository</b><br/>";
		$body.="<table width=\"100%\">";
		$body.="<tr><th width=\"10%\">Revision</th><th width=\"10%\" align=\"center\">Author</th><th width=\"40%\">Message</th><th width=\"40%\">Issues</th></tr>";
		foreach our $key(keys %{$repo{$repository}})
		{
			$total++;
			
			next if $commits{$key}{status} eq "Ok";
			
			$probs++;
			$problems++;
			
			our $issues="";
			our @errors=split("\n", $commits{$key}{errors});
			foreach(@errors)
			{
				$issues.="$_<br/>";
			}
			
			$body.=sprintf("<tr><td valign=\"top\" align=\"left\">%s</td><td valign=\"top\" align=\"left\">%s</td><td valign=\"top\" align=\"left\">%s</td><td valign=\"top\" align=\"left\">%s</td></tr>",$key, $commits{$key}{author}, $commits{$key}{msg}, $issues);
		}
		
		$body.="<tr><td colspan=4><br/>$probs of $total commits had issues.</td></tr>";
		$body.="</table><br/><br/>";
	}
		
	
	$body.="<br/></p>Closing paragraph</p>";
	
	if($problems > 0)
	{
		sendMailMessage('noreply@verizon.com','kenneth.s.henderson@gmail.com','Subversion Commit Analysis', $body);	
	}
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
	our $type;
	our $reqs;
	our @rqmt;
	
	($type, $reqs)=split(/\=/, $line);
	
	$type="BR" if index(uc $type, "BR") >= 0;
	$type="SR" if index(uc $type, "SR") >= 0;
	$type="GT" if index(uc $type, "GT") >= 0;
	
	if(defined $reqs)
	{
		@rqmt=split(/\,/, $reqs);
	
		foreach(@rqmt)
		{
			our $rq=$_;
			
			$rq=stripSpaces($rq);
			$rq=stripSpaces($rq);
			
			$return.="$type.$rq\n";
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
		
		if(index(uc $_, "*PROJECT") >= 0)
		{
			$phase="PRO";
			next;
		}
		else
		{
			if(index(uc $_, "*BREQ") >= 0 || index(uc $_, "*SREQ") >= 0 || index(uc $_, "*GTRAK") >= 0)
			{
				$phase="REQ";
				next;
			}
			else
			{
				if(index(uc $_, "*DEFECT") >= 0)
				{
					$phase="DEF";
					next;
				}
				else
				{
					if(index(uc $_, "*REVIEWER") >= 0)
					{
						$phase="REV";
						next;
					}
					else
					{
						if(index(uc $_, "*RELEASE NOTES") >= 0)
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
	
	
	my @errorList=();
	
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
		else
		{
			if(!($release =~ m/^(1[4-9].0[1-6]|[2-9][0-9].0[1-6])$/))
			{
				$commits{$revision}{errors}.="Release provided is not a valid release\n";
				$logger->warn("[$revision $commits{$revision}{author}] Release provided is not a valid release");
				$commits{$revision}{status}="No";
			}
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
	
	# Parse the requirements looking for numeric or non-numeric here
	
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
sub xmlParse
{
	our $xml=shift;
	our $conn=shift;
	
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
			if(index(lc $fkey, "/tags/") eq -1)
			{
				next;
			}
			our $svnPath=substr($fkey, 0, rindex($fkey, "/"));
			our $svnFile=substr($fkey, rindex($fkey, "/")+1, length($fkey)-rindex($fkey, "/"));
			####print "$fkey $svnPath $svnFile\n";
			$files.="[";
			$files.=$xml->{logentry}{$key}->{paths}->{path}{$fkey}->{action};
			$files.="] ";
			$files.="$fkey\n"
		}
		
		if(!(defined $files))
		{
			$commits{$key}{status}="Skip";
		}
		else
		{
			$commits{$key}{status}="Ok";
			$commits{$key}{author}=$xml->{logentry}{$key}->{author};
			$commits{$key}{date}=$xml->{logentry}{$key}->{date};
			$commits{$key}{msg}=$xml->{logentry}{$key}->{msg};
			$commits{$key}{files}=$files;
			
			#----------
			# Determine the repo/application/team
			#----------
			#
			$repo{RepositoryName}{$key}=$key;
			
			$logger->info("Parsing Revision $key");
			parseCommitComments($key, $xml->{logentry}{$key}->{msg});
			
			$logger->info("Committing Revision $key to Database");
			insertEvent($conn, $key);
			$logger->info("Database Updated Successfully");	
		}
		 
		
	}
	#$rptSummary{files}{$path}{revisions}=$revs;
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
		
		#----------
		# Determine the repo/application/team
		#----------
		#
		$repo{RepositoryName}{$key}=$key;
		
		$logger->info("Parsing Revision $key");
		parseCommitComments($key, $xml->{logentry}{$key}->{msg});
		
		$logger->info("Committing Revision $key to Database");
		insertEvent($conn, $key);
		$logger->info("Database Updated Successfully"); 
		
	}
	$rptSummary{files}{$path}{revisions}=$revs;
}
#****************************************************************************************************************************************************************
# 
#****************************************************************************************************************************************************************
#
sub parseLogEntries
{
	our $dir=shift || "/var/vzt/rm/svn";
	our $conn=shift;
	our $count=0;
	
	$logger->info("Processing Directory $dir");
	if(!(opendir(DIR, $dir)))
	{
		$logger->error("Opening directory $dir failed");
		$logger->error("$!");
		exit 1;
	}
	
    while(our $file=readdir DIR) 
    {
    	next if -d "$dir/$file";
    	$count++;
    	
    	$logger->info("Processing $file In Directory $dir");
    	parseLogFile("$dir/$file", $conn);
    }
    
    closedir DIR;	
    
    $logger->info("$count file(s) processed in $dir");
}
#****************************************************************************************************************************************************************
# 
#****************************************************************************************************************************************************************
#
sub parseSubversion
{
	our $conn=shift;
	our $count=0;
	
	foreach my $repo("http://svn.hti.com/svn/hti", "http://svn.hti.com/svn/tos")
	{
		our $command=sprintf('svn log --xml --verbose -r {%s}:{%s} --username %s --password %s %s |', '2014-01-01', '2014-05-14', 'khenderson', 'H3@rtNur$3', $repo);
		
		$logger->info("Requesting SVN Log for $repo");
		open(RPO, $command) or die $!;
		$logger->info("SVN Log Received");
		
		our @recs=<RPO>;
		our $input=join("\n", @recs);
		$input=~s/\n//g;
		
		close RPO;
		
		$logger->info("Parsing XML Document");
		our $xml = XMLin($input, KeyAttr => { logentry => 'revision', path=>'content' }, ForceArray => [ 'path' ]);

		xmlParse($xml, $conn);
		
		$logger->info("Parsing Completed");
		
		$count++;
	}
	    $logger->info("$count repositories processed");
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

	##parseLogEntries("/var/vzt/rm/svn", $dbConnection);
	parseSubversion($dbConnection);
	
	generateSummaryReport($dbConnection);
	generateViolationReport($dbConnection);
	generateActivityReport($dbConnection);
	
	closeDatabaseConnection($dbConnection);
	
	$logger->info("$0 process ended");
	
	print Dumper(%commits) if defined $opt{'D'} && uc $opt{'D'} eq 'Y';
}