param(
	$subscriptionId,
	$adTenantId,
	$prefix,
	$dataCenter,
	$loginHint,
	$adLoginHint,
	$libDir = (Resolve-Path ..\lib).Path,
	$workingDir = (Resolve-Path .).Path
)
$VerbosePreference = "Continue"
$DebugPreference = "SilentlyContinue"
$ErrorActionPreference = "stop"
(Get-Host).PrivateData.VerboseForegroundColor = "cyan"
(Get-Host).PrivateData.DebugForegroundColor = "green"

& "$($workingDir)\service_bus.integration.tests.ps1" $subscriptionId "$($prefix)rsbus" $dataCenter $loginHint $libDir
& "$($workingDir)\acs_rest_client.integration.tests.ps1" $subscriptionId "$($prefix)acs" $dataCenter $loginHint $libDir
& "$($workingDir)\azure_ad_rest_client.integration.tests.ps1" $adTenantId "$($prefix)ad" $adLoginHint $libDir
& "$($workingDir)\blob_storage_client.integration.tests.ps1" $subscriptionId "$($prefix)bstor" $dataCenter $loginHint $libDir
& "$($workingDir)\resource_manager_rest_client.integration.tests.ps1" $subscriptionId "$($prefix)resman" $dataCenter $loginHint $libDir
& "$($workingDir)\shared_access_signature.integration.tests.ps1" $subscriptionId "$($prefix)sasstor" $dataCenter $loginHint $libDir
& "$($workingDir)\service_bus_rest_client.integration.tests.ps1" $subscriptionId "$($prefix)sbus" $dataCenter $loginHint $libDir
& "$($workingDir)\table_storage_client.integration.tests.ps1" $subscriptionId "$($prefix)tstor" $dataCenter $loginHint $libDir
