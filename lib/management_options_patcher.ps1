$ErrorActionPreference = "stop"

function new_management_options_patcher { 
	param(
		[ValidateNotNullOrEmpty()]$version,
		[ValidateNotNullOrEmpty()]$baseOptionsPatcher
	)
	$obj = New-Object PSObject -Property @{ 
		Version = $version;
		BaseOptionsPatcher = $baseOptionsPatcher;
	}
	$obj | Add-Member -Type ScriptMethod execute { param($options)
		$this.BaseOptionsPatcher.execute($options)
		if($null -eq $options.Version) {
			$options.Version = $this.Version
		}
		$options.Headers += @{ name = "x-ms-version"; value = $options.Version }
	}
	$obj
}
