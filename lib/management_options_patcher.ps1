$ErrorActionPreference = "stop"

function new_management_options_patcher { 
	param(
		[ValidateNotNullOrEmpty()]$urlPatcher,
		[ValidateNotNullOrEmpty()]$version,
		[ValidateNotNullOrEmpty()]$authenticationPatcher,
		[ValidateNotNullOrEmpty()]$baseOptionsPatcher
	)
	$obj = New-Object PSObject -Property @{ 
		UrlPatcher = $urlPatcher;
		Version = $version;
		BaseOptionsPatcher = $baseOptionsPatcher;
		AuthenticationPatcher = $authenticationPatcher;
	}
	$obj | Add-Member -Type ScriptMethod execute { param($options)
		$this.BaseOptionsPatcher.execute($options)
		$this.UrlPatcher.execute($options)
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

function new_subscription_management_url_patcher { param($subscriptionId)
	$obj = New-Object PSObject -Property @{ SubscriptionId = $subscriptionId }
	$obj | Add-Member -Type ScriptMethod execute { param($options)
		if($null -eq $options.Url) {
			$options.Url = "$($options.Scheme)://management.core.windows.net/$($this.SubscriptionId)/$($options.Resource)"
		}
	}
	$obj
}

function new_management_url_patcher {
	$obj = New-Object PSObject
	$obj | Add-Member -Type ScriptMethod execute { param($options)
		if($null -eq $options.Url) {
			$options.Url = "$($options.Scheme)://management.core.windows.net/$($options.Resource)"
		}
	}
	$obj
}
