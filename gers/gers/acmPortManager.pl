use strict;
use warnings;

$ENV{MLINK}='/gers/mlink;/prod/mlink';

if(!(open(PS,"ps -eaf | grep amproc |"))) 
{
	printChronologicalMessage("DWM Monitor: Failed to Process ps -ef", "N");
	my $message="Failed to open ps -ef\n$!";
	sendMailMessage('[GERS DWM] Failed To Process ps-ef', $! || " ");	
	exit 0;
}

while ( <PS> )
{
	chomp($_);
	
	our (undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, $port, $process)=split(" ", $_);
	
	print "Setting debug on port $port\n" if defined $port;
	
	system("mlink -h amdebug genret $port 9") if defined $port;
	#setDebug($port);
}

exit 0;

sub setDebug
{
	our $port=shift;

	return if length($port) != 4;
	
	
	
	if(!(open(PS,"mlink -h amdebug genret $port 9 |"))) 
	{
		printChronologicalMessage("DWM Monitor: Failed to Process ps -ef", "N");
		my $message="Failed to open ps -ef\n$!";
		sendMailMessage('[GERS DWM] Failed To Process ps-ef', $! || " ");	
		exit 0;
	}
	
	while ( <PS> )
	{
		chomp($_);
		
		print "$_\n";
	}	
}

