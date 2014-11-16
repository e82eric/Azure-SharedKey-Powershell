$ErrorActionPreference = "stop"

function new_options_patcher { param(
	$baseOptionsPatcher,
	$version,
	$msHeadersPatcher)
	$obj = New-Object PSObject -Property @{ 
		BaseOptionsPatcher = $baseOptionsPatcher;
		Version = $version;
		MsHeadersPatcher = $msHeadersPatcher;
	}
	$obj | Add-Member -Type ScriptMethod execute { param($options)
		if($null -eq $options.Version) {
			$options.Version = $this.Version
		}
		$this.MsHeadersPatcher.execute($options)
		$this.BaseOptionsPatcher.execute($options)
	}
	$obj
}
