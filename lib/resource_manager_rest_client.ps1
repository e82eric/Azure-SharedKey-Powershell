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
. "$restLibDir\adal_authentication_patcher.ps1" $adalLibDir
. "$restLibDir\rest_client.ps1"
. "$restLibDir\simple_options_patcher.ps1"
. "$restLibDir\config.ps1"

function new_resource_manager_rest_client {
	param(
		[ValidateNotNullOrEmpty()]$subscriptionId=$(throw "subscriptionId is mandatory"),
		[ValidateNotNullOrEmpty()]$adTenantId = $(throw "adTenantId is mandatory"),
		$defaultVersion = $(__.azure.rest.get_config "management_version"),
		$defaultScheme = $(__.azure.rest.get_config "scheme"),
		$defaultRetryCount = $(__.azure.rest.get_config "retry_count"),
		$defaultContentType = $(__.azure.rest.get_config "management_content_type"),
		$defaultTimeout = $(__.azure.rest.get_config "timeout")
	)

	$authenticationPatcher = new_adal_authentication_patcher $adTenantId "https://management.core.windows.net/" $adTenantId
	$requestHandler = new_request_handler (new_request_builder) (new_retry_handler $write_response)

	$baseOptionsPatcher = new_simple_options_patcher `
		$defaultRetryCount `
		$defaultScheme `
		$defaultContentType `
		$defaultTimeout

	$optionsPatcher = new_resource_manager_options_patcher `
		$authenticationPatcher `
		$baseOptionsPatcher `
		"management.azure.com" `
		"subscriptions/$subscriptionId"


	$obj = new_rest_client $requestHandler $optionsPatcher $authenticationPatcher
	$obj
}
