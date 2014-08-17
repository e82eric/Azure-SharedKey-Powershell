param($subscriptionId, $thumbprint, $storageAccountName, $dataCenter, $workingDir = (Resolve-Path .\).Path)
$ErrorActionPreference = "stop"

$cert = Get-Item cert:\CurrentUser\My\$thumbprint

. "$workingDir\management_rest_client.ps1"
. "$workingDir\table_storage_client.ps1"

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

function create_table { param($tableName, $tableClient)
	$tableClient.Request(@{
		Verb = "POST";
		ContentType = "application/json";
		Accept = "application/json;odata=nometadata";
		Resource = "tables";
		Content = "{`"TableName`":`"$tableName`"}" 
	})
}

function delete_table { param($tableName, $tableClient)
	$tableClient.Request(@{
		Verb = "DELETE";
		ContentType = "application/json";
		Accept = "application/json;odata=nometadata";
		Resource = "tables('$tableName')";
		Content = "{`"TableName`":`"$tableName`"}"
	})
}

function insert_entity { param($tableName, $entity, $tableClient)
	$tableClient.Request(@{
		Verb = "POST";
		ContentType = "application/json";
		Accept = "application/json;odata=nometadata";
		Resource = $tableName;
		Content = $entity
	})
}

function merge_entity { param($tableName, $partitionKey, $rowKey, $entity, $tableClient)
	$tableClient.Request(@{
		Verb = "MERGE";
		ContentType = "application/json";
		Accept = "application/json;odata=nometadata";
		Resource = "$tableName(PartitionKey='$partitionKey',RowKey='$rowKey')";
		Content = $entity
	})
}

function update_entity { param($tableName, $partitionKey, $rowKey, $entity, $tableClient)
	$tableClient.Request(@{
		Verb = "PUT";
		ContentType = "application/json";
		Accept = "application/json;odata=nometadata";
		Resource = "$tableName(PartitionKey='$partitionKey',RowKey='$rowKey')";
		Content = $entity
	})
}

function delete_entity { param($tableName, $partitionKey, $rowKey, $tableClient)
	$tableClient.Request(@{
		Verb = "DELETE";
		Resource = "$tableName(PartitionKey='$partitionKey',RowKey='$rowKey')";
		Headers = @(@{ name = "If-Match"; value = "*"})
	})
}

function query_entities { param($resource, $tableClient)
	$result = $tableClient.Request(@{
		Verb = "GET";
		ContentType = "application/json";
		Accept = "application/json;odata=nometadata";
		Resource = $resource;
		Content = $entity;
		ProcessResponse = $parse_json
	})

	$entities = $result 

	if($null -ne $result.value) {
		$entities = $result.value	
	}

	$entities | % {
		$_.GetEnumerator() | % { Write-Host "$($_.Key):$($_.Value)" }
	}
}

function query_tables { param($tableClient)
	$result = $tableClient.Request(@{
		Verb = "GET";
		ContentType = "application/json";
		Accept = "application/json;odata=nometadata";
		Resource = "tables()";
		Content = $entity;
		ProcessResponse = $parse_json
	})

	$entities = $result 

	if($null -ne $result.value) {
		$entities = $result.value	
	}

	$entities | % {
		$_.GetEnumerator() | % { Write-Host "$($_.Key):$($_.Value)" }
	}
}

create_storage_account $storageAccountName $dataCenter
$storageKey = get_storage_key $storageAccountName
$tableClient = new_table_storage_client $storageAccountName $storageKey

$tableName = "atest"
create_table $tableName $tableClient
insert_entity $tableName '{ "Name":"n1","RowKey":"1","PartitionKey":"1" }' $tableClient
merge_entity $tableName "1" "1" '{ "Name":"n2","RowKey":"1","PartitionKey":"1" }' $tableClient
merge_entity $tableName "1" "2" '{ "Name":"n2","RowKey":"2","PartitionKey":"1" }' $tableClient
update_entity $tableName "1" "2" '{ "Name2":"n3","RowKey":"2","PartitionKey":"1" }' $tableClient
query_entities "$tableName()" $tableClient
query_entities "$tableName(PartitionKey='1',RowKey='1')" $tableClient
query_entities "$tableName()?$filter=(Name='n2')" $tableClient
query_tables $tableClient
delete_entity $tableName "1" "2" $tableClient
delete_table $tableName $tableClient
delete_storage_account $storageAccountName
