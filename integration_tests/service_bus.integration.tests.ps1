param(
	$subscriptionId,
	$name,
	$dataCenter,
	$loginHint,
	$restLibDir = (Resolve-Path "..\lib").Path,
	$apiVersion = "2014-04-01"
)
$ErrorActionPreference = "stop"

. "$($restLibDir)\management_rest_client.ps1" $restLibDir
. "$($restLibDir)\service_bus_rest_client.ps1" $restLibDir

[Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions") | Out-Null

$managementRestClient = new_management_rest_client_with_adal $loginHint
$subscriptions = $managementRestClient.Request(@{ Verb = "GET"; Url = "https://management.core.windows.net/Subscriptions"; OnResponse = $parse_xml;})
$subscriptionAadTenantId = ($subscriptions.Subscriptions.Subscription | ? { $_.SubscriptionId -eq $subscriptionId }).AADTenantId
if($null -eq $subscriptionAadTenantId) {
	throw "Error: Unable to find aad tenant id for subscription: $($subscriptionId)"
}

$script:managementRestClient = new_subscription_management_rest_client_with_adal $subscriptionId $subscriptionAadTenantId $loginHint
$script:serializer = New-Object Web.Script.Serialization.JavaScriptSerializer

function create_namespace { param(
	[ValidateNotNullOrEmpty()] $name = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $dataCenter = $(throw "empty parameter")
)
	$body = 
		"<entry xmlns='http://www.w3.org/2005/Atom'>
			<content type='application/xml'>
				<NamespaceDescription xmlns:i=`"http://www.w3.org/2001/XMLSchema-instance`" xmlns=`"http://schemas.microsoft.com/netservices/2010/10/servicebus/connect`">
					<Region>$($dataCenter)</Region>
				</NamespaceDescription>
			</content>
		</entry>"

	$script:managementRestClient.ExecuteOperation2(@{ Verb = "PUT"; Resource = "services/ServiceBus/Namespaces/$($name)"; Content = $body; ContentType = "application/xml"; Version = "2015-04-01"; })
	$confirmCreate = $false

	while(!$confirmCreate) {
		$status = $null
		$result = $script:managementRestClient.Request(@{ Verb = "GET"; Resource = "services/servicebus/namespaces/$($name)"; OnResponse = $parse_xml; Accept = "application/atom+xml"; })
		$status = $result.entry.content.NamespaceDescription.Status
		Write-Host "INFO: Checking status of create service bus namespace operation. Status: $($status)"
		Start-Sleep -s 3
		if($status -eq "Active") {
			$confirmCreate = $true
		}
	}

	$sasAuthEnabled = $false
	while($false -eq $sasAuthEnabled) {
		try {
			Write-Host "INFO: Trying to see if sas auth to be enabled. Namespace: $($name)"
			create_queue $name "sashck"
			$sasAuthEnabled = $true
		} catch {
			Write-Host "INFO: Sas auth not enabled will try again in 15 seconds. Namespace: $($name)"
		}
		Start-Sleep -s 15
	}
	delete_queue $name "sashck"
}

function create_queue { param(
	[ValidateNotNullOrEmpty()] $namespace = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $name = $(throw "empty parameter")
)
	$def = '<entry xmlns="http://www.w3.org/2005/Atom">
			 <content type="application/xml">
					<QueueDescription xmlns="http://schemas.microsoft.com/netservices/2010/10/servicebus/connect" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
						 <LockDuration>PT30S</LockDuration>
						 <MaxSizeInMegabytes>1024</MaxSizeInMegabytes>
						 <RequiresDuplicateDetection>false</RequiresDuplicateDetection>
						 <RequiresSession>false</RequiresSession>
						 <DefaultMessageTimeToLive>P14D</DefaultMessageTimeToLive>
						 <DeadLetteringOnMessageExpiration>false</DeadLetteringOnMessageExpiration>
						 <DuplicateDetectionHistoryTimeWindow>PT10M</DuplicateDetectionHistoryTimeWindow>
						 <MaxDeliveryCount>10</MaxDeliveryCount>
						 <EnableBatchedOperations>true</EnableBatchedOperations>
						 <SizeInBytes>0</SizeInBytes>
						 <MessageCount>0</MessageCount>
					</QueueDescription>
			 </content>
		</entry>'
	
	$restClient = get_service_bus_rest_client $namespace
	$restClient.Request(@{ Verb = "PUT"; Resource = $name; Content = $def; ContentType = "application/atom+xml;type=entry;charset=utf-8."; }) | Out-Null
}

function delete_queue { param(
	[ValidateNotNullOrEmpty()] $namespace = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $name = $(throw "empty parameter")
)
	$restClient = get_service_bus_rest_client $namespace
	$restClient.Request(@{ Verb = "DELETE"; Resource = $name; }) | Out-Null
}

function get_service_bus_rest_client { param(
	[ValidateNotNullOrEmpty()] $namespace = $(throw "empty parameter")
)
	$connectionDetails = $script:managementRestClient.Request(@{ Verb = "GET"; Resource = "services/servicebus/namespaces/$($namespace)/connectiondetails"; OnResponse = $parse_xml; Accept = "application/atom+xml"; })
	$primaryKey = $connectiondetails.feed.entry.content.ConnectionDetail.ConnectionString.split(';')[2].Replace("SharedAccessKey=", "")
	$result = new_service_bus_rest_client_with_sas_auth $namespace $primaryKey "RootManageSharedAccessKey"
	$result
}

function create_event_hub { param(
	[ValidateNotNullOrEmpty()] $namespace = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $name = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $partitionCount = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $messageRetentionDays = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $keyName = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $primaryKey = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $secondaryKey = $(throw "empty parameter")
)
	$restClient = get_service_bus_rest_client $namespace

	$existing = $restClient.Request(@{
		Verb = "GET";
		Resource = "$($name)?api-version=2014-01";
		OnResponse = $parse_xml
	})

	$def = "<entry xmlns='http://www.w3.org/2005/Atom'>
		<content type='application/xml'>
			<EventHubDescription xmlns:i=`"http://www.w3.org/2001/XMLSchema-instance`" xmlns=`"http://schemas.microsoft.com/netservices/2010/10/servicebus/connect`">
				<MessageRetentionInDays>$($messageRetentionDays)</MessageRetentionInDays>
				<AuthorizationRules>
					<AuthorizationRule i:type=`"SharedAccessAuthorizationRule`">
						<ClaimType>SharedAccessKey</ClaimType>
						<ClaimValue>None</ClaimValue>
						<Rights>
							<AccessRights>Send</AccessRights>
							<AccessRights>Listen</AccessRights>
						</Rights>
						<KeyName>$($keyName)</KeyName>
						<PrimaryKey>$($primaryKey)</PrimaryKey>
						<SecondaryKey>$($secondaryKey)</SecondaryKey>
					</AuthorizationRule>
				</AuthorizationRules>
				<PartitionCount>$($partitionCount)</PartitionCount>
			</EventHubDescription>
		</content>
	</entry>"

	$restClient.Request(@{ Verb = "PUT"; Resource = "$($name)?api-version=2014-01"; Content = $def; ContentType = "application/json"; OnResponse = $parse_xml; }) | Out-Null
}

function create_consumer_group { param(
	[ValidateNotNullOrEmpty()] $namespace = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $name = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $path = $(throw "empty parameter")
)
	$restClient = get_service_bus_rest_client $namespace

	$def = '<entry xmlns="http://www.w3.org/2005/Atom">
		 <content type="application/xml">
				<ConsumerGroupDescription xmlns="http://schemas.microsoft.com/netservices/2010/10/servicebus/connect" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
				</ConsumerGroupDescription>
		 </content>
	</entry>'

	$restClient.Request(@{
		Verb = "PUT";
		Resource = "$($path)/consumerGroups/$($name)?api-version=2015-01";
		OnResponse = $parse_xml;
		Content = $def;
	}) | Out-Null
}

function delete_service_bus_namespace { param(
	[ValidateNotNullOrEmpty()] $name = $(throw "empty parameter")
) 
	$script:managementRestClient.ExecuteOperation("DELETE", "services/servicebus/namespaces/$name", (New-Object byte[] 0))	

	$confirmDelete = $false
	while(!$confirmDelete) {
		try {
			$result = $script:managementRestClient.Request(@{ Verb = "GET"; Resource = "services/servicebus/namespaces/$($name)"; OnResponse = $parse_xml; Accept = "application/atom+xml"})
			Write-Host "INFO: Checking delete service bus namespace operation. Status: $($result.entry.content.NamespaceDescription.Status)"
			Start-Sleep -s 3
		} catch {
			$e = $_.Exception
			while($e.Response -eq $null) {
				if($null -eq $e.InnerException) { break }
				$e = $e.InnerException
			}
			if($e.Response.StatusCode -eq "NotFound"){
				$confirmDelete = $true;
			} else {
				throw $_
			}
		}
	}
}

function create_password {
	$passwordProvider = New-Object Security.Cryptography.RngCryptoServiceProvider
	$passwordBytes = New-Object byte[] 32
	$passwordProvider.GetBytes($passwordBytes)
	[Convert]::ToBase64String($passwordBytes)
}

$eventHubName = "testhub"
create_namespace $name $dataCenter
create_event_hub $name $eventHubName 2 1 "testkey" (create_password) (create_password)
create_consumer_group $name "testgroup" $eventHubName
delete_service_bus_namespace $name
