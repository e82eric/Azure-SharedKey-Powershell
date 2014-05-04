function new_retry_handler {
	$obj  = New-Object PSObject
	$obj | Add-Member -Type ScriptMethod execute { param ($retryCount, $retryAction)
		$result = $null
		$numberOfRetries = 0
		$running = $true

		while($running) { 
			try {
				& $retryAction
				$running = $false	
			} catch [Net.WebException] {
				if($_.Exception.Status -eq [Net.WebExceptionStatus]::Timeout) {
                                        if(!($numberOfRetries -lt $retryCount)) {
                                                throw $_
                                        }
                                        $numberOfRetries++
                                        Write-Host "Retrying request due to timeout. Attempt $numberOfRetries of $retryCount"
                                }
				else  { 
					throw $_
				}
			}
			catch {
				throw $_
			} 
		}
	}
	$obj
}
