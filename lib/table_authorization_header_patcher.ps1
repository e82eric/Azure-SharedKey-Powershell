$ErrorActionPreference = "stop"

function new_table_authorization_header_patcher { param(
	$uriParser,
	$canonicalizedResourcesParser,
	$canonicalizedHeadersParser,
	$signatureParser,
	$signatureHashParser,
	$authorizationHeaderParser)
	$obj = New-Object PSObject -Property @{
		UriParser = $uriParser;
		CanonicalizedResourcesParser = $canonicalizedResourcesParser;
		CanonicalizedHeadersParser = $canonicalizedHeadersParser;
		SignatureParser = $signatureParser;
		SignatureHashParser = $signatureHashParser;
		AuthorizationHeaderParser = $authorizationHeaderParser;
	}
	$obj | Add-Member -Type ScriptMethod execute { param($options)
		$uriElements = $this.UriParser.execute($options.Url)
		$canonicalizedResources = $this.CanonicalizedResourcesParser.execute($uriElements.Resource)
		$date = ($options.Headers | ? { $_.name -eq "x-ms-date" }).value
		$signature = $this.SignatureParser.execute($options.Verb, $options.ContentHash, $options.ContentType, $date, $canonicalizedResources)
		$signatureHash = $this.SignatureHashParser.execute($signature)
		$options.AuthorizationHeader = $this.AuthorizationHeaderParser.execute($signatureHash)
	}
	$obj
}
