param(
	$subscriptionId,
	$subscriptionAadTenantId,
	$dataCenter,
	$name = "resmaninttests",
	$apiVersion = "2014-04-01",
	$restLibDir = (Resolve-Path "..\lib").Path
)
$ErrorActionPreference = "stop"

. "$restLibDir\resource_manager_rest_client.ps1" $restLibDir

[Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions") | Out-Null

$script:restClient = new_resource_manager_rest_client $subscriptionId $subscriptionAadTenantId
$script:serializer = New-Object Web.Script.Serialization.JavaScriptSerializer
$script:apiVersion = $apiVersion

function create_server_farm { param($name, $resourceGroup, $dataCenter)
	$options = @{
		name = $name;
		location = $dataCenter;
		properties = @{
			sku = "Standard";
			workerSize = "1";
			numberOfWorkers = 1;
		}
	}

	$contentJson = $script:serializer.Serialize($options)

	$restClient.Request(@{
		Verb = "PUT";
		Resource = "resourcegroups/$resourceGroup/providers/Microsoft.Web/serverFarms/$name`?api-version=$script:apiVersion";
		OnResponse = $write_host;
		Content = $contentJson;
		ContentType = "application/json";
	})
}

function create_website { param($name, $serverFarm, $resourcGroup, $dataCenter)
	$options = @{
		location = $dataCenter;
		properties = @{
			computeMode = $null;
			name = $name;
			sku = "Standard";
			serverFarm = $serverFarm;
		};
		tags = @{}
	}

	$contentJson = $script:serializer.Serialize($options)

	$restClient.Request(@{
		Verb = "PUT";
		Resource = "resourcegroups/$resourceGroup/providers/Microsoft.Web/sites/$name`?api-version=$script:apiVersion";
		OnResponse = $write_host;
		Content = $contentJson;
		ContentType = "application/json";
	})
}

function delete_server_farm { param($name, $resourceGroup, $dataCenter)
	$restClient.Request(@{
		Verb = "DELETE";
		Resource = "resourcegroups/$resourceGroup/providers/Microsoft.Web/serverFarms/$name`?api-version=$script:apiVersion";
		OnResponse = $write_host;
	})
}

function delete_website { param($name, $resourceGroup, $dataCenter)
	$restClient.Request(@{
		Verb = "DELETE";
		Resource = "resourcegroups/$resourceGroup/providers/Microsoft.Web/sites/$name`?api-version=$script:apiVersion";
		OnResponse = $write_host;
	})
}

$shortDataCenter = $dataCenter.ToLower().Replace(" ", "")
$resourceGroup = "Default-Web-$shortDataCenter"

create_server_farm $name $resourceGroup $dataCenter
create_website $name $name $resourceGroup $dataCenter
delete_website $name $resourceGroup $dataCenter
delete_server_farm $name $resourceGroup $dataCenter
