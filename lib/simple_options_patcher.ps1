$ErrorActionPreference = "stop"

function new_simple_options_patcher {
	param(
		[ValidateNotNullOrEmpty()]$defaultRetryCount,
		[ValidateNotNullOrEmpty()]$defaultScheme,
		[ValidateNotNullOrEmpty()]$defaultContentType,
		[ValidateNotNullOrEmpty()]$defaultTimeout
	)
	$obj = New-Object PSObject -Property @{ 
		DefaultRetryCount = $retryCount;
		DefaultScheme = $defaultScheme;
		DefaultContentType = $defaultContentType;
		DefaultTimeout = $defaultTimeout;
	}
	$obj | Add-Member -Type ScriptMethod execute { param($options)
		if($null -eq $options.Scheme) {
			$options.Scheme = $this.DefaultScheme	
		}
		if($null -eq $options.RetryCount) {
			$options.RetryCount = $this.DefaultRetryCount
		}
		if($null -eq $options.Timeout) {
			$options.Timeout = $this.DefaultTimeout
		}
    if($null -eq $options.ContentType) {
      $options.ContentType = $this.DefaultContentType
    }
    if($null -eq $options.Headers) {
      $options.Headers = @()
    }
    if($null -eq $options.ProcessResponse) {
      $options.ProcessResponse = $options.OnResponse
    }
	}
	$obj
}
