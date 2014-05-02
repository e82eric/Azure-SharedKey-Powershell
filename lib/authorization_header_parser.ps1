function new_authorization_header_parser { param($storageName)
	$obj = New-Object PSObject -Property @{ StorageName = $storageName }
	$obj | Add-Member -Type ScriptMethod execute { param($params)
		$params.AuthorizationHeader = "SharedKey $($this.StorageName.ToLower()):$($params.SignatureHash)"
	}
	$obj
}
