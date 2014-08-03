param($restLibDir = (Resolve-Path .\).Path)
$ErrorActionPreference = "stop"

. "$restLibDir\request_builder.ps1"
. "$restLibDir\retry_handler.ps1"
. "$restLibDir\request_handler.ps1"
. "$restLibDir\response_handlers.ps1"

function new_azure_rest_client ($subscriptionId, $authHandler) {
  $requestBuilder = new_request_builder
  $retryHandler = new_retry_handler $write_response
  $requestHandler = new_request_handler $requestBuilder $retryHandler

	$obj = New-Object PSObject -Property @{ AuthHandler = $authHandler; SubscriptionId = $subscriptionId; RequestHandler = $requestHandler }
  $obj | Add-Member -Type ScriptMethod -Name Request -Value { param ($options)
    if($null -eq $options.Url) {
      $options.Url = "https://management.core.windows.net/$($this.subscriptionId)/$($options.Resource)"
    }
    $this.AuthHandler.Handle($options)

		if($null -eq $options.RetryCount) {
			$options.RetryCount = 3
		}

		if($null -ne $options.Timeout){
			$request.Timeout = $options.Timeout
		}

		if($null -eq $options.ContentType) {
			$options.ContentType = "application/xml"
		} 

    if($null -eq $options.Headers) {
      $options.Headers = @()
    }

    if($null -eq $options.ProcessResponse) {
      $options.ProcessResponse = $options.OnResponse
    }

    $options.Headers += @{ name = "x-ms-version"; value = "2013-08-01" }

    $params = @{
      MsHeaders = @();
      Options = $options
    }

    $this.RequestHandler.Execute($params)
  }
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
