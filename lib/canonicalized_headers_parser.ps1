$ErrorActionPreference = "stop"

function new_canonicalized_headers_parser {
	$obj = New-Object PSObject
	$obj | Add-Member -Type ScriptMethod execute { param ($headers)
		$concatenatedHeaders = $headers | ? { $_.name.startswith("x-ms") } | % { "$($_.Name):$($_.Value)" }
		[string]::join("`n", ($concatenatedHeaders | Sort))
	}
	$obj
}
