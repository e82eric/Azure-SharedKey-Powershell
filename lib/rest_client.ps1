$ErrorActionPreference = "stop"

function new_rest_client { 
	param(
		$requestHandler,
		$optionsPatcher
	)
	$obj = New-Object PSObject -Property @{
		RequestHandler = $requestHandler;
		OptionsPatcher = $optionsPatcher;
	}
	$obj | Add-Member -Type ScriptMethod -Name Request -Value { param ($options)
		$this.optionsPatcher.execute($options)
		$this.RequestHandler.execute($options)
	}
	$obj
}
