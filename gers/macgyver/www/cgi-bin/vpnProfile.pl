#!/usr/bin/perl
#******************************************************************************************************************************************************************
# Program Name:	vpnProfile.pl
# Author      :	Ken Henderson
# Narrative   : 
#
#
# Program History
#
# ----------  ------------------------  ---------------------------------------------------------------------------------------------------------------------------
# Date        Programmer				Description	
# ----------  ------------------------  ---------------------------------------------------------------------------------------------------------------------------
# 08/22/2013  K Henderson				Initial Coding
# 08/28/2013  K Henderson				Added subdirectory for storing VPN profiles
#
# ==========  ========================  ===========================================================================================================================
#
# -----------------------------------------------------------------------------------------------------------------------------------------------------------------
# To Do List
# -----------------------------------------------------------------------------------------------------------------------------------------------------------------
#
# 1. Add functionality to update Request Tracker tickets
# 2. Move ASA credentials to mysql database to obscure them from staff
#

#******************************************************************************************************************************************************************
# Modules Used
#******************************************************************************************************************************************************************
# 
use strict;
use warnings;

use CGI;
use Getopt::Std;
use String::Random qw(random_string);
use Net::Appliance::Session;
use Net::FTP;
use MIME::Lite;

#******************************************************************************************************************************************************************
# Global Variables
#******************************************************************************************************************************************************************
# 
our %opt;
our @profile;
our %info;
our $cgi;
our $json;

#******************************************************************************************************************************************************************
# main
#******************************************************************************************************************************************************************
#
main();
exit 0;

