param($restLibDir = (Resolve-Path .\).Path)
$ErrorActionPreference = "stop"

. "$restLibDir\request_builder.ps1"
. "$restLibDir\retry_handler.ps1"
. "$restLibDir\request_handler.ps1"
. "$restLibDir\response_handlers.ps1"
. "$restLibDir\resource_manager_options_patcher.ps1"
. "$restLibDir\rest_client.ps1"
. "$restLibDir\simple_options_patcher.ps1"
. "$restLibDir\config.ps1"
. "$restLibDir\acs_wrap_token_patcher.ps1"
. "$restLibDir\acs_rest_client.ps1" $restLibDir

function new_service_bus_rest_client {
	param(
		[ValidateNotNullOrEmpty()]$namespace = $(throw "namespace is mandatory"),
		[ValidateNotNullOrEmpty()]$identityName = $(throw "identityName is mandatory"),
		[ValidateNotNullOrEmpty()]$key = $("key is mandatory"),
		$defaultScheme = $(__.azure.rest.get_config "scheme"),
		$defaultRetryCount = $(__.azure.rest.get_config "retry_count"),
		$defaultTimeout = $(__.azure.rest.get_config "timeout"),
		$defaultContentType = $(__.azure.rest.get_config "acs_content_type")
	)

	$requestHandler = new_request_handler (new_request_builder) (new_retry_handler $write_response)

	$baseOptionsPatcher = new_simple_options_patcher `
		$defaultRetryCount `
		$defaultScheme `
		$defaultContentType `
		$defaultTimeout

	$acsRestClient = new_acs_rest_client $namespace $key
	
	$authorizationPatcher = new_acs_wrap_token_patcher $namespace $identityName $key $acsRestClient

	$optionsPatcher = new_resource_manager_options_patcher `
		$authorizationPatcher `
		$baseOptionsPatcher `
		"$($namespace).servicebus.windows.net"

	$obj = new_rest_client $requestHandler $optionsPatcher
	$obj
}
