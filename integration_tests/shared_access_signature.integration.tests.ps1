param(
	$subscriptionId,
	$thumbprint,
	$storageAccountName,
	$dataCenter,
	$libDir = (Resolve-Path ..\lib).Path)
$ErrorActionPreference = "stop"

$cert = Get-Item cert:\CurrentUser\My\$thumbprint

. "$libDir\management_rest_client.ps1" $libDir
. "$libDir\shared_access_signature_provider.ps1" $libDir
. "$libDir\blob_storage_client.ps1" $libDir

$script:restClient = new_subscription_management_rest_client_with_cert_auth $subscriptionId $cert

function create_storage_account { param($name, $dataCenter)
	$storageAccountDef = `
		"<?xml version=`"1.0`" encoding=`"utf-8`"?>
		<CreateStorageServiceInput xmlns=`"http://schemas.microsoft.com/windowsazure`">
			<ServiceName>$name</ServiceName>
			<Description></Description>
			<Label>$([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($name)))</Label>
			<Location>$dataCenter</Location>
			<AccountType>Standard_LRS</AccountType>
		</CreateStorageServiceInput>"

	$script:restClient.ExecuteOperation("POST", "services/storageservices", $storageAccountDef)
}

function get_storage_key { param($name)
	$result = $script:restClient.Request(@{
		Verb = "GET";
		Resource = "services/storageservices/$name/keys";
		OnResponse = $parse_xml
	})
	$result.StorageService.StorageServiceKeys.Secondary
}

function delete_storage_account { param($name)
	$result = $script:restClient.Request(@{
		Verb = "GET";
		Resource = "services/storageservices";
		OnResponse = $parse_xml;
	})
	$resource = $result.StorageServices.StorageService | ? { $_.ServiceName -eq $name }

	if($resource -ne $null) {
		$script:restClient.ExecuteOperation(
			"DELETE",
			"services/storageservices/$name",
			(New-Object byte[] 0)
		)
	}
}

function upload_blob { param($sasProvider, $containerName, $blobName)
	$sas = $sasProvider.GetUrl("$containerName/$blobName", "b", "w", [DateTime]::UtcNow.AddMinutes(1))
	$webClient = New-Object Net.WebClient
	$webClient.Headers.Add("x-ms-blob-type", "BlockBlob")
	$webClient.UploadString($sas, "PUT", "blob test")
}

function download_blob { param($sasProvider, $containerName, $blobName)
	$sas = $sasProvider.GetUrl("$containerName/$blobName", "b", "r", [DateTime]::UtcNow.AddMinutes(1))
	$webClient = New-Object Net.WebClient
	$webClient.DownloadString($sas)
}

function create_container { param($name, $blobClient)
	$blobClient.Request(@{
		Verb = "PUT";
		Resource = "$($name)`?restype=container";
		Content = (New-Object byte[] 0)
	})
}

create_storage_account $storageAccountName $dataCenter
$storageKey = get_storage_key $storageAccountName
$sasProvider = new_shared_access_signature_provider $storageAccountName $storageKey
$blobClient = new_blob_storage_client $storageAccountName $storageKey

$containerName = "tests"
$blobName = "test.txt"

create_container $containerName $blobClient
upload_blob $sasProvider $containerName $blobName
download_blob $sasProvider $containerName $blobName
