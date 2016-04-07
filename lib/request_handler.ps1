$ErrorActionPreference = "stop"

function new_request_handler { param($requestBuilder, $retryHandler, $announcer)
	$obj = New-Object PSObject -Property @{ 
		RequestBuilder = $requestBuilder;
		RetryHandler = $retryHandler;
		Announcer = $announcer;
	}
	$obj | Add-Member -Type ScriptMethod _getWebException { param($exception)
		$result = $exception
		$statusName = $null
		while($statusName -ne "WebExceptionStatus") {
			if($null -ne $result.Status) {
				$statusName = $result.Status.GetType().Name
				$this.Announcer.Verbose("Excpetion Status: $($result.Message), StatusCode: $($result.Response.StatusCode)")
				break
			}
			if($null -eq $result.InnerException) { 
				$this.Announcer.Warning("No web exception was found")
				break
			}
			$result = $result.InnerException
		}
		$result
	}
	$obj | Add-Member -Type ScriptMethod execute { param ($options)
		$state = @{ Result = $null }
		$requestBuilder = $this.RequestBuilder

		$this.RetryHandler.execute($options.RetryCount, {
			$request = $requestBuilder.execute($options)
			$response = $null
			try {
				$response = $request.GetResponse()
				$state.SuccessStatusCode = $true
				$state.StatusCode = $response.StatusCode
			} catch {
				if($true -eq $options.IncludeHttpDetails) {
					$this.Announcer.Verbose("IncludeHttpDetails flag set to true. Not throwing exception.")
					$e = $this._getWebException($_.Exception)
					$state.SuccessStatusCode = $false
					$state.StatusCode = $e.Response.StatusCode
					$response = $e.Response
				} else {
					$this.Announcer.Verbose("IncludeHttpDetails flag set to true. Throwing exception.")
					throw $_.Exception
				}
			}
			if($null -ne $options.ProcessResponse) {
				$state.Result = & $options.ProcessResponse $response $this.Announcer
			}
		})
		if($true -eq $options.IncludeHttpDetails) {
			$this.Announcer.Verbose("IncludeHttpDetails flag set to true returning full details")
			$state
		} else {
			$this.Announcer.Verbose("IncludeHttpDetails flag set to false returning only body")
			$state.Result
		}
	}
	$obj
}
