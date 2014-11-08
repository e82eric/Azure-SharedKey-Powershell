param($restLibDir = (Resolve-Path "..\lib").Path)
$ErrorActionPreference = "stop"

. "$restLibDir\management_rest_client.ps1" $restLibDir
. "$restLibDir\adal_authentication_patcher.ps1"

$restClient = new_management_rest_client (new_adal_authentication_patcher "common")
$restClient.Request(@{ Verb = "GET"; Url = "https://management.core.windows.net/Subscriptions"; OnResponse = $parse_xml;})
