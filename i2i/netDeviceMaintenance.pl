#****************************************************************************************************************************************************************
# rmSVNCommentParser.pl
#****************************************************************************************************************************************************************
#
# To Do List
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
#	Priority		Description
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
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

use POSIX;;
use Getopt::Long;
use Net::Appliance::Session;

use Log::Log4perl qw(get_logger :levels);
use Data::Dumper;
#****************************************************************************************************************************************************************
# Global Variables
#****************************************************************************************************************************************************************
#
our %opt;
our %svr;

our @cmds;

our $host;
our $servers;
our $user;
our $pass;
our $enable;
our $commands;
our $web=0;
our $firewall=0;
our $router=0;
our $switch=0;
our $help=0;
our $debug=0;
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
# 
#****************************************************************************************************************************************************************
#
sub getSession
{
	our $host=shift;
	our $personality=shift || 'ios';
	our $transport=shift || 'SSH';
	
	$logger->info("Establishing Session to $host");
	our $session=Net::Appliance::Session->new({personality=>$personality, transport=>$transport, host=>$host, privileged_paging => 1});
	
	
	try
	{
		$session->connect({username=>'username', password=>'loginpass'})
	}
	catch
	{
		$logger->error("Could not establish session with $host");
		$logger->error("$_");
		exit 1;
	}
	finally
	{
		$session->close;	
	}
}
#****************************************************************************************************************************************************************
# 
#****************************************************************************************************************************************************************
#
sub runCommand
{
	our $session=shift;
	our $command=shift;
	our $show=shift || "Y";
	
	$logger->info("[$host] $command");
	
	try
	{
		our @result=$session->cmd($command);
		
		if(uc $show eq "Y")
		{
			foreach(@result)
			{
				$logger->info("$_");
			}
			
		}
		$logger->info("Execution Completed");	
	}
	catch
	{
		$logger->error("Execution of [$command] Failed");
		$logger->error("$_");
		exit 1;
	}
	finally
	{
			
	}
}
#****************************************************************************************************************************************************************
# 
#****************************************************************************************************************************************************************
#
sub endSession
{
	our $session;
	
 	$session->close;
 	
}
#****************************************************************************************************************************************************************
# 
#****************************************************************************************************************************************************************
#
sub processHost
{
	our $host=shift;
	our $user=shift;
	our $pass=shift;
	our $enable=shift;
	
	our $session=getSession($host, $user, $pass);
	
	$session->begin_privileged({password=>$enable});
	$session->begin_configure;
	
	foreach(@cmds)
	{
		runCommand($_);
	}

	$session->end_configure;	
	$session->end_privileged;
	
	endSession($session);
}
#****************************************************************************************************************************************************************
# 
#****************************************************************************************************************************************************************
#
sub loadServers
{
	our $cnt=0;
	
	$logger->info("Loading Servers");
	
	if(open(SVR, "<$servers"))
	{
		while(<SVR>)
		{
			chomp($_);
			#
			# Do any substitution here
			
			our ($server, $user, $pass, $enable)=split(/\,/, $_);
			
			$svr{$server}{host}=$server;
			$svr{$server}{user}=$user;
			$svr{$server}{pass}=$pass;
			$svr{$server}{enable}=$enable;
			
			$cnt++;
		}
		
		close SVR;	
	}
	else
	{
		$logger->error("Could not open server manifest [$servers]");
		$logger->error("$!");
		exit 1;
	}
	
	
	$logger->info("$cnt Servers Loaded");	
}
#****************************************************************************************************************************************************************
# 
#****************************************************************************************************************************************************************
#
sub loadCommandFile
{	
	$logger->info("Loading Command Set");
	if(open(CMD, "<$commands"))
	{
		our $cnt=0;
		while(<CMD>)
		{
			chomp($_);
			#
			# Do any substitution here
			push(@cmds, $_);
			$cnt++;
		}
		close CMD;	
		$logger->info("$cnt commands loaded");
	}
	else
	{
		$logger->error("Could not open commands [$commands]");
		$logger->error("$!");
		exit 1;
	}
}
#****************************************************************************************************************************************************************
# 
#****************************************************************************************************************************************************************
#
sub usage
{	
	print "Usage\n";
	exit;
}
#****************************************************************************************************************************************************************
# 
#****************************************************************************************************************************************************************
#
sub getOptions
{	
	
	 GetOptions('host=s'	=> \$host,
	            'servers=s'	=> \$servers,
	            'commands=s'=> \$commands,
	            'user=s'	=> \$user,
	            'pass=s'	=> \$pass,
	            'enable=s'	=> \$enable,
	            'web'		=> \$web,
	            'firewall'	=> \$firewall,
	            'router'	=> \$router,
	            'switch'	=> \$switch,
	            'help'		=> \$help,
	            'debug'		=> \$debug);
	            
	#'quiet' => sub { $verbose = 0 });
	
	# Check if help was requested and call that process, then exit
	# 
	#
	
	usage() if $help;
	
	#validate existence of files
	print "|h=$host|s=$servers|c=$commands|$web|$firewall $router $switch|$help|$debug|\n";
#	if(defined $host && defined $servers)
#	{
#		print "pick host or servers, only 1";
#		exit;
#	}
#	else
#	{
#		if(defined $host)
#		{
#		}
#		else
#		{
#			if(!(-e $servers))
#			{
#				print "The server file does not exist"
#				exit;
#			}
#		}
#	}
#	
#	if(!defined $commands)
#	{
#		if(!(-e $commands))
#		{
#			print "the command file does notexist";
#			exit;
#		}
#	}
#	else
#	{
#		print "command file must be supplied";
#		exit;
#	}
	
	# valiate only firewall, switch, router: only 1
	
	if(!(defined $firewall || defined $router || defined $switch))
	{
		print "must enter firewall, switch or router";
		exit;
	}
	
	if(($firewall+$router+$switch) > 1)
	{
		print "Only 1 (firewall, router, switch";
		exit;
	}
	
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
	
	loadCommandFile();
	
	if(defined $host)
	{
		$logger->info("Using Host Processing Path");
		processHost($host,$user, $pass, $enable);
	}
	else
	{
		if(defined $servers)
		{
			$logger->info("Using Servers Processing Path");
			loadServers();
			
			foreach our $srvr(sort keys %svr)
			{
				$logger->info("Attmepting Host $svr{$srvr}{host}");
				processHost($svr{$srvr}{host}, $svr{$srvr}{user}, $svr{$srvr}{pass}, $svr{$srvr}{enable})
			}	
		}
	}
		
	$logger->info("$0 process ended");
}