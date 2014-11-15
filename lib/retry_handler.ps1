function new_retry_handler { param($exceptionResponseHandler)
	$obj	= New-Object PSObject -Property @{ ExceptionResponseHandler = $exceptionResponseHandler }
	$obj | Add-Member -Type ScriptMethod execute { param ($retryCount, $retryAction)
		$result = $null
		$numberOfRetries = 0
		$running = $true

		while($running) { 
			try {
				& $retryAction
				$running = $false	
			} catch {
				$e = $_.Exception
				while($e.Response -eq $null) {
					if($null -eq $e.InnerException) { break }
					$e = $e.InnerException
				}
				if($e.Status -eq [Net.WebExceptionStatus]::Timeout) {
					if($null -ne $e.Response) {
						& $this.ExceptionResponseHandler $e.Response
					}
					if(!($numberOfRetries -lt $retryCount)) {
						throw $e
					}
					$numberOfRetries++
					Write-Host "Retrying request due to timeout. Attempt $numberOfRetries of $retryCount"
				}
				else	{ 
					if($null -ne $e.Response) {
						& $this.ExceptionResponseHandler $e.Response
					}
					throw $e
				}
			}
		}
	}
	$obj
}
