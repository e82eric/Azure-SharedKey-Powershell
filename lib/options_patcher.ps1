$ErrorActionPreference = "stop"

function new_options_patcher { param($storageName, $version, $retryCount, $clientType, $defaultScheme, $msHeadersPatcher, $authorizationHeaderPatcher)
	$obj = New-Object PSObject -Property @{ 
		StorageName = $storageName;
		Version = $version;
		RetryCount = $retryCount;
		ClientType = $clientType;
		DefaultScheme = $defaultScheme;
		MsHeadersPatcher = $msHeadersPatcher;
		AuthorizationHeaderPatcher = $authorizationHeaderPatcher;
	}
	$obj | Add-Member -Type ScriptMethod execute { param($options)
		if($null -eq $options.Scheme) {
			$options.Scheme = $this.DefaultScheme	
		}
		if($null -eq $options.Url) {
			$options.Url = "$($options.Scheme)://$($this.StorageName).$($this.ClientType).core.windows.net/$($options.Resource)"
		}
		if($null -eq $options.RetryCount) {
			$options.RetryCount = $this.RetryCount
		}
		if($null -eq $options.Version) {
			$options.Version = $this.Version
		}

		$this.MsHeadersPatcher.execute($options)

		if($null -eq $options.AuthorizationHeader) {
			$this.AuthorizationHeaderPatcher.execute($options)
		}
	}
	$obj
}
