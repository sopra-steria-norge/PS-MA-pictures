
param
(
	$Username,
	$Password,
	$OperationType
)


/*
# these delta properties are used for delta searches in Active Directory. When this script is called
# with the Delta operation type, it will only return users objects where one of the specified
# attributes has changed since last import
$DeltaPropertiesToLoad = @( "displayName", "distinguishedName", "homeDirectory", "objectGuid", "isDeleted" )

# the MASchemaProperties are the properties that this script will return to FIM on objects found
$MASchemaProperties = @( "givenName", "sn", "displayName", "homeDirectory", "sAMAccountName" )

$RootDse = [ADSI] "LDAP://RootDSE"
$Domain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($RootDse.defaultNamingContext)", $Username, $Password

$Searcher = New-Object System.DirectoryServices.DirectorySearcher $Domain, "(&(objectClass=user))", $DeltaPropertiesToLoad, 1
$Searcher.Tombstone = ($OperationType -match 'Delta')
$Searcher.CacheResults = $false

if ($OperationType -eq "Full" -or $RunStepCustomData -match '^$')
{
	# reset the directory synchronization cookie for full imports (or no watermark)
	$Searcher.DirectorySynchronization = New-Object System.DirectoryServices.DirectorySynchronization
}
else
{
	# grab the watermark from last run and pass that to the searcher
	$Cookie = [System.Convert]::FromBase64String($RunStepCustomData)
	$SyncCookie = ,$Cookie # forcing it to be of type byte[]
	$Searcher.DirectorySynchronization = New-Object System.DirectoryServices.DirectorySynchronization $SyncCookie
}

$Results = $Searcher.FindAll()
foreach ($Result in $Results)
{
	# we always add objectGuid and objectClass to all objects
	$obj = @{}
	$Obj.Add("objectGuid", ([GUID] $result.PSBase.Properties.objectguid[0]).ToString())
	$Obj.Add("objectClass", "user")
	if ( $result.Properties.Contains("isDeleted") )
	{
		# this is a deleted object, so we return a changeType of 'delete'; default changeType is 'Add'
		$Obj.Add("changeType", "Delete")
	}
	else
	{
		# we need to get the directory entry to get the additional attributes since
		# these are not available if we are running a delta import (DirSync) and
		# they haven't changed. Using just the SearchResult would only get us
		# the changed attributes on delta imports and we need more, oooh, so much more
		$DirEntry = $Result.GetDirectoryEntry()
		
		# always add the objectSid
		$Obj.Add("objectSid", (New-Object System.Security.Principal.SecurityIdentifier($DirEntry.Properties["objectSid"][0], 0)).ToString() )
		
		# add the attributes defined in the schema for this MA
		$MASchemaProperties | ForEach-Object `
		{
			if ($DirEntry.Properties.Contains($_))
			{
				$Obj.Add($_, $DirEntry.Properties[$_][0])
			}
		}
	}
	$Obj
}

# grab the synchronization cookie value to use for next delta/watermark
# and put it in the $RunStepCustomData. It is important to mark the $RunStepCustomData
# as global, otherwise FIM cannot pick it up and delta's won't work correctly
$global:RunStepCustomData = [System.Convert]::ToBase64String($Searcher.DirectorySynchronization.GetDirectorySynchronizationCookie())

*/