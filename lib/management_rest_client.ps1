param(
	$restLibDir = (Resolve-Path .\).Path,
	$adalLibDir = (Resolve-Path ..\libs).Path,
	$utilLibDir = (Resolve-Path ..\util).Path
)
$ErrorActionPreference = "stop"

. "$($restLibDir)\request_builder.ps1"
. "$($restLibDir)\retry_handler.ps1"
. "$($restLibDir)\request_handler.ps1"
. "$($restLibDir)\response_handlers.ps1"
. "$($restLibDir)\resource_manager_options_patcher.ps1"
. "$($restLibDir)\management_options_patcher.ps1"
. "$($restLibDir)\client_certificate_patcher.ps1"
. "$($restLibDir)\rest_client.ps1"
. "$($restLibDir)\simple_options_patcher.ps1"
. "$($restLibDir)\config.ps1"
. "$($restLibDir)\aad_token_provider.ps1" $adalLibDir
. "$($restLibDir)\aad_file_cache_token_provider.ps1"
. "$($utilLibDir)\announcer.ps1"

function new_subscription_management_rest_client_with_adal { 
	param(
		[ValidateNotNullOrEmpty()]$subscriptionId=$(throw "subscriptionId is mandatory"),
		[ValidateNotNullOrEmpty()]$aadTenantId=$(throw "aadTenantId is mandatory"),
		$loginHint,
		$fileTokenCachePath = "$($env:userprofile)\aad_tokens.dat",
		$announcer = (new_announcer)
	)	
	$cacheIdentifier = "$($subscriptionId)`_management_rest_client"
	$aadResource = "https://management.core.windows.net/"
	$aadTokenProvider = $null
	if($null -eq $loginHint) {
		$aadTokenProvider = new_aad_token_provider $aadResource $aadTenantId
	} else {
		$aadTokenProvider = new_aad_token_provider_with_login $aadResource $aadTenantId -LoginHint $loginHint
	}
	$authenticationPatcher = new_aad_file_cache_token_provider $cacheIdentifier $aadTenantId $aadResource $aadTokenProvider $fileTokenCachePath -Announcer $announcer
	new_subscription_management_rest_client $subscriptionId $authenticationPatcher $announcer
}

function new_subscription_management_rest_client_with_cert_auth { 
	param(
		[ValidateNotNullOrEmpty()]$subscriptionId=$(throw "subscriptionId is mandatory"),
		[ValidateNotNullOrEmpty()]$cert=$(throw "cert is mandatory"),
		$announcer
	)	
	$authenticationHandler = new_client_certificate_patcher $cert
	new_subscription_management_rest_client $subscriptionId $authenticationHandler $announcer
}

function new_management_rest_client_with_adal { param(
	$loginHint,
	$fileTokenCachePath = "$($env:userprofile)\aad_tokens.dat",
	$announcer = (new_announcer)
)
	$cacheIdentifier = "$($subscriptionId)`subscriptions_management_rest_client"
	$aadResource = "https://management.core.windows.net/"
	$aadTenantId = "common"

	if($null -eq $loginHint) {
		$aadTokenProvider = new_aad_token_provider $aadResource $aadTenantId
	} else {
		$aadTokenProvider = new_aad_token_provider_with_login $aadResource $aadTenantId -LoginHint $loginHint
	}
	$authenticationPatcher = new_aad_file_cache_token_provider $cacheIdentifier $aadTenantId $aadResource $aadTokenProvider $fileTokenCachePath -Announcer $announcer
	new_management_rest_client $authenticationPatcher $announcer
}

function new_management_rest_client {
	param(
		[ValidateNotNullOrEmpty()]$authenticationHandler=$(throw "authenticationHandler is mandatory"),
		$announcer = (new_announcer)
	)	
	_new_management_rest_client "management.core.windows.net" $authenticationHandler -Announcer $announcer
}

