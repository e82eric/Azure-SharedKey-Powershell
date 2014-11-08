#.\create_azure_network.ps1 `
#	-thumbprint $thumbprint `
#	-subscriptionId $subscriptionId `
#	-networkName "testnet" `
#	-affinityGroup "testuswest" `
#	-networkAddressSpace "192.168.0.0/24" `
#	-subnetAddressPrefix "192.168.0.0/27" `
#	-gatewaySubnetAddressPrefix "192.168.0.32/27" `
#	-vpnAddressPrefix "172.16.1.0/29" `
#	-clientCertificatePassword "pass@word1"

param(
	$subscriptionId,
	$subscriptionAdTenantId,
	$networkName,
	$affinityGroup,
	$affinityGroupDataCenter,
	$networkAddressSpace,
	$subnetAddressPrefix,
	$gatewaySubnetAddressPrefix,
	$vpnAddressPrefix,
	$clientCertificatePassword,
	$restLibDir = (Resolve-Path "..\lib").Path,
	$toolsDir = (Resolve-Path "..\tools").Path,
	$outDir = "..\vpn")

$ErrorActionPreference = "Stop"

function _get_resource_if_exists { param($restClient, $existsRequestOptions)
	$result = $null
	try {
		$result = $restCLient.Request($existsRequestOptions)
	} catch {
		$e = $_.Exception
		while($e.Response -eq $null) {
			if($null -eq $e.InnerException) { break }
			$e = $e.InnerException
		}
		if($e.Response.StatusCode -eq "NotFound") {
			#this means the resource does not exists and we will let the method continue and return null
		} else {
			throw $_
		}
	}
	$result
}

function _try_get_resource { param($restClient, $existsRequestOptions, $onNotExists)
	$result = _get_resource_if_exists $restClient $existsRequestOptions
	if ($null -eq $result -and $null -ne $onNotExists) {
		$result = & $onNotExists
	}
	$result
}

. "$restLibDir\management_rest_client.ps1" $restLibDir
. "$restLibDir\adal_authentication_patcher.ps1"

$cert = Get-Item Cert:\CurrentUser\My\$thumbprint
$restClient = new_management_rest_client $subscriptionId (new_adal_authentication_patcher $subscriptionAdTenantId)

$affinityGroupDef = "<?xml version=`"1.0`" encoding=`"utf-8`"?>
<CreateAffinityGroup xmlns=`"http://schemas.microsoft.com/windowsazure`">
	<Name>$affinityGroup</Name>
	<Label>$([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($affinityGroup)))</Label>
	<Description>$affinityGroup</Description>
	<Location>$affinityGroupDataCenter</Location>
</CreateAffinityGroup>"

_try_get_resource `
	$restClient `
	@{ Verb = "GET"; Resource = "affinityGroups/$affinityGroup"; OnResponse = $parse_xml } `
	{ $restClient.ExecuteOperation("POST", "affinityGroups", $affinityGroupDef) } | Out-Null

$networkDef = _try_get_resource `
	$restClient `
	@{ Verb = "GET"; Resource = "services/networking/media"; OnResponse = $parse_xml } `
	{
		[xml]'<?xml version="1.0" encoding="utf-8"?>
		<NetworkConfiguration xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration" >
			<VirtualNetworkConfiguration>
				<VirtualNetworkSites>
				</VirtualNetworkSites>
			</VirtualNetworkConfiguration>
		</NetworkConfiguration>'
	}

