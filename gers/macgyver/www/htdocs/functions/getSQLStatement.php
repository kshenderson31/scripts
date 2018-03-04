<?php
require_once "globals/globals.php";

function getSQLStatement($statementNumber)
{
	$dbConnection = mysqli_connect(mysqlHost, mysqlUser, mysqlPass, mysqlDatabase);

	if (mysqli_connect_errno()) 
	{
		echo "Connect failed: " . mysqli_connect_errno() . " --> " . mysqli_connect_error();
		exit();
	}
		
	$sqlStatement = "SELECT sql_stmt_txt " .
	                "  FROM tpsArchitecture.syssql " .
					"WHERE sql_stmt_nbr = $statementNumber ";
	
	if (!$dbResult = mysqli_query($dbConnection, $sqlStatement))
	{
		mysqli_close($dbConnection);
		
		echo "it failed \n";
		echo "sqlState : " . mysqli_sqlstate($dbConnection) . "\n";
	 	echo "Errorcode: " . mysqli_errno($dbConnection) . " --> " . mysqli_error($dbConnection) . "\n" ;
		
		header("Location:http:" . webRoot . "errorPage.php");
	
		exit();
	}
	
	$row = mysqli_fetch_array($dbResult);
	
	mysqli_close($dbConnection);
	
	return $row['sql_stmt_txt'];
}

?>