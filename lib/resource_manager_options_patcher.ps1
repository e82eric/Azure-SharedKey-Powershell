$ErrorActionPreference = "stop"

function new_resource_manager_options_patcher { 
	param(
		[ValidateNotNullOrEmpty()]$authenticationPatcher,
		[ValidateNotNullOrEmpty()]$baseOptionsPatcher,
		[ValidateNotNullOrEmpty()]$beforeResource	
	)
	$obj = New-Object PSObject -Property @{ 
		BaseOptionsPatcher = $baseOptionsPatcher;
		AuthenticationPatcher = $authenticationPatcher;
		BeforeResource = $beforeResource;
	}
	$obj | Add-Member -Type ScriptMethod execute { param($options)
		$this.BaseOptionsPatcher.execute($options)
		if($null -eq $options.Url) {
			$options.Url = "$($options.Scheme)://$($this.BeforeResource)/$($options.Resource)"
		}
		$this.AuthenticationPatcher.execute($options)
	}
	$obj
}
