function new_acs_options_patcher { 
	param(
		[ValidateNotNullOrEmpty()]$namespace=$(throw "namespace is mandatory"),
		[ValidateNotNullOrEmpty()]$baseOptionsPatcher=$(throw "baseOptionsPatcher is mandatory"),
		[ValidateNotNullOrEmpty()]$authorizationPatcher=$(throw "authorizationPatcher is mandatory")
	)
	$obj = New-Object PSObject -Property @{
		Namespace = $namespace;
		BaseOptionsPatcher = $baseOptionsPatcher;
		AuthorizationPatcher = $authorizationPatcher;
	}
	$obj | Add-Member -Type ScriptMethod execute { param($options)
		$this.BaseOptionsPatcher.execute($options)
		if($null -eq $options.Url) {
			$options.Url = "https://$($this.Namespace)-sb.accesscontrol.windows.net/$($options.Resource)"
		}
		if($options.Resource -ne "v2/OAuth2-13?" -And $options.Resource -ne "WRAPV0.9") {
			$this.AuthorizationPatcher.execute($options)
		}
	}
	$obj
}
