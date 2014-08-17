$ErrorActionPreference = "stop"

function new_resource_manager_options_patcher { 
	param(
		[ValidateNotNullOrEmpty()]$subscriptionId,
		[ValidateNotNullOrEmpty()]$authenticationPatcher,
		[ValidateNotNullOrEmpty()]$baseOptionsPatcher
	)
	$obj = New-Object PSObject -Property @{ 
		SubscriptionId = $subscriptionId;
		BaseOptionsPatcher = $baseOptionsPatcher;
		AuthenticationPatcher = $authenticationPatcher;
	}
	$obj | Add-Member -Type ScriptMethod execute { param($options)
		$this.BaseOptionsPatcher.execute($options)
		if($null -eq $options.Url) {
			$options.Url = "$($options.Scheme)://management.azure.com/$($options.Resource)"
		}
		if($null -eq $options.AuthorizationHeader) {
			$this.AuthenticationPatcher.execute($options)
		}
	}
	$obj
}
