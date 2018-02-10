# WindowsWWWCustomCleanup - Cleanup script for WWW log files and removal of old UpdraftPlus backups

<#
.SYNOPSIS
	This script cleans log files and backup files from web servers running WordPress with the UpdraftPlus plugin on Windows (IIS)
.DESCRIPTION
	Removes W3SVC log files older than a set number of days when the containing subfolder exceeds set bytes. Also forcefully removes WordPress UpdraftPlus backups older than a set number of days when they are found in the UpdraftPlus backup folder beyond their specified retention date (set within the UpdraftPlus plugin settings).
	
	WindowsWWWCustomCleanup.ps1 is built to run via automated task. As such, it generates its own small log files in a 'cleanup' subfolder and retains history indefinitely. Cleanup Report log files are set to rollover to a new file when filesize exceeds 25Mb.
.EXAMPLE
	First put WindowsWWWCustomCleanup.ps1 into a folder on your webhost. Remember the path to the script, as it will be required if implementing the script through Task Scheduler.
	
	Set variables in WindowsWWWCustomCleanup.ps1 specific to your environment. All variables are initialized at the top of the file. Default variable values should coincide with default settings from Windows, IIS, WordPress, and UpdraftPlus.
	
	Environmental Assumptions: Windows Server running IIS, WordPress installation (not Multisite), UpdraftPlus plugin installed in WordPress and saving backups to local disk. 
	
	For more information on UpdraftPlus, see:
	https://updraftplus.com/ or https://wordpress.org/plugins/updraftplus/
	
	Set up a scheduled task to run the script at a time and with the options best suited to your environment. Some environments may require a task scheduled to run daily, for example, while others may only need to run weekly.
	
	For more information on Windows Task Scheduler, see:
	https://msdn.microsoft.com/en-us/library/windows/desktop/aa384006.aspx
.NOTES
	Author	: Josef Cook - josef@assemblystudio.com (josef.cook@nettech.net)
#>

