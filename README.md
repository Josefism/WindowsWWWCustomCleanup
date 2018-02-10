# WindowsWWWCustomCleanup

A PowerShell script cleaning log files and backup files from web servers running WordPress with the UpdraftPlus plugin on Windows (IIS)

## Summary
WindowsWWWCustomCleanup removes W3SVC log files older than a set number of days when the containing subfolder exceeds set bytes. Also forcefully removes WordPress UpdraftPlus backups older than a set number of days when they are found in the UpdraftPlus backup folder beyond their specified retention date (set within the UpdraftPlus plugin settings).
	
WindowsWWWCustomCleanup.ps1 is built to run via automated task. As such, it generates its own small log files in a 'cleanup' subfolder and retains history indefinitely. Cleanup Report log files are set to rollover to a new file when filesize exceeds 25Mb.

### Environmental Assumptions:
* Windows Server running IIS
* WordPress installation (not Multisite)
* UpdraftPlus plugin installed in WordPress and saving backups to local disk. For more information on UpdraftPlus, see:
	* https://updraftplus.com/
	* https://wordpress.org/plugins/updraftplus/

## Usage

First put WindowsWWWCustomCleanup.ps1 into a folder on your webhost. Remember the path to the script, as it will be required if implementing the script through Task Scheduler.
	
Set variables in WindowsWWWCustomCleanup.ps1 specific to your environment. All variables are initialized at the top of the file. Default variable values should coincide with default settings from Windows, IIS, WordPress, and UpdraftPlus.
	
Set up a scheduled task to run the script at a time and with the options best suited to your environment. Some environments may require a task scheduled to run daily, for example, while others may only need to run weekly.
	
For more information on Windows Task Scheduler, see:
https://msdn.microsoft.com/en-us/library/windows/desktop/aa384006.aspx

___

## Credits, Comments, etc.

This script was built for a single client server with a specific configuration, but the cleanup jobs it performs are so universal I have moved the code to GitHub to allow forking and reuse in other client environments.

## TODO

* Add error handling for typos in variables, i.e., incorrect log file path
* Add parameters for runtime options, i.e., -BackupDeletions
* Test with implementation via SolarWinds MSP Dashboard Automated Tasks rather than (or in addition to) Windows Task Scheduler