function new_subscription_management_rest_client {
	param(
		[ValidateNotNullOrEmpty()]$subscriptionId=$(throw "subscriptionId is mandatory"),
		[ValidateNotNullOrEmpty()]$authenticationHandler=$(throw "authenticationHandler is mandatory"),
		$announcer = (new_announcer)
	)	
	_new_management_rest_client "management.core.windows.net/$($subscriptionId)" $authenticationHandler -Announcer $announcer
}

function _new_management_rest_client {
	param(
		$beforeResource=$(throw "beforeResource is mandatory"),
		$authenticationHandler=$(throw "authenticationHandler is mandatory"),
		$defaultVersion = $(__.azure.rest.get_config "management_version"),
		$defaultScheme = $(__.azure.rest.get_config "scheme"),
		$defaultRetryCount = $(__.azure.rest.get_config "retry_count"),
		$defaultContentType = $(__.azure.rest.get_config "management_content_type"),
		$defaultTimeout = $(__.azure.rest.get_config "timeout"),
		$announcer = (new_announcer)
	)

	$requestHandler = new_request_handler (new_request_builder $announcer) (new_retry_handler $write_response $announcer) $announcer

	$baseOptionsPatcher = new_simple_options_patcher `
		$defaultRetryCount `
		$defaultScheme `
		$defaultContentType `
		$defaultTimeout
	
	$resourceManagerOptionsPatcher = new_resource_manager_options_patcher `
		$authenticationHandler `
		$baseOptionsPatcher `
		$beforeResource

	$optionsPatcher = new_management_options_patcher `
		$defaultVersion `
		$resourceManagerOptionsPatcher

	$obj = new_rest_client $requestHandler $optionsPatcher $authenticationHandler
	$obj | Add-Member -Type NoteProperty Announcer $announcer
	$obj | Add-Member -Type ScriptMethod ExecuteOperation { param ($verb, $resource, $content)
		$this.ExecuteOperation2(@{ Verb = $verb; Resource = $resource; Content = $content; })
	}
	$obj | Add-Member -Type ScriptMethod ExecuteOperation2 { param ($options)
		$options.Add("OnResponse", $parse_operation_id) | Out-Null
		$serviceResult = $this.Request($options)

		$operationResult = $null	
		$status = $null
		while ($true) {
			$operationResult = $this.Request(@{ Verb = "GET"; Resource = "operations/$($serviceResult.OperationId)"; OnResponse = $parse_xml; RetryCount = 3; })
			$status = $operationResult.Operation.Status
			$this.Announcer.Info("Checking management api operation status. OperationId: $($serviceResult.OperationId), Status: $($status)")
			if($operationResult.Body -ne $null) {
				$this.Announcer.Info("Checking management api operation body. OperationId: $($serviceResult.OperationId), Body: $($operationResult.Body)")
			}
			if($status -ne "InProgress") {
				break
			}
			Start-Sleep -s 3
		}
		if($status -ne "Succeeded") {
			$error = $operationResult.OperationResult.Error
			throw "Error: Management api operation failed. $($operationResult.OuterXml)"
		}
		$operationResult
	}
	$obj
}
								
$parse_operation_xml = { param ($response, $announcer)
	$announcer.Verbose("Process response as operation xml")
	$operationId = $response.Headers.Get("x-ms-request-id")
	$stream = $response.GetResponseStream()
	$reader = New-Object IO.StreamReader($stream)
	$result = $reader.ReadToEnd()
	$stream.Close()
	$reader.Close()
	$body = [xml]$result
	@{ Body = $body; OperationId = $operationId }
}

$parse_operation_id = { param ($response)
	$announcer.Verbose("Process response as operation id")
	$operationId = $response.Headers.Get("x-ms-request-id")
	$stream = $response.GetResponseStream()
	$reader = New-Object IO.StreamReader($stream)
	$result = $reader.ReadToEnd()
	$stream.Close()
	$reader.Close()
	$body = $result
	@{ Body = $body; OperationId = $operationId }
}
