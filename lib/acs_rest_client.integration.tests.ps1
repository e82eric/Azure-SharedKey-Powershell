param($subscriptionId, $thumbprint, $namespace, $dataCenter, $workingDir = (Resolve-Path .\).Path)
$ErrorActionPreference = "stop"

$cert = Get-Item cert:\CurrentUser\My\$thumbprint

. "$workingDir\management_rest_client.ps1"
. "$workingDir\acs_rest_client.ps1"

$script:restClient = new_management_rest_client_with_cert_auth $subscriptionId $cert

function create_service_bus_namespace { param($name, $dataCenter)
	$def = "<entry xmlns='http://www.w3.org/2005/Atom'>
		<content type='application/xml'>
			<NamespaceDescription xmlns:i=`"http://www.w3.org/2001/XMLSchema-instance`" xmlns=`"http://schemas.microsoft.com/netservices/2010/10/servicebus/connect`">
				<Region>$dataCenter</Region>
			</NamespaceDescription>
		</content>
	</entry>"
	$script:restClient.ExecuteOperation2(@{ Verb = "PUT"; Resource = "services/ServiceBus/Namespaces/$name"; Content = $def; Version = "2013-08-01" })
	$confirmCreate = $false
	while(!$confirmCreate) {
		$status = $null
		$result = $script:restClient.Request(@{
			Verb = "GET";
			Resource = "services/servicebus/namespaces/$name";
			OnResponse = $parse_xml
		})
		$status = $result.NamespaceDescription.Status
		Write-Host "Status: $status"
		Start-Sleep -s 3
		if($status -eq "Active") {
			$confirmCreate = $true
		}
	}
}

function get_acs_key { param($name)
	$result = $script:restClient.Request(@{
		Verb = "GET";
		Resource = "services/servicebus/namespaces/$name/connectiondetails";
		OnResponse = $parse_xml 
	})
	$connectionString = $result.ArrayOfConnectionDetail.ConnectionDetail.ConnectionString
	$keyPart = $connectionString.split(';')[2]
	$start = $keyPart.indexOf("=") + 1
	$key = $keyPart.Substring($start, $keyPart.Length - $start)
	$key
}

function delete_service_bus_namespace { param($name) 
	$script:restClient.ExecuteOperation2(@{ Verb = "DELETE"; Resource = "services/servicebus/namespaces/$name"; Content = (New-Object byte[] 0); Version = "2013-08-01" })	

	while(!$confirmDelete) {
		try {
			$result = $script:restClient.Request(@{
				Verb = "GET";
				Resource = "services/servicebus/namespaces/$name";
				OnResponse = $parse_xml
			})
			Write-Host "Status: $($result.NamespaceDescription.Status)"
			Start-Sleep -s 3
		} catch {
			$e = $_.Exception
			while($e.Response -eq $null) {
				if($null -eq $e.InnerException) { break }
				$e = $e.InnerException
			}
			if($e.Response.StatusCode -eq "NotFound") {
				$confirmDelete = $true
			}
		}
	}
}

function create_identity { param($acsClient, $name, $actions)
	$content = "<?xml version=`"1.0`" encoding=`"utf-8`" standalone=`"yes`"?>
	<entry xmlns:d=`"http://schemas.microsoft.com/ado/2007/08/dataservices`" xmlns:m=`"http://schemas.microsoft.com/ado/2007/08/dataservices/metadata`" xmlns=`"http://www.w3.org/2005/Atom`">
		<category scheme=`"http://schemas.microsoft.com/ado/2007/08/dataservices/scheme`" term=`"Microsoft.Cloud.AccessControl.Management.ServiceIdentity`" />
		<title />
		<author>
			<name />
		</author>
		<updated>2014-08-01T10:17:57.7521432Z</updated>
		<id />
		<content type=`"application/xml`">
			<m:properties>
				<d:Description m:null=`"true`" />
				<d:Id m:type=`"Edm.Int64`">0</d:Id>
				<d:Name>$name</d:Name>
				<d:RedirectAddress m:null=`"true`" />
				<d:SystemReserved m:type=`"Edm.Boolean`">false</d:SystemReserved>
				<d:Version m:type=`"Edm.Binary`" m:null=`"true`" />
			</m:properties>
		</content>
	</entry>"

	$identity = $acsClient.Request(@{ Verb = "POST"; Resource = "v2/mgmt/service/ServiceIdentities"; Content = $content})
}

create_service_bus_namespace $namespace $dataCenter
$key = get_acs_key $namespace
$acsClient = new_acs_rest_client $namespace $key
create_identity $acsClient "identity1" $key
delete_service_bus_namespace $namespace
