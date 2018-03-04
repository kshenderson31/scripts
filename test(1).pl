use strict;
use warnings;
use SVN::Log;
use POSIX;

use Email::Send;
use Email::Send::Gmail;
use Email::Simple::Markdown;

  my $email = Email::Simple::Markdown->create(
      header => [
          From    => 'kenneth.s.henderson@gmail.com',
          To      => 'kenneth.s.henderson@gmail.com',
          Subject => 'Test Message',
      ],
      body => '<b>The server is down. Start panicing.</b>',
  );

  my $sender = Email::Send->new(
      {   mailer      => 'Gmail',
          mailer_args => [
              username => 'kenneth.s.henderson@gmail.com',
              password => 'zzt1mm1e31',
          ]
      }
  );
  eval { $sender->send($email) };
  die "Error sending email: $@" if $@;

exit;


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
exit;

open(SVN, 'svn log --verbose --xml -r {$(date --date="yesterday" +"%Y-%m-%d")}:{$(date --date="yesterday" +"%Y-%m-%d")} http://svn.apache.org/repos/asf/commons/proper |');
while(<SVN>)
{
	print "$_\n";
}

__DATA__
14.02
13.01