param(
	$restLibDir = (Resolve-Path .\).Path,
	$adalLibDir = (Resolve-Path ..\libs).Path,
	$utilsDir = (Resolve-Path ..\utils).Path
)

$ErrorActionPreference = "stop"

. "$($restLibDir)\request_builder.ps1"
. "$($restLibDir)\retry_handler.ps1"
. "$($restLibDir)\request_handler.ps1"
. "$($restLibDir)\response_handlers.ps1"
. "$($restLibDir)\resource_manager_options_patcher.ps1"
. "$($restLibDir)\aad_token_provider.ps1" $adalLibDir
. "$($restLibDir)\aad_file_cache_token_provider.ps1"
. "$($restLibDir)\rest_client.ps1"
. "$($restLibDir)\simple_options_patcher.ps1"
. "$($restLibDir)\config.ps1"
. "$($utilsDir)\announcer.ps1"

function new_resource_manager_rest_client {
	param(
		[ValidateNotNullOrEmpty()]$subscriptionId=$(throw "subscriptionId is mandatory"),
		[ValidateNotNullOrEmpty()]$adTenantId = $(throw "adTenantId is mandatory"),
		$loginHint,
		$cacheIdentifier,
		$defaultVersion = $(__.azure.rest.get_config "management_version"),
		$defaultScheme = $(__.azure.rest.get_config "scheme"),
		$defaultRetryCount = $(__.azure.rest.get_config "retry_count"),
		$defaultContentType = $(__.azure.rest.get_config "management_content_type"),
		$defaultTimeout = $(__.azure.rest.get_config "timeout"),
		$fileTokenCachePath = "$($env:userprofile)\aad_tokens.dat",
		$announcer = (new_announcer)
	)

	if($null -eq $cacheIdentifier) {
		$cacheIdentifier = "$subscriptionId`_resource_management"
	}

	$aadResource = "https://management.core.windows.net/"
	if($null -eq $loginHint) {
		$aadTokenProvider = new_aad_token_provider $aadResource $adTenantId
	} else {
		$aadTokenProvider = new_aad_token_provider_with_login $aadResource $adTenantId -LoginHint $loginHint
	}
	$authenticationPatcher = new_aad_file_cache_token_provider $cacheIdentifier $adTenantId $aadResource $aadTokenProvider $fileTokenCachePath -Announcer $announcer
	$requestHandler = new_request_handler (new_request_builder $announcer) (new_retry_handler $write_response $announcer) $announcer

	$baseOptionsPatcher = new_simple_options_patcher `
		$defaultRetryCount `
		$defaultScheme `
		$defaultContentType `
		$defaultTimeout

	$optionsPatcher = new_resource_manager_options_patcher `
		$authenticationPatcher `
		$baseOptionsPatcher `
		"management.azure.com/subscriptions/$subscriptionId"

	$obj = new_rest_client $requestHandler $optionsPatcher $authenticationPatcher
	$obj
}
