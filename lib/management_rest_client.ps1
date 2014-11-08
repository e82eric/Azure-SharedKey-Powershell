param($restLibDir = (Resolve-Path .\).Path)
$ErrorActionPreference = "stop"

. "$restLibDir\request_builder.ps1"
. "$restLibDir\retry_handler.ps1"
. "$restLibDir\request_handler.ps1"
. "$restLibDir\response_handlers.ps1"
. "$restLibDir\management_options_patcher.ps1"
. "$restLibDir\client_certificate_patcher.ps1"
. "$restLibDir\rest_client.ps1"
. "$restLibDir\simple_options_patcher.ps1"
. "$restLibDir\config.ps1"

function new_subscription_management_rest_client_with_cert_auth { 
	param(
		[ValidateNotNullOrEmpty()]$subscriptionId=$(throw "subscriptionId is mandatory"),
		[ValidateNotNullOrEmpty()]$cert=$(throw "cert is mandatory")
	)	
	$authenticationHandler = new_client_certificate_patcher $cert
	new_subscription_management_rest_client $subscriptionId $authenticationHandler	
}

function new_management_rest_client {
	param(
		[ValidateNotNullOrEmpty()]$authenticationHandler=$(throw "authenticationHandler is mandatory")
	)	
	$urlPatcher = new_management_url_patcher
	_new_management_rest_client $urlPatcher $authenticationHandler
}

function new_subscription_management_rest_client {
	param(
		[ValidateNotNullOrEmpty()]$subscriptionId=$(throw "subscriptionId is mandatory"),
		[ValidateNotNullOrEmpty()]$authenticationHandler=$(throw "authenticationHandler is mandatory")
	)	
	$urlPatcher = new_subscription_management_url_patcher $subscriptionId
	_new_management_rest_client $urlPatcher $authenticationHandler
}

function _new_management_rest_client {
	param(
		$urlPatcher=$(throw "urlPatcher is mandatory"),
		$authenticationHandler=$(throw "authenticationHandler is mandatory"),
		$defaultVersion = $(__.azure.rest.get_config "management_version"),
		$defaultScheme = $(__.azure.rest.get_config "scheme"),
		$defaultRetryCount = $(__.azure.rest.get_config "retry_count"),
		$defaultContentType = $(__.azure.rest.get_config "management_content_type"),
		$defaultTimeout = $(__.azure.rest.get_config "timeout")
	)

	$requestHandler = new_request_handler (new_request_builder) (new_retry_handler $write_response)

	$baseOptionsPatcher = new_simple_options_patcher `
		$defaultRetryCount `
		$defaultScheme `
		$defaultContentType `
		$defaultTimeout

	$optionsPatcher = new_management_options_patcher `
		$urlPatcher `
		$defaultVersion `
		$authenticationHandler `
		$baseOptionsPatcher

	$obj = new_rest_client $requestHandler $optionsPatcher $authenticationHandler
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
			Write-Host $status
			if($operationResult.Body -ne $null) {
				Write-Host $operationResult.Body
			}
			if($status -ne "InProgress") {
				break
			}
			Start-Sleep -s 3
		}
		if($status -ne "Succeeded") {
			$error = $operationResult.OperationResult.Error
			throw "Status: $status Code: $($error.Code) Message: $($error.Message)"
		}
		$operationResult
	}
	$obj
}
								
$parse_operation_xml = { param ($response)
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
	$operationId = $response.Headers.Get("x-ms-request-id")
	$stream = $response.GetResponseStream()
	$reader = New-Object IO.StreamReader($stream)
	$result = $reader.ReadToEnd()
	$stream.Close()
	$reader.Close()
	$body = $result
	@{ Body = $body; OperationId = $operationId }
}
