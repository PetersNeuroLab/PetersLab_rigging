# Set archive and tape paths
$archivePath = "\\qnap-ap001.dpag.ox.ac.uk\APlab\Archive\to_archive"
$tapeDrive = "T"

# Set path for log
$datestring = (Get-Date).ToString("yyyy-MM-dd")
$logFilename = "\\qnap-ap001.dpag.ox.ac.uk\APlab\Archive\logs\move_to_archive_log\move_log_$datestring"

# Create (temporary) file with list of items to move
# (because TeraCopy scripting doesn't support wildcards)
$archiveList = [System.IO.Path]::GetTempFileName()

$foldersToArchive = Get-ChildItem -Path $archivePath
$foldersToArchive | ForEach-Object { $_.FullName } | Out-File -FilePath $archiveList

# Get total size of items to be moved
$archiveFilesSize = 0
foreach ($folder in $foldersToArchive) {
    # Get all files in the folder and subfolders
    $files = Get-ChildItem -Path $folder.FullName -Recurse -File

    # Sum the sizes of all files
    $folderSizeBytes = ($files | Measure-Object -Property Length -Sum).Sum
    $archiveFilesSize += $folderSizeBytes
}

# Get free space on tape (slightly hacky b/c LTFS - use fsutil, then parse text output)
$tape_fsutil = fsutil volume diskfree ($tapeDrive + ':')
$freeBytesLine = $tape_fsutil | Where-Object { $_ -match "Total free bytes" }
$freeBytesLine_noCommas = $freeBytesLine -replace ",", ""
$freeBytes = [double][regex]::Match($freeBytesLine_noCommas, "\d+").Value

# Check free space is enough for transfer
if ($freeBytes -ge $totalSizeBytes) {
    # Enough free space: move with TeraCopy
    & "C:\Program Files\TeraCopy\TeraCopy.exe" Move *$archiveList ($tapeDrive + ":\") /OverwriteAll /Verify /NoClose

} else {
    # Not enough free space: 
    
    # 1) create log of tape contents
    $tapeScriptPath = $PSScriptRoot
    $tapeLogScriptFilename = Join-Path -Path $tapeScriptPath -ChildPath "tape_log_contents.ps1"
    & $tapeLogScriptFilename

    # 2) eject tape   
    & "C:\Program Files\LTFS\LtfsCmdEject.exe" $tapeDrive

}

