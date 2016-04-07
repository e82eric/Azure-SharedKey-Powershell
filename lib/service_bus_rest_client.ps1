param(
	$restLibDir = (Resolve-Path .\).Path,
	$utilsDir = (Resolve-Path ..\utils).Path
)
$ErrorActionPreference = "stop"

. "$($restLibDir)\request_builder.ps1"
. "$($restLibDir)\retry_handler.ps1"
. "$($restLibDir)\request_handler.ps1"
. "$($restLibDir)\response_handlers.ps1"
. "$($restLibDir)\resource_manager_options_patcher.ps1"
. "$($restLibDir)\rest_client.ps1"
. "$($restLibDir)\simple_options_patcher.ps1"
. "$($restLibDir)\config.ps1"
. "$($restLibDir)\acs_wrap_token_patcher.ps1"
. "$($restLibDir)\acs_rest_client.ps1" $restLibDir $utilsDir
. "$($restLibDir)\service_bus_shared_access_signature_header_patcher.ps1"
. "$($restLibDir)\service_bus_shared_access_signature_provider.ps1" $restLibDir
. "$($utilsDir)\announcer.ps1"

function new_service_bus_rest_client {
	param(
		[ValidateNotNullOrEmpty()]$namespace = $(throw "namespace is mandatory"),
		[ValidateNotNullOrEmpty()]$identityName = $(throw "identityName is mandatory"),
		[ValidateNotNullOrEmpty()]$key = $("key is mandatory"),
		$defaultScheme = $(__.azure.rest.get_config "scheme"),
		$defaultRetryCount = $(__.azure.rest.get_config "retry_count"),
		$defaultTimeout = $(__.azure.rest.get_config "timeout"),
		$defaultContentType = $(__.azure.rest.get_config "acs_content_type"),
		$announcer = (new_announcer)
	)

	$requestHandler = new_request_handler (new_request_builder $announcer) (new_retry_handler $write_response $announcer) $announcer

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

function new_service_bus_rest_client_with_sas_auth {
	param(
		[ValidateNotNullOrEmpty()]$namespace = $(throw "namespace is mandatory"),
		[ValidateNotNullOrEmpty()]$key = $("key is mandatory"),
		[ValidateNotNullOrEmpty()]$keyName = $("key name is mandatory"),
		$defaultScheme = $(__.azure.rest.get_config "scheme"),
		$defaultRetryCount = $(__.azure.rest.get_config "retry_count"),
		$defaultTimeout = $(__.azure.rest.get_config "timeout"),
		$defaultContentType = $(__.azure.rest.get_config "acs_content_type"),
		$announcer = (new_announcer)
	)

	$requestHandler = new_request_handler (new_request_builder $announcer) (new_retry_handler $write_response $announcer) $announcer

	$baseOptionsPatcher = new_simple_options_patcher `
		$defaultRetryCount `
		$defaultScheme `
		$defaultContentType `
		$defaultTimeout

	$sasProvider = new_service_bus_shared_access_signature_provider $namespace $key $keyName $announcer
	
	$authorizationPatcher = new_service_bus_shared_access_signature_header_patcher $sasProvider $announcer

	$optionsPatcher = new_resource_manager_options_patcher `
		$authorizationPatcher `
		$baseOptionsPatcher `
		"$($namespace).servicebus.windows.net"

	$obj = new_rest_client $requestHandler $optionsPatcher
	$obj
}
