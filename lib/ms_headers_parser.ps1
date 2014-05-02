function new_ms_headers_parser {
	$obj = New-Object PSObject
	$obj | Add-Member -Type ScriptMethod execute { param($params)
		$options = $params.Options

		$now = [DateTime]::UtcNow.ToString("R", [Globalization.CultureInfo]::InvariantCulture)
		$dateHeader = @{ name = "x-ms-date"; value = $now }
		$versionHeader = @{ name = "x-ms-version"; value = $options.Version }
		$result = @($dateHeader, $versionHeader)
		if($null -ne $options.BlobType) {
			$blobHeader = @{ name = "x-ms-blob-type"; value = $options.BlobType }
			$result = $result + $blobHeader
		}
		$params.MsHeaders = $result
	}
	$obj
}
