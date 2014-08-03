function new_retry_handler { param($exceptionResponseHandler)
  $obj  = New-Object PSObject -Property @{ ExceptionResponseHandler = $exceptionResponseHandler }
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
          if($null -ne $_.Exception.Response) {
            & $this.ExceptionResponseHandler $_.Exception.Response
          }
          if(!($numberOfRetries -lt $retryCount)) {
            throw $_
          }
          $numberOfRetries++
          Write-Host "Retrying request due to timeout. Attempt $numberOfRetries of $retryCount"
        }
        else  { 
          if($null -ne $_.Exception.Response) {
            & $this.ExceptionResponseHandler $_.Exception.Response
          }
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
