use Mail::Sendmail;


	$Mail::Sendmail::mailcfg{smtp}->[0]='mail-atl.hughestelematics.com';
	$Mail::Sendmail::mailcfg{from}="ReleaseManagement\@hughestelematics.com";
	
	
  print "Testing Mail::Sendmail version $Mail::Sendmail::VERSION\n";
  print "Default server: $Mail::Sendmail::mailcfg{smtp}->[0]\n";
  print "Default sender: $Mail::Sendmail::mailcfg{from}\n";

	exit 1;
	
  %mail = (
      To      => 'ken.henderson@hughestelematics.com',
      From    => 'ken.henderson@hughestelematics.com',
      #Bcc     => 'Someone <him@there.com>, Someone else her@there.com',
      # only addresses are extracted from Bcc, real names disregarded
      #Cc      => 'Yet someone else <xz@whatever.com>',
      # Cc will appear in the header. (Bcc will not)
      Subject => 'Test message 2',
      'X-Mailer' => "Mail::Sendmail version $Mail::Sendmail::VERSION",
  );


  #$mail{smtp} = 'mail-atl.hughestelematics.com';
  #$mail{port} = '2525';
  #$mail{'X-custom'} = 'My custom additionnal header';
  $mail{'mESSaGE : '} = "The message key looks terrible, but works.";
  # cheat on the date:
  #$mail{Date} = Mail::Sendmail::time_to_date( time() - 86400 );

  if (sendmail %mail) { print "Mail sent OK.\n" }
  else { print "Error sending mail: $Mail::Sendmail::error \n" }

  print "\n\$Mail::Sendmail::log says:\n", $Mail::Sendmail::log;