#******************************************************************************************************************************************************************
# usage
#******************************************************************************************************************************************************************
# 
sub usage
{
	our $help ="vpnProfile.pl -[a|d] -u[username] {-p[default|it|lp] {-m} {-h} {-e[account\@domain.com]}\n";
	    $help.="\n";
	    $help.="Required Arguments:\n";
	    $help.="  ASA IP Address\n";
	    $help.="    -i172.20.99.99\n";
	    $help.="\n";
	    $help.="  Action (only one permitted)\n";
	    $help.="    -a\tAdd VPN Account\n";
	    $help.="    -d\tDelete VPN Account\n";
	    $help.="\n";
	    $help.="  Username\n";
	    $help.="    -uUsername\n";
	    $help.="\n";
	    $help.="Optional Arguments:\n";
	    $help.="  Profile\n";
	    $help.="    -pdefault\tDefault Profile [used if -p is omitted]\n";
	    $help.="    -pit\t\tInformation Technology Profile\n";
	    $help.="    -plp\t\tLoss Prevention Profile\n";
	    $help.="\n";
	    $help.="  Mail\n";
	    $help.="    -m\tSend a message to the user with their profile and instructions\n";
	    $help.="\n";
	    $help.="  Alternate Email Address\n";
	    $help.="    -eaddress\@sample.com\n";
	    $help.="\n";
	    $help.="\n";
	    
	our @help=split("\n", $help);
	    
	foreach(@help)
	{
		printChronologicalMessage("$_");
	}    
	
	printChronologicalMessage("Script $0 Ended");
	
	exit 0;
}
#******************************************************************************************************************************************************************
# getOptions
#******************************************************************************************************************************************************************
#
sub getOptions
{
	if(defined $ENV{'HTTP_USER_AGENT'})
	{
		$opt{'i'}=$cgi->param('i');
		$opt{'u'}=$cgi->param('u');
		$opt{'p'}=$cgi->param('p');
		$opt{'e'}=$cgi->param('e');
		
		$opt{'a'}=1 if $cgi->param('a') eq 'a';
		$opt{'d'}=1 if $cgi->param('a') eq 'd';
		$opt{'x'}=1 if $cgi->param('a') eq 'x';
		$opt{'m'}=1 if $cgi->param('n') eq 'y';
		
		$info{'user'}=$cgi->param('u');
		
		return;
	}
	else
	{
		usage() if scalar(@ARGV) == 0;
		getopts("admhvxyu:p:e:i:l:t:", \%opt);
		usage() if defined $opt{'h'};
	}
	
	if(defined $opt{'a'} || defined $opt{'d'} || defined $opt{'x'})
	{
		if(defined($opt{'a'}))
		{
			if(defined $opt{'d'} || defined $opt{'x'})
			{
				printChronologicalMessage("Switches -a, -d, and -x cannot be used at the same time, use only one(1)");
				exit 0;	
			}
		}
		
		if(defined($opt{'d'}))
		{
			if(defined $opt{'a'} || defined $opt{'x'})
			{
				printChronologicalMessage("Switches -a, -d and -x cannot be used at the same time, use only one(2)");
				exit 0;	
			}
		}
		
		if(defined($opt{'x'}))
		{
			if(defined $opt{'a'} || defined $opt{'d'})
			{
				printChronologicalMessage("Switches -a, -d and -x cannot be used at the same time, use only one(3)");
				exit 0;	
			}
		}	
	}
	else
	{
		printChronologicalMessage("An action must be specified, please use either -a, -d or -x");
		exit 0;
	}
	
	if(defined $opt{'i'})
	{
		my $ip_part = "([0-9]|[0-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])";
		if (!($opt{'i'} =~ /^($ip_part\.){3}$ip_part$/))
		{
 			printChronologicalMessage("The supplied IP address is not valid");
			exit 0;
		}
	}
	else
	{
		printChronologicalMessage("The IP address of the target ASA must be supplied");
		exit 0;
	}
	
	if(defined $opt{'l'})
	{
		if(!(-e $opt{'l'}))
		{
			printChronologicalMessage("User file was not found");
			exit 0;
		}
		
		printChronologicalMessage("Action:\tAdd User") if defined $opt{'a'};
		printChronologicalMessage("Action:\tRemove User") if defined $opt{'d'};
		
		printChronologicalMessage("Address:\t$opt{'i'}");
		printChronologicalMessage("Filename:\t$opt{'l'}");
	
		return;
	}
	
	if(defined $opt{'u'})
	{
		$opt{'u'}=lc $opt{'u'};
		$info{'user'}=$opt{'u'};
	}
	else
	{
		printChronologicalMessage("Username must be supplied");
		exit 0;
	}
	
	if(defined $opt{'p'})
	{
		$opt{'p'}=lc $opt{'p'};
		if($opt{'p'} ne 'default'  && $opt{'p'} ne 'it'  && $opt{'p'} ne 'lp')
		{
			printChronologicalMessage("Profile must be default, it or lp");
			exit 0;
		}
	}
	else
	{
		$opt{'p'}="default";
	}
	
	if(defined $opt{'e'})
	{
		if(!($opt{'e'} =~ /.+@.+\..+/))
		{
			printChronologicalMessage("The supplied email address does not look like and email address");
			exit 0;
		}
	}
	
	printChronologicalMessage("Action:\tAdd User") if defined $opt{'a'};
	printChronologicalMessage("Action:\tRemove User") if defined $opt{'d'};
	
	printChronologicalMessage("Address:\t$opt{'i'}");
	printChronologicalMessage("Username:\t$opt{'u'}");
	printChronologicalMessage("Profile:\tDefault") if $opt{'p'} eq "default";
	printChronologicalMessage("Profile:\tInformation Technology") if $opt{'p'} eq "it";
	printChronologicalMessage("Profile:\tLoss Prevention") if $opt{'p'} eq "lp";
	
	printChronologicalMessage("Mail?\tYes") if defined $opt{'m'};
	printChronologicalMessage("Mail?\tNo") if not defined $opt{'m'};
	
	printChronologicalMessage("Email To:\t$opt{'e'}") if defined $opt{'e'};
	
}
#******************************************************************************************************************************************************************
# loadProfileTemplate
#******************************************************************************************************************************************************************
#
sub loadProfileTemplate
{
	our $profile="default";
	
	$profile="lp" if defined $opt{'p'} && lc $opt{'p'} eq "lp";
	$profile="it" if defined $opt{'p'} && lc $opt{'p'} eq "it";
	
	our $file="/usr/local/data/net/vpn/profiles/vpn.profile.$profile";
	printChronologicalMessage("\tUsing Profile: $profile");
	printChronologicalMessage("\t$file");
	
	if(!(open(VPNI, "<$file")))
	{
		printChronologicalMessage("Failed to open profile template");
		printChronologicalMessage("$!");
		$info{"error"}="Failed to open profile template\n$!\n";
		return 0;
	}

	while (<VPNI>)
	{
	    chomp($_);
	    push(@profile, $_);
	}
	
	close VPNI;
	
	return 1;
}
#******************************************************************************************************************************************************************
# generateProfile
#******************************************************************************************************************************************************************
#
sub generateProfile
{
	our $file=sprintf("/usr/local/data/net/vpn/profiles/%s/vpn-%s.pcf", $opt{'i'}, lc $opt{'u'});
	our $pattern=random_string("000000000000", ['0'..'4']);
	our $password=random_string("$pattern", ['A'..'Z', '!', '@', '#', '%', '&', '*', '=', '+'],
	                                        ['a'..'z', '!', '@', '#', '%', '&', '*', '=', '+'],
	                                        ['0'..'9', '!', '@', '#', '%', '&', '*', '=', '+'],
	                                        ['A'..'Z', '0'..'9', '!', '@', '#', '%', '&', '*', '=', '+'],
	                                        ['a'..'z', '0'..'9', '!', '@', '#', '%', '&', '*', '=', '+']);
	                                        
	$info{'user'}=$opt{'u'};
	$info{'password'}=$password;
	
	printChronologicalMessage("Creating User $info{'user'} with password $info{'password'}") if defined $opt{'v'};
	
	if(buildProfileOnFirewall())
	{
		if(!(open(VPN, ">$file")))
		{
			printCnronologicalMessage("Failed to open user profile, $file");
			printCnronologicalMessage("$!\n");
			$info{"error"}="Failed to open user profile\n$file\n$!\n";
			return 0;
		}
	
		foreach our $vpn(@profile)
	    {
	        $vpn =~ s/<username>/$info{'user'}/g;
	        $vpn =~ s/<password>/$password/g;
	        print VPN "$vpn\n";
	    }
		
		close VPN;	
	}
	else
	{
		return 0;
	}
		
	return 1;
}
#******************************************************************************************************************************************************************
# buildProfileOnFirewall
#******************************************************************************************************************************************************************
#
sub buildProfileOnFirewall
{
	our($user, $pass, $enable)=getCredentials($opt{'i'});
	our @result;
	
	printChronologicalMessage("Connecting to ASA at $opt{'i'}");
		
	our $s = Net::Appliance::Session->new({personality=>'ios', transport=>'SSH', host=>"$opt{'i'}", privileged_paging => 1});
	$s->set_global_log_at('debug') if defined $opt{'y'}; 

 	eval
 	{
 		$s->connect(username=>$user, password=>$pass, privileged_password=>$enable, SHKC=>0);
 		
		$s->begin_privileged;
        asaCommand($s, "terminal pager 0");
        $s->begin_configure;
        
        asaCommand($s, sprintf("clear config username %s", $info{'user'}), "Y");
        
        asaCommand($s, sprintf("username %s password %s priv 0", $info{'user'}, $info{'password'}), "Y");
        asaCommand($s, sprintf("username %s attributes", $info{'user'}), "Y");
        asaCommand($s, "vpn-group-policy Paradies", "Y");

        $s->end_configure;		
        
        asaCommand($s, sprintf("show running-config username %s", $info{'user'}), "Y");
        
     	$s->end_privileged;
     	$s->close;
 	};
 	
 	if($@)
 	{
 		printChronologicalMessage("\tError Connecting to ASA");
 		printChronologicalMessage("$@");
 		$info{"error"}="Error connecting to ASA\n$@\n";
 		return 0;
 	}
 	
	return 1;
}

