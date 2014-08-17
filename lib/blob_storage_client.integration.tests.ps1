param($subscriptionId, $thumbprint, $storageAccountName, $dataCenter, $workingDir = (Resolve-Path .\).Path)
$ErrorActionPreference = "stop"

$cert = Get-Item cert:\CurrentUser\My\$thumbprint

. "$workingDir\management_rest_client.ps1"
. "$workingDir\blob_storage_client.ps1"

$script:restClient = new_management_rest_client_with_cert_auth $subscriptionId $cert

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

function list_containers { param($blobClient)
	$result = $blobClient.Request(@{
		Verb = "GET";
		Resource = "?comp=list";
		ProcessResponse = $parse_xml
	})

	$result.EnumerationResults.Containers.Container | % { Write-Host $_.Name }
}

function put_text_blob { param($name, $container, $content, $blobClient)
	$blobClient.Request(@{
		Verb = "PUT";
		Resource = "$container/$name";
		Content = $content;
		BlobType = "BlockBlob";
	})
}

function list_blobs { param($container, $blobClient)
	$result = $blobClient.Request(@{
		Verb = "GET";
		Resource = "$($container)?restype=container&comp=list";
		ProcessResponse = $parse_xml;
	})

	$result.EnumerationResults.Blobs.Blob | % { Write-Host $_.Name }
}

function get_blob { param($container, $fileName)
	$result = $blobClient.Request(@{
		Verb = "GET";
		Resource = "$container/$fileName";
		ProcessResponse = $parse_text;
	})
	Write-Host $result
}

function set_account_properties { param($blobClient)
	$propsDef = `
	'<?xml version="1.0" encoding="utf-8"?>
	<StorageServiceProperties>
			<Cors>
		<CorsRule>
				<AllowedOrigins>http://www.fabrikam.com,http://www.contoso.com</AllowedOrigins>
				<AllowedMethods>GET,PUT</AllowedMethods>
				<MaxAgeInSeconds>500</MaxAgeInSeconds>
				<ExposedHeaders>x-ms-meta-data*,x-ms-meta-customheader</ExposedHeaders>
				<AllowedHeaders>x-ms-meta-target*,x-ms-meta-customheader</AllowedHeaders>
		</CorsRule>
			</Cors>
	</StorageServiceProperties>'

	$blobClient.Request(@{
		Verb = "PUT";
		Resource = "?restype=service&comp=properties";
		Content = $propsDef;
	})
}

function get_account_properties { param($blobClient)
	$result = $blobClient.Request(@{
		Verb = "GET";
		Resource = "?restype=service&comp=properties";
		ProcessResponse = $parse_xml;
	})

	Write-Host $result.OuterXml
}

function set_container_metadata { param($container, $metadata, $blobClient)
	$blobClient.Request(@{
		Verb = "PUT";
		Resource = "$($container)?restype=container&comp=metadata";
		Headers = $metadata;
		Content = (New-Object byte[] 0)
	})
}

function get_container_metadata { param($container, $blobClient)
	$result = $blobClient.Request(@{
		Verb = "GET";
		Resource = "$($container)?restype=container&comp=metadata";
		ProcessResponse = $parse_ms_headers
	})
	
	$result | % { Write-Host "$($_.name): $($_.value)" }
}

function set_container_acl { param($container, $blobClient)
	$aclDef = `
		'<?xml version="1.0" encoding="utf-8"?>
		<SignedIdentifiers>
			<SignedIdentifier> 
				<Id>MTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTI=</Id>
				<AccessPolicy>
					<Start>2009-09-28T08:49:37.0000000Z</Start>
					<Expiry>2039-09-29T08:49:37.0000000Z</Expiry>
					<Permission>rwd</Permission>
				</AccessPolicy>
			</SignedIdentifier>
		</SignedIdentifiers>'

	$blobClient.Request(@{
		Verb = "PUT";
		Resource = "$($container)?restype=container&comp=acl";
		Content = $aclDef
	})
}

function get_container_acl { param($container, $blobClient)
	$result = $blobClient.Request(@{
		Verb = "GET";
		Resource = "$($container)?restype=container&comp=acl";
		ProcessResponse = $parse_xml
	})

	Write-Host $result.OuterXml
}

function set_blob_metadata { param($container, $fileName, $metadata, $blobClient)
	$blobClient.Request(@{
		Verb = "PUT";
		Resource = "$container/$($fileName)?comp=metadata";
		Headers = $metadata;
		Content = (New-Object byte[] 0)
	})
}

function get_blob_metadata { param($container, $fileName, $blobClient)
	$result = $blobClient.Request(@{
		Verb = "GET";
		Resource = "$container/$($fileName)?comp=metadata";
		ProcessResponse = $parse_ms_headers
	})
	
	$result | % { Write-Host "$($_.name): $($_.value)" }
}

function copy_blob { param($account, $container, $fileName, $newName, $blobClient)
	$blobClient.Request(@{
		Verb = "PUT";
		Resource = "$container/$newName";
		Headers = @(@{ name = "x-ms-copy-source"; value = "https://$($account).blob.core.windows.net/$container/$fileName" });
		Content = (New-Object byte[] 0)
	})
}

create_storage_account $storageAccountName $dataCenter
$storageKey = get_storage_key $storageAccountName
$blobClient = new_blob_storage_client $storageAccountName $storageKey
set_account_properties $blobClient
get_account_properties $blobClient

$containerName = "acont"

create_container $containerName $blobClient
list_containers $blobClient
set_container_acl $containerName $blobClient
get_container_acl $containerName $blobCLient
set_container_metadata $containerName @(
	@{ name = "x-ms-meta-prop1"; value = "p1" },
	@{ name = "x-ms-meta-prop2"; value = "p2" }
) $blobClient

get_container_metadata $containerName $blobClient

put_text_blob "test1.txt" $containerName "Test File 1" $blobClient
copy_blob $storageAccountName $containerName "test1.txt" "test2.txt" $blobClient
list_blobs $containerName $blobClient
get_blob $containerName "test1.txt"
set_blob_metadata $containerName "test1.txt" @(
	@{ name = "x-ms-meta-prop1"; value = "p1" },
	@{ name = "x-ms-meta-prop2"; value = "p2" }
) $blobClient
get_blob_metadata $containerName "test1.txt" $blobClient
delete_container $containerName $blobClient
delete_storage_account $storageAccountName
