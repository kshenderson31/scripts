use strict;
use warnings;
use POSIX;

use Email::Send;
use Email::Send::Gmail;
use Email::Simple::Markdown;

  my $email = Email::Simple::Markdown->create(
      header => [
          From    => 'ken.henderson@hughestelematics.com',
          To      => 'ken.henderson@hughestelematics.com',
          Subject => 'Test Message',
      ],
      body => '<b>The server is down. Start panicing.</b>',
  );

  my $sender = Email::Send->new(
      {   mailer      => 'SMTP',
          mailer_args => [Host=>'mail-atl.hughestelematics.com']
      }
  );
  eval { $sender->send($email) };
  die "Error sending email: $@" if $@;

exit;


my @result = `svn log --xml --verbose --username khenderson --password H3\@rtNur\$3 http://svn.hti.com/svn/hti/MiddleWare`;
foreach(@result)
{
	print "$_";
}
exit 1;

open(SVN, 'svn log --xml --verbose http://svn.hti.com/svn/hti/MiddleWare |') || die "Failed: $!\n";

	print ">>>>\n";
	while(<SVN>)
	{
		print "$_";
	}
	
	close SVN;

exit 1;




while(<DATA>)
{
	if($_ =~ m/^(1[4-9].0[1-6]|[2-9][0-9].0[1-6])$/)
	{
		print "$_ Matches\n";
	}
	else
	{
		print "$_ DOES NOT MATCH\n";
	}	
}

print strftime "%Y-%m-%d", localtime;

open(SVN, 'svn log --verbose --xml -r {$(date --date="yesterday" +"%Y-%m-%d")}:{$(date --date="yesterday" +"%Y-%m-%d")} http://svn.apache.org/repos/asf/commons/proper |');
while(<SVN>)
{
	print "$_\n";
}

__DATA__
14.02
13.01