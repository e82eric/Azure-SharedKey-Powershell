param(
	$libDir = (Resolve-Path .\).Path,
	$utilsDir = (Resolve-Path ..\utils).Path
)
$ErrorActionPreference = "stop"

. "$($libDir)\config.ps1"
. "$($libDir)\uri_parser.ps1"
. "$($libDir)\ms_headers_parser.ps1"
. "$($libDir)\table_canonicalized_resources_parser.ps1"
. "$($libDir)\table_signature_parser.ps1"
. "$($libDir)\signature_hash_parser.ps1"
. "$($libDir)\request_builder.ps1"
. "$($libDir)\request_handler.ps1"
. "$($libDir)\options_patcher.ps1"
. "$($libDir)\simple_options_patcher.ps1"
. "$($libDir)\resource_manager_options_patcher.ps1"
. "$($libDir)\response_handlers.ps1"
. "$($libDir)\authorization_header_parser.ps1"
. "$($libDir)\rest_client.ps1"
. "$($libDir)\retry_handler.ps1"
. "$($libDir)\table_authorization_header_patcher.ps1"
. "$($libDir)\canonicalized_headers_parser.ps1"
. "$($utilsDir)\announcer.ps1"

function new_table_storage_client {
	param(
		$storageName=$(throw "storageName is mandatory"),
		$storageKey=$(throw "storageKey is mandatory"),
		$defaultVersion = $(__.azure.rest.get_config "storage_version"),
		$defaultScheme = $(__.azure.rest.get_config "scheme"),
		$defaultRetryCount = $(__.azure.rest.get_config "retry_count"),
		$defaultContentType = "application/xml",
		$defaultTimeout = $(__.azure.rest.get_config "timeout"),
		$announcer = (new_announcer)
	)
	$clientType = "table"

	$authorizationHeaderPatcher = new_table_authorization_header_patcher `
		(new_uri_parser $clientType) `
		(new_table_canonicalized_resources_parser $storageName) `
		(new_canonicalized_headers_parser) `
		(new_table_signature_parser) `
		(new_signature_hash_parser $storageKey $announcer) `
		(new_authorization_header_parser $storageName)

	$requestHandler = new_request_handler (new_request_builder $announcer) (new_retry_handler $write_response $announcer) $announcer

	$baseOptionsPatcher = new_simple_options_patcher `
		$defaultRetryCount `
		$defaultScheme `
		$defaultContentType `
		$defaultTimeout

	$resourceManagerOptionsPatcher = new_resource_manager_options_patcher `
		$authorizationHeaderPatcher `
		$baseOptionsPatcher `
		"$($storageName).$($clientType).core.windows.net"

	$optionsPatcher = new_options_patcher `
		$resourceManagerOptionsPatcher `
		$defaultVersion `
		(new_ms_headers_parser)

	new_rest_client $requestHandler $optionsPatcher $authorizationHeaderPatcher
}