# WWW Log-related variables
$logFilePath = "C:\inetpub\logs\LogFiles"
$logFileSubfolders = @("\W3SVC1\","\W3SVC2\","\W3SVC3\")
$maxDaystoKeep = -5
$maxDirBytes = 500000000

# UpdraftPlus-related variables
$updraftBackupPath = "C:\inetpub\wwwroot\wp-content\updraft\"
$maxDaysofBackups = -21

# Output Report variables
$outputPath = "C:\inetpub\logs\cleanup\" 
$existingCleanLogs = New-Object System.Collections.ArrayList
$currentCleanLogFile = ""
$cleanupReportSectionHeader = "# Cleanup Task Run on " + (get-date -Format "yyyy-MM-dd @ hh:mm:ss") + " #"
$cleanupReportDirectories = "- WWW Log Folders Over 500Mb: "
$cleanupReportSkippedFolders = "- WWW Log Folders Over 500Mb With No Files Older Than " + $($maxDaystoKeep * -1) + " Days: "
$cleanupReportFiles = "- WWW Log Files Removed:"
$cleanupReportBackups = "- Updraft Backup Files Removed:"

# Make sure we have a directory for logging output
if ( Test-Path $outputPath ) {
	# If there, do nothing
	continue
} else {
	New-Item $outputPath -type directory
}

# Cleanup WWW Logs if dir size is getting too large
# Check each SVC sub dir individually
foreach ($subfolder in $logFileSubfolders) {
	if ( ((Get-ChildItem ($logFilePath + $subfolder) -Recurse | Measure-Object -Property Length -Sum -ErrorAction Stop).Sum) -gt $maxDirBytes ) {
	# Do this if dir size more than 500Mb
	
		# Indicate subfolders requiring cleaning in report
		$cleanupReportDirectories += $(if ($cleanupReportDirectories -match "SVC") {", "} else {""}) + $subfolder.trim("\")
	
		# Keep cleanup logging organized
		# See what cleanup logs already exist, then select the latest that is not too large
		$existingCleanLogs += Get-ChildItem $outputPath -Recurse -Include "*.log" | Foreach-Object {$_.Name}
		
		foreach ($cleanLogFile in $existingCleanLogs) {
			if ( $cleanLogFile.Length -gt 25000000 ) {
				# If cleaning logfile is over 25Mb, stop using it, go to next
				continue
			}
			else
			{
				# If cleaning logfile is under 25Mb, select it for logging cleanup
				$currentCleanLogFile = $cleanLogFile
				break
			}
		}
		
		# If no existing clean log file under 25Mb was found, create the next and make current
		if ( $currentCleanLogFile -eq "" ) {
			
			# See what the next file number should be
			$nextFileNum = $existingCleanLogs.Length + 1
			$fileNumPrefix = ""
			
			# Add zeros to maintain three-digit numbering system
			if ( $nextFileNum -lt 10 ) {
				$fileNumPrefix = "00"
			} 
			elseif ( $nextFileNum -lt 100 ) {
				$fileNumPrefix = "0"
			}
			
			$newCleanFileName = "Cleanup_Old_Logs_" + $fileNumPrefix + $nextFileNum + ".log"
			New-Item ($outputPath + $newCleanFileName) -type file -force
			
			$currentCleanLogFile = $newCleanFileName
		}
				
		# Check for any log files older than 5 days
		$itemsToDelete = dir ($logFilePath + $subfolder) -Recurse -Include "*.log" | Where-Object { $_.LastWriteTime -lt ((get-date).AddDays($maxDaystoKeep)) }
		
		# Remove old log files and note deletions, or note no candidates found
		if ($itemsToDelete.Count -gt 0){ 
			ForEach ($item in $itemsToDelete){ 
				$cleanupReportFiles += "`r`n" + "    " + $item.FullName + " last modified on " + $(get-date $item.LastWriteTime -Format "yyyy-MM-dd")
				
				# Get-item $item | Remove-Item -Verbose 
			} 
		} 
		else
		{ 
		# Indicate if a large folder has no files older than MaxDays to be deleted
		
			# See if we need to add a comma to this list
			if ($cleanupReportSkippedFolders -match "SVC") {
				$cleanupReportSkippedFolders += ", "
			}
				
			$cleanupReportSkippedFolders += $subfolder.trim("\")
		} 		
	}
	else
	{
	# Do nothing if dir size under 500Mb
	continue
	}
}

# Correct grammar of any report strings that have not changed from default
if ($cleanupReportDirectories -match "SVC") { continue } else { $cleanupReportDirectories += "None" }
if ($cleanupReportSkippedFolders -match "SVC") { continue } else { $cleanupReportSkippedFolders += "None" }
if ($cleanupReportFiles -match "modified") { continue } else { $cleanupReportFiles += "None" }

# Check Updraft Backups folder for files older than MaxDaysOfBackups (-21)
# Updraft on server is set to retain 2 weeks of backups, but was retaining much more
# This section of cleanup removes any backup sets older than 3 weeks, in case Updraft misses any again
if (Get-ChildItem $updraftBackupPath -Recurse -Include "*.txt" | Where-Object { $_.LastWriteTime -lt ((get-date).AddDays($maxDaysofBackups)) } ) {
# Do this if backup sets older than MaxDaysOfBackups are found

	# Remove outdated backup sets 
	$backupsToDelete = Get-ChildItem $updraftBackupPath -Recurse -Include *.txt, *.zip | Where-Object { $_.LastWriteTime -lt ((get-date).AddDays($maxDaysofBackups)) }
	
	ForEach ($backup in $backupsToDelete){ 
		$cleanupReportBackups += "`r`n" + "    " + $backup.FullName
		
		# Get-item $backup | Remove-Item -Verbose 
	}
}
else
{
# Do nothing if no backup sets older than MaxDaysOfBackups are found
continue
}

# Correct grammar if last report string has not changed from default
if ($cleanupReportBackups -match "C:") { continue } else { $cleanupReportBackups += "None" }

# Write all report lines to Current Cleanup Log File
$cleanupReportSet = $cleanupReportSectionHeader + "`r`n"
$cleanupReportSet += $cleanupReportDirectories + "`r`n"
$cleanupReportSet += $cleanupReportSkippedFolders + "`r`n"
$cleanupReportSet += $cleanupReportFiles + "`r`n"
$cleanupReportSet += $cleanupReportBackups + "`r`n" + "`r`n"

# Write output to SolarWinds Dashboard (when run via Automated Tasks)
Write-Output "Cleanup of log files older than $((get-date).AddDays($maxDaystoKeep)) completed." 

start-sleep -Seconds 10