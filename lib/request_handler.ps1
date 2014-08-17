$ErrorActionPreference = "stop"

function new_request_handler { param($requestBuilder, $retryHandler)
	$obj = New-Object PSObject -Property @{ 
		RequestBuilder = $requestBuilder;
		RetryHandler = $retryHandler;
	}
	$obj | Add-Member -Type ScriptMethod execute { param ($options)
		$state = @{ Result = $null }
		$requestBuilder = $this.RequestBuilder

		$this.RetryHandler.execute($options.RetryCount, {
			$request = $requestBuilder.execute($options)
			$response = $request.GetResponse()
			if($null -ne $options.ProcessResponse) {
				$state.Result = & $options.ProcessResponse $response
			}
		})
		$state.Result
	}
	$obj
}
