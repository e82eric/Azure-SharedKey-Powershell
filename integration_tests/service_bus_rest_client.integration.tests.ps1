param(
	$subscriptionId,
	$thumbprint,
	$namespace,
	$dataCenter,
	$libDir = (Resolve-Path ..\lib).Path)
$ErrorActionPreference = "stop"

$cert = Get-Item cert:\CurrentUser\My\$thumbprint

. "$libDir\management_rest_client.ps1" $libDir
. "$libDir\service_bus_rest_client.ps1" $libDir

$script:restClient = new_subscription_management_rest_client_with_cert_auth $subscriptionId $cert

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
	$connectionString = ($result.ArrayOfConnectionDetail.ConnectionDetail | ? { $_.KeyName -eq "ACSOwnerKey" }).ConnectionString
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

function create_queue { param($serviceBusClient, $namespace, $name)
	$def = "<entry xmlns=`"http://www.w3.org/2005/Atom`">
			<content type=`"application/atom+xml;type=entry;charset=utf-8`">
				<QueueDescription xmlns=`"http://schemas.microsoft.com/netservices/2010/10/servicebus/connect`">
					<MaxSizeInMegabytes>0</MaxSizeInMegabytes>
					<RequiresDuplicateDetection>false</RequiresDuplicateDetection>
					<RequiresSession>false</RequiresSession>
					<DeadLetteringOnMessageExpiration>false</DeadLetteringOnMessageExpiration>
					<EnableBatchedOperations>false</EnableBatchedOperations>
					<SizeInBytes>0</SizeInBytes>
					<MessageCount>0</MessageCount>
					<IsAnonymousAccessible>false</IsAnonymousAccessible>
					<AuthorizationRules />
					<SupportOrdering>false</SupportOrdering>
				</QueueDescription>
			</content>
		</entry>"

	$script:restClient.Request(@{ Verb = "PUT"; Resource = "services/ServiceBus/namespaces/$namespace/queues/$name/"; Content = $def; ContentType = "application/atom+xml" })
}

create_service_bus_namespace $namespace $dataCenter
$key = get_acs_key $namespace
$serviceBusClient = new_acs_rest_client $namespace $key
create_queue $serviceBusClient $namespace "queue1"
delete_service_bus_namespace $namespace
