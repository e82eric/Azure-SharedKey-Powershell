$libDir = (Resolve-Path .\).Path

. "$libDir\uri_parser.ps1"
. "$libDir\ms_headers_parser.ps1"
. "$libDir\table_canonicalized_resources_parser.ps1"
. "$libDir\table_signature_parser.ps1"
. "$libDir\signature_hash_parser.ps1"
. "$libDir\composite_parser.ps1"
. "$libDir\request_builder.ps1"
. "$libDir\request_handler.ps1"
. "$libDir\options_patcher.ps1"
. "$libDir\response_handlers.ps1"
. "$libDir\authorization_header_parser.ps1"
. "$libDir\storage_client.ps1"

function new_table_storage_client { param($storageName, $storageKey)
	$clientType = "table"

	$parsers = New-Object Collections.ArrayList
	$parsers.Add((new_uri_parser $clientType)) | Out-Null
	$parsers.Add((new_ms_headers_parser)) | Out-Null
	$parsers.Add((new_table_canonicalized_resources_parser)) | Out-Null
	$parsers.Add((new_table_signature_parser)) | Out-Null
	$parsers.Add((new_signature_hash_parser $storageKey)) | Out-Null
	$parsers.Add((new_authorization_header_parser $storageName)) | Out-Null
	new_storage_client $storageName $storageKey $parsers $clientType
}
