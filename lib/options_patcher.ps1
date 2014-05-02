function new_options_patcher { param($storageName, $version, $retryCount, $clientType)
	$obj = New-Object PSObject -Property @{ 
		StorageName = $storageName;
		Version = $version;
		RetryCount = $retryCount;
		ClientType = $clientType;
	}
	$obj | Add-Member -Type ScriptMethod execute { param($options)
		if($null -eq $options.Url) {
			$options.Url = "http://$($this.StorageName).$($this.ClientType).core.windows.net/$($options.Resource)"
		}
		if($null -eq $options.RetryCount) {
			$options.RetryCount = $this.RetryCount
		}
		if($null -eq $options.Version) {
			$options.Version = $this.Version
		}
	}
	$obj
}
