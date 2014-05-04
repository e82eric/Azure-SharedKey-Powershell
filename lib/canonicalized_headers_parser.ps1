$ErrorActionPreference = "stop"

function new_canonicalized_headers_parser {
	$obj = New-Object PSObject
	$obj | Add-Member -Type ScriptMethod execute { param ($params)
		$concatenatedHeaders = $params.MsHeaders | % { "$($_.Name):$($_.Value)" }
		$params.CanonicalizedHeaders = [string]::join("`n", ($concatenatedHeaders | Sort))
	}
	$obj
}
