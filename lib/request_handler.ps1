function new_request_handler { param($requestBuilder)
	$obj = New-Object PSObject -Property @{ RequestBuilder = $requestBuilder }
	$obj | Add-Member -Type ScriptMethod execute { param ($params)
		$result = $null
		$numberOfRetries = 0
		$running = $true

		while($running) { 
			$request = $this.RequestBuilder.execute($params)
			try {
				$response = $request.GetResponse()
				if($null -ne $options.ProcessResponse) {
					$result = & $options.ProcessResponse $response
				}
				$running = $false	
			} catch [Net.WebException] {
				if($_.Exception.Status -eq [Net.WebExceptionStatus]::Timeout) {
                                        if(!($numberOfRetries -lt $options.RetryCount)) {
                                                throw $_
                                        }
                                        $numberOfRetries++
                                        Write-Host "Retrying request due to timeout. Attempt $numberOfRetries of $($options.RetryCount)"
                                }
				else  { 
					throw $_
				}
			}
			catch {
				throw $_
			} finally {
				if($null -ne $response) {
					$response.Close()
				}
			}
		}
		$result
	}
	$obj
}
