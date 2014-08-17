$ErrorActionPreference = "stop"

function new_authorization_header_parser { param($storageName)
	$obj = New-Object PSObject -Property @{ StorageName = $storageName }
	$obj | Add-Member -Type ScriptMethod execute { param($signatureHash)
		"SharedKey $($this.StorageName.ToLower()):$($signatureHash)"
	}
	$obj
}
