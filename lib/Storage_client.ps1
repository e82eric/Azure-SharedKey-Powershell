function new_storage_client { param($storageName, $storageKey, $parsers, $clientType)
	$paramsParser = new_composite_parser $parsers

	$requestHandler = new_request_handler (new_request_builder $storageName)
	$optionsPatcher = new_options_patcher $storageName "2013-08-15" 3 $clientType
	
	$obj = New-Object PSObject -Property @{
		ParamsParser = $paramsParser;
		RequestHandler = $requestHandler;
		OptionsPatcher = $optionsPatcher;
	}
	$obj | Add-Member -Type ScriptMethod _log_params { param($params)
		$params.GetEnumerator() | % {
			Write-Host $_.name
			Write-Host $_.value
		}
	}
	$obj | Add-Member -Type ScriptMethod -Name Request -Value { param ($options)
		$this.optionsPatcher.execute($options)
		$params = @{ Options = $options }
		$this.ParamsParser.execute($params)
		$this._log_params($params)
		$this.RequestHandler.execute($params)
	}
	$obj
}
