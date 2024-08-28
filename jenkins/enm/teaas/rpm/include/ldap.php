<?php
//http://stackoverflow.com/questions/17773643/using-active-directory-to-authenticate-users-on-intranet-site

session_start();

//error_reporting(E_ALL);
//ini_set('display_errors', 'On');

$ldapserver = 'ldaps://eriseli01.ericsson.se';
$ldapserver = 'ldaps://ldap-egad.internal.ericsson.com';
$ldapuser      = 'ATVEGAD@ericsson.se';
$ldappass     = 'GuWa3EpuBRUqAjAg';

//$ldapuser      = 'ejershe@ericsson.se';
//$ldappass     = 'Bluegrass30';

$ldaptree    = "CN=eiffelldap,OU=CA,OU=SvcAccount,OU=P001,OU=ID,OU=Data,DC=ericsson,DC=se";



if(isset($_POST['logout']))
{
	$err = "You have been logged out";
	unset($_SESSION['rpm']);
}

if (isset($_POST['submit']))
{

	$ldapuser = strip_tags($_POST['username'])."@ericsson.se";
	$ldappass = stripslashes($_POST['password']);
	
	
    $conn = ldap_connect($ldapserver ."/",3269);

    if (!$conn){
        $err = 'Could not connect to LDAP server';
    }
    else
    {
        define('LDAP_OPT_DIAGNOSTIC_MESSAGE', 0x0032);

        ldap_set_option($conn, LDAP_OPT_PROTOCOL_VERSION, 3);
        ldap_set_option($conn, LDAP_OPT_REFERRALS, 0);

        $bind = @ldap_bind($conn, $ldapuser, $ldappass);

        ldap_get_option($conn, LDAP_OPT_DIAGNOSTIC_MESSAGE, $extended_error);

        if (!empty($extended_error))
        {
            $errno = explode(',', $extended_error);
            $errno = $errno[2];
            $errno = explode(' ', $errno);
            $errno = $errno[2];
            $errno = intval($errno);

            if ($errno == 532)
                $err = 'Unable to login: Password expired';
        }

        elseif ($bind)
        {
            

            $result = ldap_search($conn,$ldaptree, "(cn=*)") or die ("Error in search query: ".ldap_error($ldapconn));
            $data = ldap_get_entries($conn, $result);
        	setcookie("uid", $_POST['username'],time()+3600,"/","atrclin3.athtem.eei.ericsson.se");

            if (count($result)==1){
            	$_SESSION['rpm'] = 'bar';
            	 
            }
                
            else
            {
            	
            }
        }
    }

    // session OK, redirect to home page
    if (isset($_SESSION['rpm']))
    {
        $err = "Login ". ldap_error($conn);
    }

    else if (!isset($err)){ 
    	
    	$err = 'Unable to login : '. ldap_error($conn);
    }

    ldap_close($conn);
    
}



?>
