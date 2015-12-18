param(
	$workingDirectory = (Resolve-Path .\).Path,
	$restLibDir = (Resolve-Path "$($workingDirectory)\..\lib").Path,
	$adalLibDir = (Resolve-Path "$($workingDirectory)\..\libs").Path
)

. "$($restLibDir)\resource_manager_rest_client.ps1" $restLibDir $adalLibDir
. "$($restLibDir)\blob_storage_client.ps1" $restLibDir
. "$($restLibDir)\shared_access_signature_provider.ps1" $restLibDir
. "$($workingDirectory)\azure_resource_management_base.ps1"
. "$($workingDirectory)\azure_resource_group_management.ps1"
. "$($workingDirectory)\azure_resource_management.ps1"

$ErrorActionPreference = "stop"

function new_azure_vm (
	[ValidateNotNullOrEmpty()] $resourceGroup = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $dataCenter = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $template = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $templateParameters = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $name = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $publicIpName = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $workingDirectory = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $installersDirectory = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $isoDrive = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $installersStorageAccount = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $installersStorageKey = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $installersContainer = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $subscriptionId = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $subscriptionAdTenantId = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $loginHint = $(throw "empty parameter")
) {
	Write-Host "INFO: new_zure_vm"
	Write-Host "INFO: --resourceGroup $($resourceGroup)"
	Write-Host "INFO: --dataCenter $($dataCenter)"
	Write-Host "INFO: --name $($name)"
	Write-Host "INFO: --publicIpName $($publicIpName)"
	Write-Host "INFO: --workingDirectory $($workingDirectory)"
	Write-Host "INFO: --installersDirectory $($installersDirectory)"
	Write-Host "INFO: --isoDrive $($isoDrive)"
	Write-Host "INFO: --installersStorageAccount $($installersStorageAccount)"
	Write-Host "INFO: --installersStorageKey $($installersStorageKey)"
	Write-Host "INFO: --installersContainer $($installersContainer)"
	Write-Host "INFO: --subscriptionId $($subscriptionId)"
	Write-Host "INFO: --subscriptionAdTenantId $($subscriptionAdTenantId)"
	Write-Host "INFO: --loginHint $($loginHint)"

	$resourceManagerRestClient = new_resource_manager_rest_client $subscriptionId $subscriptionAadTenantId $loginHint
	$azureResourceGroupManagement = new_azure_resource_group_management $resourceManagerRestClient
	$azureResourceManagement = new_azure_resource_management $resourceManagerRestClient $azureResourceGroupManagement

	$obj = new_vm_base $name $installersDirectory $isoDrive
	$obj | Add-Member -Type NoteProperty ResourceGroup $resourceGroup
	$obj | Add-Member -Type NoteProperty DataCenter $dataCenter
	$obj | Add-Member -Type NoteProperty Template $template
	$obj | Add-Member -Type NoteProperty TemplateParameters $templateParameters
	$obj | Add-Member -Type NoteProperty InstallersStorageAccount $installersStorageAccount
	$obj | Add-Member -Type NoteProperty InstallersStorageAccountKey $installersStorageKey
	$obj | Add-Member -Type NoteProperty InstallersContainer $installersContainer
	$obj | Add-Member -Type NoteProperty RestClient $resourceManagerRestClient
	$obj | Add-Member -Type NoteProperty AzureResourceGroupManagement $azureResourceGroupManagement
	$obj | Add-Member -Type NoteProperty AzureResourceManagement $azureResourceManagement
	$obj | Add-Member -Type NoteProperty PublicIpName $publicIpName

	$obj | Add-Member -Type ScriptMethod  _validateInstallers {
		Write-Host "INFO: ValidateInstallers"
		$blobClient = new_blob_storage_client $this.InstallersStorageAccount $this.InstallersStorageAccountKey

		$blobsXml = $blobClient.Request(@{ Verb = "GET"; Resource = "$($this.InstallersContainer)`?restype=container&comp=list"; ProcessResponse = $parse_xml })
		$blobs = $blobsXml.EnumerationResults.Blobs.Blob

		$this.Installers.GetEnumerator() | % {
			$installer = $_.Value 
			$blob = $blobs | ? { $_.Name -eq $installer }

			if($null -eq $blob) {
				throw "could not find $($installer)" 
			} else {
				Write-Host "INFO: --Found installer: $($installer)"
			}
		}
		Write-Host "INFO: --Done"
	}
	$obj | Add-Member -Type ScriptMethod _createVM {
		Write-Host "INFO: CreateVm"
		Write-Host "INFO: --CreateResourceGroup"
		$this.AzureResourceGroupManagement.CreateResourceGroup($this.ResourceGroup, $this.DataCenter) | Out-Null
		Write-Host "INFO: --DeployTemplate"
		$this.AzureResourceManagement.DeployTemplate($this.ResourceGroup, $this.DataCenter, $this.Template, $this.TemplateParameters) | Out-Null
	}
	$obj | Add-Member -Type ScriptMethod _waitForBoot {
		Write-Host "INFO: Wait for boot"
		Write-Host "INFO: --Azure ARM template engine handles this now"
	}
	$obj | Add-Member -Type ScriptMethod _setWinRmUri {
		Write-Host "INFO: SetWinRmUri"
		$ipDef = $this.RestClient.Request(@{
			Verb = "GET";
			Resource = "resourceGroups/$($this.ResourceGroup)/providers/Microsoft.Network/publicIPAddresses/$($this.PublicIpName)?api-Version=2015-06-15";
			OnResponse = $parse_json;
		})
		$ipAddress = $ipDef.properties.ipAddress
		Write-Host "INFO: --ipAddress: $($ipAddress)"
		$this.WinRmUri = "http://$($ipAddress):5985"
		Write-Host "INFO: --uri: $($this.WinRmUri)"
	}
	$obj | Add-Member -Type ScriptMethod CreatePSSession { param($authentication)
		Write-Host "INFO: CreatePSSession"
		Write-Host "INFO: --Authentication: $($authentication)"
		Write-Host "INFO: --Connection Uri: $($this.WinRmUri)" 
		New-PSSession -ConnectionUri $this.WinRmUri -Credential $this.AdminUser.Credential -Authentication $authentication -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck)
	}
	$obj | Add-Member -Type ScriptMethod _waitForWinRm -Value {
		$numberOfTries = 0

		$session = $null
		$sessionCreated = $false

		while(!$sessionCreated) {
			try {
				Write-Host "INFO: Waiting for boot CredSSP attempt. $($numberOfTries)"
				if($this.WinRmUri -eq $null) { $this._setWinRmUri() }
				$session = New-PsSession -ConnectionUri $this.WinRmUri -Credential $this.AdminUser.Credential -Authentication Negotiate -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck)
				$sessionCreated = $true
			} catch {
				if($numberOfTries -lt 40) { 
					Write-Host $_
					$numberOfTries++
					Start-Sleep -s 10
				} else {
					throw $_
				}
			} finally {
				if($null -ne $session) {
					Remove-PsSession $session
				}
			}

		}
	}
	$obj | Add-Member -Type ScriptMethod _downloadInstallers -Value {
		Write-Host "INFO: DownloadInstallers"
		$sasProvider = new_shared_access_signature_provider $this.InstallersStorageAccount $this.InstallersStorageAccountKey

		$this.RemoteSession({ param($session)
			$session.Execute({ param($context)
				if(!(Test-Path $context.InstallersDirectory)) {
					New-Item $context.InstallersDirectory -Type Directory
				}
			})
			$this.Installers.GetEnumerator() | % {
				$url = $sasProvider.GetUrl("$($this.InstallersContainer)/$($_.Value)", "b", "r", [DateTime]::UtcNow.AddMinutes(1))
				$session.Execute({ param($context, $installerName, $installerSasUrl)
					$filePath = "$($context.InstallersDirectory)\$installerName"	
					Write-Host "INFO: --Trying to download installer. installerName: $($installerName), installerSasUrl: $($installerSasUrl), filePath: $($filePath)"
					$webRequest = [Net.WebRequest]::Create($installerSasUrl)
					$webRequest.Method = "GET"
					$response = $webRequest.GetResponse()
					$stream = $response.GetResponseStream()
					$file = [System.IO.File]::Create($filePath)
					$buffer = New-Object Byte[] 1024

					Do {
						$bytesRead = $stream.Read($buffer, 0, $buffer.Length)
						$file.Write($Buffer, 0, $BytesRead)
					} While ($bytesRead -gt 0)

					$stream.Close()

					$file.Flush()
					$file.Close()
					$file.Dispose()
				},
				@($_.Value, $url))
			}
		})
	}
	$obj
}
