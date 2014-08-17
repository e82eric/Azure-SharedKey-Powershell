$ErrorActionPreference = "stop"

function new_management_options_patcher { 
	param(
		[ValidateNotNullOrEmpty()]$subscriptionId,
		[ValidateNotNullOrEmpty()]$version,
		[ValidateNotNullOrEmpty()]$authenticationPatcher,
		[ValidateNotNullOrEmpty()]$baseOptionsPatcher
	)
	$obj = New-Object PSObject -Property @{ 
		SubscriptionId = $subscriptionId;
		Version = $version;
		BaseOptionsPatcher = $baseOptionsPatcher;
		AuthenticationPatcher = $authenticationPatcher;
	}
	$obj | Add-Member -Type ScriptMethod execute { param($options)
		$this.BaseOptionsPatcher.execute($options)
		if($null -eq $options.Url) {
			$options.Url = "$($options.Scheme)://management.core.windows.net/$($this.SubscriptionId)/$($options.Resource)"
		}
		if($null -eq $options.Version) {
			$options.Version = $this.Version
		}
    $options.Headers += @{ name = "x-ms-version"; value = $options.Version }
		if($null -eq $options.AuthorizationHeader) {
			$this.AuthenticationPatcher.execute($options)
		}
	}
	$obj
}
