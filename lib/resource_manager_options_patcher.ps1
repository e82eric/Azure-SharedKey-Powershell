$ErrorActionPreference = "stop"

function new_resource_manager_options_patcher { 
	param(
		[ValidateNotNullOrEmpty()]$authenticationPatcher,
		[ValidateNotNullOrEmpty()]$baseOptionsPatcher,
		[ValidateNotNullOrEmpty()]$authority,
		[ValidateNotNullOrEmpty()]$beforeResource	
	)
	$obj = New-Object PSObject -Property @{ 
		BaseOptionsPatcher = $baseOptionsPatcher;
		AuthenticationPatcher = $authenticationPatcher;
		Authority = $authority;
		BeforeResource = $beforeResource;
	}
	$obj | Add-Member -Type ScriptMethod execute { param($options)
		$this.BaseOptionsPatcher.execute($options)
		if($null -eq $options.Url) {
			$options.Url = "$($options.Scheme)://$($this.Authority)/$($this.BeforeResource)/$($options.Resource)"
		}
		if($null -eq $options.AuthorizationHeader) {
			$this.AuthenticationPatcher.execute($options)
		}
	}
	$obj
}
