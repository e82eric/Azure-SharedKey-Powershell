$ErrorActionPreference = "stop"

$libDir = (Resolve-Path .\).Path

. "$libDir\uri_parser.ps1"
. "$libDir\ms_headers_parser.ps1"
. "$libDir\blob_canonicalized_resources_parser.ps1"
. "$libDir\canonicalized_headers_parser.ps1"
. "$libDir\blob_signature_parser.ps1"
. "$libDir\signature_hash_parser.ps1"
. "$libDir\request_builder.ps1"
. "$libDir\request_handler.ps1"
. "$libDir\options_patcher.ps1"
. "$libDir\response_handlers.ps1"
. "$libDir\authorization_header_parser.ps1"
. "$libDir\rest_client.ps1"
. "$libDir\retry_handler.ps1"
. "$libDir\blob_authorization_header_patcher.ps1"

function new_blob_storage_client {
	param(
		$storageName=$(throw "storageName is mandatory"),
		$storageKey=$(throw "storageKey is mandatory"),
		$defaultVersion = $(__.azure.rest.get_config "storage_version"),
		$defaultScheme = $(__.azure.rest.get_config "scheme"),
		$defaultRetryCount = $(__.azure.rest.get_config "retry_count")
	)
	$clientType = "blob"

	$authorizationHeaderPatcher = new_blob_authorization_header_patcher `
		(new_uri_parser $clientType) `
		(new_blob_canonicalized_resources_parser $storageName) `
		(new_canonicalized_headers_parser) `
		(new_blob_signature_parser) `
		(new_signature_hash_parser $storageKey) `
		(new_authorization_header_parser $storageName)

	$requestHandler = new_request_handler (new_request_builder $storageName) (new_retry_handler $write_response)
	$optionsPatcher = new_options_patcher `
		$storageName `
		$defaultVersion `
		$defaultRetryCount `
		$clientType `
		$defaultScheme `
		(new_ms_headers_parser) `
		$authorizationHeaderPatcher

	new_rest_client $requestHandler $optionsPatcher $authorizationHeaderPatcher
}
