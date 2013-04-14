#
# This script require the module image
# http://blogs.msdn.com/b/powershell/archive/2009/03/31/image-manipulation-in-powershell.aspx
# Simply download and unzip the file into a directory called Image underneath 
# $env:UserProfile\Documents\WindowsPowerShell\Modules and then run Import-Module Image
#
param
(
	$Username,
	$Password,
	$OperationType
)

$debug = $false

# Schema creation in FIM
#$obj = New-Object -Type PSCustomObject 
#$obj | Add-Member -Type NoteProperty -Name "objectClass|String" -Value "user" 
#$obj | Add-Member -Type NoteProperty -Name "Anchor-AccountName|String" -Value "REVX" 
#$obj | Add-Member -Type NoteProperty -Name "Picture|String" -Value "999999" 

#
# Configuration params (would have been great to get those from FIM
#
$picturesDir = "C:\temp\test"
$filter      = "*#*.jp*g"

if ($OperationType -eq "Full" -or $RunStepCustomData -match '^$')
{
	# reset timestamp for full imports (or no watermark)
	$timeStamp = get-date('1/1/1601')
}
else
{
	# grab the watermark from last run and pass that to the timestamp
    # Convert from WMI date format (DMTF)  
	$timeStamp = [System.Management.ManagementDateTimeConverter]::ToDateTime($RunStepCustomData)
}


$imgFilter = Add-ScaleFilter -width 96 -height 96 -passThru

# PS2.0 does not support "-File" param 
$items = Get-ChildItem -Filter $filter -Path $picturesDir -Recurse | Where-Object {$_.LastWriteTimeUtc -ge $timestamp}


# enumerate the items array
foreach ($item in ($items | Sort-Object LastWriteTime) )
{
    $obj = @{}
    $obj.Add("objectClass", "user")

    if ( ($item.Attributes -ne "Directory") -And ($item.name -match "^.+#(.+)\.jpe*g$")) {
        $obj.Add("AccountName", $matches[1].toUpper())
        
        $image = Get-Image $item.FullName            
        $image = $image | Set-ImageFilter -filter $imgFilter -passThru
        $b = $image.FileData.BinaryData
        $obj.Add("Picture",[System.Convert]::ToBase64String($b))
        If ($debug) {
            $fName =  "{0}\\{1}.jpeg" -f $picturesDir, $obj["AccountName"]
            If (Test-Path $fName){ Remove-Item $fName }
            $image.SaveFile($fName)
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

