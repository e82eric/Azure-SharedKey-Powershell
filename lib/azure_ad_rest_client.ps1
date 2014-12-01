param(
	$restLibDir = (Resolve-Path .\).Path,
	$adalLibDir = (Resolve-Path ..\libs).Path
)

$ErrorActionPreference = "stop"

. "$restLibDir\request_builder.ps1"
. "$restLibDir\retry_handler.ps1"
. "$restLibDir\request_handler.ps1"
. "$restLibDir\response_handlers.ps1"
. "$restLibDir\resource_manager_options_patcher.ps1"
. "$restLibDir\aad_token_provider.ps1" $adalLibDir
. "$restLibDir\aad_file_cache_token_provider.ps1"
. "$restLibDir\rest_client.ps1"
. "$restLibDir\simple_options_patcher.ps1"
. "$restLibDir\config.ps1"

function new_azure_ad_rest_client {
	param(
		[ValidateNotNullOrEmpty()]$adTenantId = $(throw "adTenantId is mandatory"),
		$cacheIdentifier,
		$defaultVersion = $(__.azure.rest.get_config "management_version"),
		$defaultScheme = $(__.azure.rest.get_config "scheme"),
		$defaultRetryCount = $(__.azure.rest.get_config "retry_count"),
		$defaultContentType = $(__.azure.rest.get_config "management_content_type"),
		$defaultTimeout = $(__.azure.rest.get_config "timeout"),
		$fileTokenCachePath = "$env:userprofile\aad_tokens.dat"
	)

	if($null -eq $cacheIdentifier) {
		$cacheIdentifier = "$adTenantId`_azure_ad_management"
	}

	$aadResource = "https://graph.windows.net"
	$aadTokenProvider = new_aad_token_provider $aadResource "common" 
	$authenticationPatcher = new_aad_file_cache_token_provider $cacheIdentifier $adTenantId $aadResource $aadTokenProvider $fileTokenCachePath
	$requestHandler = new_request_handler (new_request_builder) (new_retry_handler $write_response)

	$baseOptionsPatcher = new_simple_options_patcher `
		$defaultRetryCount `
		$defaultScheme `
		$defaultContentType `
		$defaultTimeout

	$optionsPatcher = new_resource_manager_options_patcher `
		$authenticationPatcher `
		$baseOptionsPatcher `
		"graph.windows.net/$adTenantid"

	$obj = new_rest_client $requestHandler $optionsPatcher $authenticationPatcher
	$obj
}
