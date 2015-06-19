function new_retry_handler { param($exceptionResponseHandler)
	$obj	= New-Object PSObject -Property @{ ExceptionResponseHandler = $exceptionResponseHandler }
	$obj | Add-Member -Type ScriptMethod _getWebException { param($exception)
		$result = $exception
		$statusName = $null
		while($statusName -ne "WebExceptionStatus") {
			if($null -ne $result.Status) {
				$statusName = $result.Status.GetType().Name
				Write-Verbose "Excpetion status: $($statusName)"
				break
			}
			if($null -eq $result.InnerException) { 
				Write-Warning "No web exception was found"
				break
			}
			$result = $result.InnerException
		}
		$result
	}
	$obj | Add-Member -Type ScriptMethod _writeResponse { param($e)
		if($null -ne $e.Response) {
			& $this.ExceptionResponseHandler $e.Response
		}
	}
	$obj | Add-Member -Type ScriptMethod execute { param ($retryCount, $retryAction)
		$result = $null
		$numberOfRetries = 0
		$running = $true

		while($running) { 
			try {
				& $retryAction
				$running = $false	
			} catch {
				Write-Verbose "Exception caught in rest request"
				$e = $this._getWebException($_.Exception)
				$this._writeResponse($e)
				if($e.Status -eq [Net.WebExceptionStatus]::Timeout) {
					if(!($numberOfRetries -lt $retryCount)) {
						throw $e
					}
					$numberOfRetries++
					Write-Host "Retrying request due to timeout. Attempt $numberOfRetries of $retryCount"
				}
				else	{ 
					throw $e
				}
			}
		}
	}
	$obj
}
