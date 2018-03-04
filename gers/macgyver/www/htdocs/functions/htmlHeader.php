<?php
require_once "globals/globals.php";

function htmlHeader($includeStyles)
{
	$sessionTimer = sessionTimeOut + 1;
	
	print "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n";
	print "<html xmlns=\"http://www.w3.org/1999/xhtml\">\n";
	print "<head>\n";
	print "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=ISO-8859-1\">\n";
	
	if ($_SERVER['REQUEST_URI'] != "/errorPage.php" &&
	    $_SERVER['REQUEST_URI'] != "/loginPage.php" &&
		$_SERVER['REQUEST_URI'] != "/logoutPage.php" &&
		$_SERVER['REQUEST_URI'] != "/registerPage.php" &&
	    $_SERVER['REQUEST_URI'] != "/landingPage.php")
	{
		print "<meta http-equiv=\"refresh\" content=\"$sessionTimer\">\n";
	}

	if ($includeStyles == "Y")
	{	
		print "		<link rel=\"stylesheet\" href=\"styles/wrapper.css\" type=\"text/css\" media=\"screen\" title=\"no title\" charset=\"utf-8\" />";
		print "<style type=\"text/css\">\n";
	}
		
}
?>
