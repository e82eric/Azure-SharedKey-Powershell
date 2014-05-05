param($subscriptionId, $thumbprint, $storageAccountName, $dataCenter, $workingDir = (Resolve-Path .\).Path)
$ErrorActionPreference = "stop"

$cert = Get-Item cert:\CurrentUser\My\$thumbprint

. "$workingDir\azure_rest_client.ps1"
. "$workingDir\blob_storage_client.ps1"

$script:restClient = new_azure_rest_client $subscriptionId $cert

function create_storage_account { param($name, $dataCenter)
	$storageAccountDef = `
		"<?xml version=`"1.0`" encoding=`"utf-8`"?>
		<CreateStorageServiceInput xmlns=`"http://schemas.microsoft.com/windowsazure`">
		  <ServiceName>$name</ServiceName>
		  <Description></Description>
		  <Label>$([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($name)))</Label>
		  <Location>$dataCenter</Location>
		  <GeoReplicationEnabled>true</GeoReplicationEnabled>
		</CreateStorageServiceInput>"

	$script:restClient.ExecuteOperation("POST", "services/storageservices", $storageAccountDef)
}

function delete_storage_account { param($name)
	$result = $script:restClient.Request(@{
		Verb = "GET";
		Resource = "services/storageservices";
		OnResponse = $parse_xml;
	})
	$resource = $result.StorageServices.StorageService | ? { $_.ServiceName -eq $name }

	if($resource -ne $null) {
		$script:restClient.ExecuteOperation("DELETE", "services/storageservices/$name", (New-Object byte[] 0))
	}
}

function get_storage_key { param($name)
	$result = $script:restClient.Request(@{
		Verb = "GET";
		Resource = "services/storageservices/$name/keys";
		OnResponse = $parse_xml
	})
	$result.StorageService.StorageServiceKeys.Secondary
}

function create_container { param($name, $blobClient)
	$blobClient.Request(@{
		Verb = "PUT";
		Resource = "$($name)`?restype=container";
		Content = (New-Object byte[] 0)
	})
}

function delete_container { param($name, $blobClient)
	$blobClient.Request(@{
		Verb = "DELETE";
		Resource = "$($name)`?restype=container"
	})
}

create_storage_account $storageAccountName $dataCenter
$storageKey = get_storage_key $storageAccountName
$blobClient = new_blob_storage_client $storageAccountName $storageKey

$containerName = "acont"

create_container $containerName $blobClient
delete_container $containerName $blobClient
delete_storage_account $storageAccountName
