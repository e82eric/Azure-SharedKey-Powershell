$ErrorActionPreference = "stop"

function new_request_handler { param($requestBuilder, $retryHandler)
	$obj = New-Object PSObject -Property @{ 
		RequestBuilder = $requestBuilder;
		RetryHandler = $retryHandler;
	}
	$obj | Add-Member -Type ScriptMethod execute { param ($params)
		$state = @{ Result = $null }
		$options = $params.Options
		$requestBuilder = $this.RequestBuilder

		$this.RetryHandler.execute($params.Options.RetryCount, {
			$request = $requestBuilder.execute($params)
			$response = $request.GetResponse()
			if($null -ne $options.ProcessResponse) {
				$state.Result = & $options.ProcessResponse $response
			}
		})
		$state.Result
	}
	$obj
}
