################################################################################## 
# 
# 
#  Script name: Import.ps1
#  Author:      Didier Rossi and Remi Vandemir
#  Homepage:    www.iamblogg.com - http://blog.goverco.com
#  Created:                         14. April 2013
# 
################################################################################## 
#
# This script require the module image
# http://blogs.msdn.com/b/powershell/archive/2009/03/31/image-manipulation-in-powershell.aspx
# Simply download and unzip the file into a directory called Image underneath 
# $env:UserProfile\Documents\WindowsPowerShell\Modules or C:\Windows\System32\WindowsPowerShell\v1.0\Modules and then run Import-Module Image
#
# TODO: Use binary type (instead of Base64 string) to removed the need for rules extension.
#

PARAM
(
	$Username,
	$Password,
	$OperationType
)

$debug = $false
Import-Module Image

# Schema creation in FIM
# Put this commands in a seperate file named schema.ps1 and call it from the Powershell MA.
#$obj = New-Object -Type PSCustomObject 
#$obj | Add-Member -Type NoteProperty -Name "objectClass|String" -Value "user" 
#$obj | Add-Member -Type NoteProperty -Name "Anchor-AccountName|String" -Value "IAMBLOGG" 
#$obj | Add-Member -Type NoteProperty -Name "Picture|String" -Value "999999" 
# or (binary still not working)
#$obj | Add-Member -Type NoteProperty -Name "Picture|String" -Value "FF" 
#$obj

#
# Configuration params
#
# Your path to images
$picturesDir = 'C:\Temp\Mypictures'

#This filter search for images with filenavn: NAME#ACCOUNTNAME.JPG - Change it to your needs.
$filter      = "*#*.jp*g"

if ($OperationType -eq "Full" -or $global:RunStepCustomData -match '^$')
{
	# Reset timestamp for full imports (or no watermark)
	$timeStamp = get-date('1/1/1601')
}
else
{
	# Grab the watermark from last run and pass that to the timestamp
    # Convert from WMI date format (DMTF)  
	$timeStamp = [System.Management.ManagementDateTimeConverter]::ToDateTime($global:RunStepCustomData)
}

# Scale images to fit in AD and FIM portal. 96x96px
$imgFilter = Add-ScaleFilter -Width 96 -Height 96 -passThru

$items = Get-ChildItem -Filter $filter -Path $picturesDir -Recurse | Where-Object {$_.LastWriteTimeUtc -ge $timestamp}
#PS 3.0 cmld: $items = Get-ChildItem -Filter $filter -File -Path $pictureDir -Recurse | Where-Object {$_.LastWriteTimeUtc -ge $timestamp}

# Enumerate the items array
foreach ($item in ($items | Sort-Object LastWriteTime) )
{
    $obj = @{}
    $obj.Add("objectClass", "user")
	if ( ($item.Attributes -ne "Directory") -And ($item.name -match "^.+#(.+)\.jpe*g$")) {
    #PS 3.0 cmld: if ($item.name -match "^.+#(.+)\.jpe*g$") {
	$obj.Add("AccountName", $matches[1].toUpper())
	try {
			$image = Get-Image $item.FullName            
			$image = $image | Set-ImageFilter -filter $imgFilter -passThru
# Does not work (bug i MA?) [byte[]] $b = $image.FileData.BinaryData
			$obj.Add("Picture",[System.Convert]::ToBase64String($b))
			$obj.Add("Picture",$b)
			If ($debug) {
				$fName =  "{0}\\{1}.jpeg" -f $picturesDir, $obj["AccountName"]
				If (Test-Path $fName){ Remove-Item $fName }
				$image.SaveFile($fName)
			}
		}
	catch {
			$obj.Add("[ErrorName]", "file-error")
			$obj.Add("[ErrorDetail]", "Maybe wrong picture format {0}" -f $item.Name)	
		}
    }
    else {
        $obj.Add("[ErrorName]", "file-error")
        $obj.Add("[ErrorDetail]", "Unexpected file name {0}" -f $item.Name)
    }

    if ($debug) { $obj.Add("LastWriteTimeUtc", $item.LastWriteTimeUtc) }

    $timeStamp = $item.LastWriteTimeUtc

    $obj
}

# Same the watermark -> timestamp
#$timeStamp = Get-Date
#$timeStamp = $today.ToUniversalTime()
# Convert to WMI date format (DMTF) - it's a string  
$global:RunStepCustomData = [System.Management.ManagementDateTimeConverter]::ToDmtfDateTime($timeStamp)

