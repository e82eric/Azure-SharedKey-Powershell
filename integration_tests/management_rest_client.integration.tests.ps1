param($restLibDir = (Resolve-Path "..\lib").Path)
$ErrorActionPreference = "stop"

. "$restLibDir\management_rest_client.ps1" $restLibDir
. "$restLibDir\adal_authentication_patcher.ps1"

$script:restClient = new_management_rest_client_with_adal
$restClient.Request(@{ Verb = "GET"; Url = "https://management.core.windows.net/Subscriptions"; OnResponse = $parse_xml;})
