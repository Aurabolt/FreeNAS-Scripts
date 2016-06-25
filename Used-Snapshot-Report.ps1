<#

Used-Snapshot-Report.ps1
Aurabolt
2016-06-25

FreeNAS Snapshots used space report
Gathers info via SSH

#>

# Modify these variables:
# --------------------------------------------------
$freenasHostname = "freenas"
$port = 22
$sshUser = "user"
$volumeName = "tank"
# --------------------------------------------------

#$csv = "$PSScriptRoot\snapshot-info.csv"
$passwordFile = "$PSScriptRoot\password.txt"

if(!(Test-Path $passwordFile)){    
    # Create encrypted password file
    $password = Read-Host "Password for FreeNAS SSH user '$sshUser'" -AsSecureString
    $password | ConvertFrom-SecureString | Out-File $passwordFile
}

# Read and decrypt password file
$pass = Get-Content $passwordFile | ConvertTo-SecureString
$cred = New-Object Management.Automation.PSCredential ($sshUser, $pass)

# Download and load Posh-SSH module
# --------------------------------------------------
$webclient = New-Object System.Net.WebClient
$url = "https://github.com/darkoperator/Posh-SSH/archive/master.zip"
Write-Host "Downloading latest version of Posh-SSH from`n$url" -ForegroundColor Cyan
$file = "$($env:TEMP)\Posh-SSH.zip"
$webclient.DownloadFile($url,$file)
Write-Host "File saved to $file" -ForegroundColor Green
$targetondisk = "$($env:USERPROFILE)\Documents\WindowsPowerShell\Modules"
New-Item -ItemType Directory -Force -Path $targetondisk | out-null
$shell_app=new-object -com shell.application
$zip_file = $shell_app.namespace($file)
Write-Host "Uncompressing the Zip file to`n$($targetondisk)" -ForegroundColor Cyan
$destination = $shell_app.namespace($targetondisk)
$destination.Copyhere($zip_file.items(), 0x10) | Out-Null
Write-Host "Renaming folder" -ForegroundColor Cyan
Rename-Item -Path ($targetondisk+"\Posh-SSH-master") -NewName "Posh-SSH" -Force -ErrorAction SilentlyContinue | Out-Null
Write-Host "Posh-SSH module has been installed`n---------------------------`n" -ForegroundColor Green
Import-Module -Name posh-ssh | Out-Null
Get-Command -Module Posh-SSH | Out-Null
# --------------------------------------------------

# SSH to FreeNAS
$ssh = New-SSHSession $freenasHostname -Credential $cred -Port $port -AcceptKey

# Execute SSH command to get snapshot info
$output = (Invoke-SSHCommand -Index 0 -Command "zfs list -o space | grep -i $volumeName").output

$totalUsedSnaps = 0

foreach($line in $output){
    $line = ($line -replace '\s+', ' ').split()
    Write-Host $line[3] "`t" $line[0] 

    $size = $line[3]
    if($size -match "K") { $size = [double]($size -replace "K","")/1024/1024 }
    elseif($size -match "M") { $size = [double]($size -replace "M","")/1024 }
    elseif($size -match "G") { $size = [double]($size -replace "G","") }
    elseif($size -match "T") { $size = [double]($size -replace "T","")*1024 }
    else { $size = 0 }

    $totalUsedSnaps += $size
}

$totalUsedSnaps = [math]::Round($totalUsedSnaps,2)
Write-Host "`n${totalUsedSnaps}G`t Total used snapshots"