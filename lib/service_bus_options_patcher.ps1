function new_service_bus_options_patcher { 
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
			$options.Url = "https://$($this.Namespace).servicebus.windows.net/$($options.Resource)"
		}
		$this.AuthorizationPatcher.execute($options)
	}
	$obj
}