#******************************************************************************************************************************************************************
#
#******************************************************************************************************************************************************************
#
sub removeProfile
{
	our($user, $pass, $enable)=getCredentials($opt{'i'});
	our @result;

	printChronologicalMessage("Removing VPN Profile of $opt{'u'}");
		
	our $s = Net::Appliance::Session->new({personality=>'ios', transport=>'SSH', host=>"$opt{'i'}", privileged_paging => 1});
	$s->set_global_log_at('debug') if defined $opt{'y'}; 

 	eval
 	{
 		$s->connect(username=>$user, password=>$pass, privileged_password=>$enable, SHKC=>0);
 		
		$s->begin_privileged;
        asaCommand($s, "terminal pager 0");
        $s->begin_configure;

        asaCommand($s, sprintf("clear config username %s", $info{'user'}), "Y");
        
        $s->end_configure;
        
        asaCommand($s, sprintf("show running-config username %s", $info{'user'}), "Y");
        
     	$s->end_privileged;
     	$s->close;
 	};
 	
 	if($@)
 	{
 		printChronologicalMessage("\tError Connecting to ASA");
 		printChronologicalMessage("$@");
 		$info{"error"}="Error connecting to ASA\n$@\n";
 		return 0;
 	}
 	
	return 1;
}
#******************************************************************************************************************************************************************
#
#******************************************************************************************************************************************************************
#
sub checkProfile
{
	our($user, $pass, $enable)=getCredentials($opt{'i'});
	our @result;

	printChronologicalMessage("Checking VPN Profile of $opt{'u'}");
		
	our $s = Net::Appliance::Session->new({personality=>'ios', transport=>'SSH', host=>"$opt{'i'}", privileged_paging => 1});
	$s->set_global_log_at('debug') if defined $opt{'y'}; 

 	eval
 	{
 		$s->connect(username=>$user, password=>$pass, privileged_password=>$enable, SHKC=>0);
 		
		$s->begin_privileged;
        asaCommand($s, "terminal pager 0");
        asaCommand($s, sprintf("show running-config username %s", $info{'user'}), "Y");
        
     	$s->end_privileged;
     	$s->close;
 	};
 	
 	if($@)
 	{
 		printChronologicalMessage("\tError Connecting to ASA");
 		printChronologicalMessage("$@");
 		$info{"error"}="Error connecting to ASA\n$@\n";
 		return 0;
 	}
 	
	return 1;
}
#******************************************************************************************************************************************************************
# asaCommand
#******************************************************************************************************************************************************************
#
sub asaCommand
{
	our $session=shift;
	our $command=shift;
	our $show=shift || "N";
	our @result;
	
	printChronologicalMessage("Executing $command") if $show eq "Y";
	
	eval
	{
		@result=$session->cmd($command);
	
		## Interrogate for error first
		if($show eq "Y")
		{
			foreach(@result)
			{
				chomp($_);
				printChronologicalMessage("$_");
			}
		}	
	};
	
	if($@)
	{
		printChronologicalMessage("$@");
	}
	
	printChronologicalMessage("Command Completed") if $show eq "Y";
	printChronologicalMessage(" ") if $show eq "Y";
}
#******************************************************************************************************************************************************************
#
#******************************************************************************************************************************************************************
#
sub generateCommunication
{
	our $file=sprintf("/usr/local/data/net/vpn/profiles/%s/vpn-%s.pcf", $opt{'i'}, $info{'user'});
    our $msg = <<__HTML__;
<HTML>
    <HEAD>
    </HEAD>
    <BODY>
        <P>
        	If you have any issues with this VPN, please do not respond to this email as your password is contained below and should not be shared with anyone at anytime.  If you encounter an issue contact the help desk by either calline the number below or sending a seperate email to ITServiceCenter\@paradies-na.com<BR />
			<BR />        
            Your VPN account has been created and is ready for use.<BR />
            <BR />
            Your username is <UN> and your new VPN password is <PW><BR />
            <I>&nbsp;&nbsp;As always, do not share your credentials with other associates</I><BR />
            <BR />
            <A HREF="http://www.accesstps.com/sites/it_support/Helpdesk%20Documentation/Forms/AllItems.aspx?RootFolder=%2fsites%2fit_support%2fHelpdesk%20Documentation%2fVPN&FolderCTID=&View=%7bEE1EFC5D-06EA-4B24-967D-2BCB5A4D70B0%7d">Click this link to view the instructions on installing your new profile</A> or open the attached document for instructions.
            <BR /><BR />
            If you have any issues with the installation of the new profile or with connecting to the VPN, please contact the IT Service Center at (888) 701-4300<BR />
            and refer to the <I>Associate VPN Profile Installation</I><BR />
        </P>
    </BODY>
</HTML>
__HTML__

    $msg =~ s/<UN>/$info{'user'}/g;
    $msg =~ s/<PW>/$info{'password'}/g;
    
    our $address=$opt{'e'} || "$info{'user'}\@paradies-na.com";
    our $mail = new MIME::Lite(Subject=>'Your New VPN Credentials', From=>'ITServiceCenter@paradies-na.com', To=>"$address", Type=>'multipart/mixed');
 
    $mail->attach(Type=>'text/html', Data=>$msg);  
    $mail->attach(Type=>'application/xml', Path=>"$file", Disposition => 'attachment');
    $mail->attach(Type=>'application/msword', Path=>"/usr/local/data/net/vpn/profiles/VPNSetupAndLoginInstructions.doc", Disposition => 'attachment');
 
    if(!($mail->send('smtp', "mail1.tpscorp.theparadiesshops.com")))
    {
    	printChronologicalMessage("\tError Sending Communication to $address");
    	printChronologicalMessage("\t$!");
    	$info{"error"}="Error Sending Communication to $address\n$!\n";
        return 0;
    }
    else
    {
        printChronologicalMessage("Message Sent Successfully");    
    }
    
    return 1;
}
#********************************************************************************************************************************************************************
# Send an error message via email
#********************************************************************************************************************************************************************
#
sub printChronologicalMessage
{
    my $msg = shift;
    
    if(defined $ENV{'HTTP_USER_AGENT'})
    {
    	print "[".getFormattedDateAndTime("mmmm dd, yyyy hr:mn:sc")."] $msg<br>";
    	$msg=~s/\n/<br>/g;
    	$json.=sprintf("[%s] %s<br>", getFormattedDateAndTime("mmmm dd, yyyy hr:mn:sc"), $msg);
    }
    else
    {
    	print "[".getFormattedDateAndTime("mmmm dd, yyyy hr:mn:sc")."] $msg\n";
    }
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
#******************************************************************************************************************************************************************
# getCredentials
#******************************************************************************************************************************************************************
#
sub getCredentials
{
	our $ip=shift;
	
	our $asaUsername="tpsscripting";
	our $asaPassword="M0o5e!0v3";
	our $asaEnable="M0o5e!0v3";
	
	if($ip eq "10.0.254.17")
	{
		$asaUsername="pix";
		$asaPassword="install";
		$asaEnable="install1";
	}
	
	return ($asaUsername, $asaPassword, $asaEnable);
}
#******************************************************************************************************************************************************************
# processListOfUsers
#******************************************************************************************************************************************************************
#
sub processListOfUsers
{
	if(!(open(USR, "<$opt{'l'}")))
	{
		printChronologicalMessage("Failed to Open User List");
		printChronologicalMessage("$!");
		return 0;	
	}
	
	while(<USR>)
	{
		chomp($_);
		
		our($user, $profile, $address)=split(",", $_);
		
		$opt{'u'}=lc $user;
		$opt{'p'}=lc $profile;
		$opt{'e'}=$address if defined $address;
	
		printChronologicalMessage(" ");
		processRequest();
		printChronologicalMessage(" ");	
	}
	
	close USR;
}
#******************************************************************************************************************************************************************
# processRequest
#******************************************************************************************************************************************************************
#
sub processRequest
{
	if(defined $opt{'a'})
	{
		printChronologicalMessage("Adding Profile for User $opt{'u'}");
		printChronologicalMessage("Loading Profile Template");
		
		if(loadProfileTemplate())
		{
			printChronologicalMessage("Generating Profile");
			if(generateProfile())
			{
				printChronologicalMessage("Bypassing Communication for User $info{'user'}") if not defined $opt{'m'};
				printChronologicalMessage("Generating Communication for User $info{'user'}") if defined $opt{'m'};
				
				generateCommunication() if defined $opt{'m'};
				
				updateServiceCenterTicket("Y") if defined $opt{'t'};
			}
			else
			{
				printChronologicalMessage("Failed to Generate Profile");
				updateServiceCenterTicket("N", $info{"error"}) if defined $opt{'t'};
			}	
		}
		else
		{
			updateServiceCenterTicket("N", $info{"error"}) if defined $opt{'t'};
		}
	}
	else
	{
		if(defined $opt{'d'})
		{
			removeProfile();
		}
		else
		{
			checkProfile();	
		}
	}
}
#******************************************************************************************************************************************************************
# updateServiceCenterTicket
#******************************************************************************************************************************************************************
#
sub updateServiceCenterTicket
{
	our $success=shift;
	our $reason=shift;
	
	printChronologicalMessage("Updating Service Center Ticket $opt{'t'}");
	
	if($success eq "Y")
	{
		
	}
	else
	{
		
	}
}
#******************************************************************************************************************************************************************
# main
#******************************************************************************************************************************************************************
#
sub main
{
	our $cgi=CGI->new;
	
	print $cgi->header(-type => "text/html", -charset => "utf-8");
	
	printChronologicalMessage("Script $0 Started");
        printChronologicalMessage(" ");
	printChronologicalMessage("Evaluating Command Line Arguments");
	getOptions();
	
	if(defined $opt{'l'})
	{
		processListOfUsers();	
	}
	else
	{
		processRequest();	
	}
	printChronologicalMessage("Script $0 Ended");
	
	$json.='"}' if defined $ENV{'HTTP_USER_AGENT'};
	print $json if defined $ENV{'HTTP_USER_AGENT'};
}
