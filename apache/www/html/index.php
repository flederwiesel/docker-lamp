<?php
// For curl, show quick version info, otherwise complete phpinfo().
if (preg_match("/curl/", $_SERVER["HTTP_USER_AGENT"]??"unknown"))
{
	echo "PHP Version ".phpversion()."\n";
	echo "Apache Version ".apache_get_version().".\n";
	echo "Zend Engine ".zend_version().".\n";

	$xdebug = phpversion("xdebug");

	if ($xdebug)
		echo "XDebug Version ${xdebug}\n";

	echo "Loaded Extensions:\n";

	$extensions = get_loaded_extensions();

	sort($extensions);

	foreach ($extensions as $ext)
		echo "    $ext\n";
}
else
{
	echo phpinfo();
}
?>
