$ErrorActionPreference = "stop"

function new_ms_headers_parser {
	$obj = New-Object PSObject
	$obj | Add-Member -Type ScriptMethod _now {
		[DateTime]::UtcNow.ToString("R", [Globalization.CultureInfo]::InvariantCulture)
	}
	$obj | Add-Member -Type ScriptMethod execute { param($options)
		if($null -eq $options.Headers) {
			$options.Headers = @()
		}
		if($null -eq ($options.Headers | ? { $_.name -eq "x-ms-date" })) {
			$options.Headers += @{ name = "x-ms-date"; value = $this._now() }
		}
		if($null -eq ($options.Headers | ? { $_.name -eq "x-ms-version" })) {
			$options.Headers += @{ name = "x-ms-version"; value = $options.Version }
		}
		if($null -eq ($options.Headers | ? { $_.name -eq "x-ms-blob-type" }) -and $null -ne $options.BlobType) {
			$options.Headers += @{ name = "x-ms-blob-type"; value = $options.BlobType }
		}
	}
	$obj
}