$newNetworkDef = `
'<?xml version="1.0" encoding="utf-8"?>
<NetworkConfiguration xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration" >
	<VirtualNetworkConfiguration>
		<VirtualNetworkSites>
			<VirtualNetworkSite name="{0}" AffinityGroup="{1}">
				<AddressSpace>
					<AddressPrefix>{2}</AddressPrefix>
				</AddressSpace>
				<Subnets>
					<Subnet name="Subnet-1">
						<AddressPrefix>{3}</AddressPrefix>
					</Subnet>
					<Subnet name="GatewaySubnet">
						<AddressPrefix>{4}</AddressPrefix>
					</Subnet>
				</Subnets>
				<Gateway>
					<VPNClientAddressPool>
						<AddressPrefix>{5}</AddressPrefix>
					</VPNClientAddressPool>
					<ConnectionsToLocalNetwork />
				</Gateway>
			</VirtualNetworkSite>
		</VirtualNetworkSites>
	</VirtualNetworkConfiguration>
</NetworkConfiguration>' -f $networkName,$affinityGroup,$networkAddressSpace,$subnetAddressPrefix,$gatewaySubnetAddressPrefix,$vpnAddressPrefix

$newNetworkDoc = New-Object Xml.XmlDocument
$newNetworkDoc.LoadXml($newNetworkDef)
$newNetworkNode = $networkDef.ImportNode($newNetworkDoc.NetworkConfiguration.VirtualNetworkConfiguration.VirtualNetworkSites.FirstChild, $true)

$networkDef.NetworkConfiguration.VirtualNetworkConfiguration.Item("VirtualNetworkSites").AppendChild($newNetworkNode)
$restClient.ExecuteOperation2(@{ Verb = "PUT"; Resource = "services/networking/media"; Content = $networkDef.OuterXml; ContentType = "text/plain" })

$gatewayDef = `
'<CreateGatewayParameters xmlns="http://schemas.microsoft.com/windowsazure">
  <gatewayType>DynamicRouting</gatewayType>
</CreateGatewayParameters>'

$restClient.ExecuteOperation("POST", "services/networking/$networkName/gateway", $gatewayDef)

while($true) {
	$result = $restClient.Request(@{ Verb = "GET"; Resource = "services/networking/$networkName/gateway"; OnResponse = $parse_xml })
	$state = $result.Gateway.State
	Write-Host $state
	if($state -eq "Provisioned") {
		break
	}
	Start-Sleep -s 1
}

$rootCertName = "$($networkName)_root"
$clientCertName = "$($networkName)_client1"

if(!(Test-Path $outDir)) { New-Item $outDir -Type Directory -Force }
& "$toolsDir\makecert.exe" -sky exchange -r -n "CN=$rootCertName" -pe -a sha1 -len 2048 -b "07/30/2014" -ss My "$outDir\$($rootCertName).cer"
if($lastExitCode -ne 0) { throw $lastExitCode }
& "$toolsDIr\makecert.exe" -n "CN=$clientCertName" -pe -sky exchange -m 96 -ss My -in "$rootCertName" -is my -a sha1
if($lastExitCode -ne 0) { throw $lastExitCode }

$clientCert = Get-ChildItem Cert:\CurrentUser\My | ? { $_.Subject -eq "CN=$clientCertName" }
$bytes = $clientCert.export([Security.Cryptography.X509Certificates.X509ContentType]::pfx, $clientCertificatePassword)
[IO.File]::WriteAllBytes("$outDir\$($clientCertName)_client1.pfx", $bytes)

$rootCertDef = "<Binary>-----BEGIN CERTIFICATE-----`n$([convert]::ToBase64String([IO.File]::ReadAllBytes("$outDir\$($rootCertName).cer")))`n-----END CERTIFICATE-----</Binary>"
$restClient.ExecuteOperation2(@{ 
	Verb = "POST"; 
	Resource = "services/networking/$networkName/gateway/clientrootcertificates"; 
	Content = $rootCertDef; 
	ContentType = "application/x-www-form-urlencoded" 
})

$vpnDef = `
"<VpnClientParameters xmlns=`"http://schemas.microsoft.com/windowsazure`">
  <ProcessorArchitecture>Amd64</ProcessorArchitecture>
</VpnClientParameters>"
$vpnClientResult = $restClient.ExecuteOperation("POST", "services/networking/$networkName/gateway/vpnclientpackage", $vpnDef)

$url = $null
$status = $null
while($true) {
	$gatewayOperation = $restClient.Request(@{ Verb = "GET"; Resource = "services/networking/operation/$($vpnClientResult.Operation.ID)"; OnResponse = $parse_xml })
	$status = $gatewayOperation.GatewayOperation.Status
	Write-Host $status
	if($status -ne "InProgress") {
		$url = $gatewayOperation.GatewayOperation.Data
		break
	}
	Start-Sleep -s 1
}

$webclient = New-Object Net.WebClient
$webclient.DownloadFile($url, "$outDir\$($networkName)_vpn.exe")
