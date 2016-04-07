function new_retry_handler { param($exceptionResponseHandler, $announcer)
	$obj	= New-Object PSObject -Property @{ ExceptionResponseHandler = $exceptionResponseHandler; Announcer = $announcer }
	$obj | Add-Member -Type ScriptMethod _getWebException { param($exception)
		$result = $exception
		$statusName = $null
		while($statusName -ne "WebExceptionStatus") {
			if($null -ne $result.Status) {
				$statusName = $result.Status.Name
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
	$obj | Add-Member -Type ScriptMethod _writeResponse { param($e)
		if($null -ne $e.Response) {
			& $this.ExceptionResponseHandler $e.Response $this.Announcer
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
				$this.Announcer.Verbose("Exception caught in rest request")
				$e = $this._getWebException($_.Exception)
				$this._writeResponse($e)
				if($e.Status -eq [Net.WebExceptionStatus]::Timeout) {
					if(!($numberOfRetries -lt $retryCount)) {
						throw $e
					}
					$numberOfRetries++
					$this.Announcer.Info("Retrying request due to timeout. Attempt $($numberOfRetries) of $($retryCount)")
				}
				else	{ 
					throw $e
				}
			}
		}
	}
	$obj
}
