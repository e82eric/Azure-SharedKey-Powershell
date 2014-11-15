$parse_text = { param ($response)
	$stream = $response.GetResponseStream()
	$reader = New-Object IO.StreamReader($stream)
	$result = $reader.ReadToEnd()
	$stream.Close()
	$reader.Close()
	$result
}
$parse_xml = { param ($response)
	$stream = $response.GetResponseStream()
	$reader = New-Object IO.StreamReader($stream)
	$result = $reader.ReadToEnd()
	$stream.Close()
	$reader.Close()
	[xml]$result
}
$parse_json = { param($response)
	[Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions") | Out-Null
	$stream = $response.GetResponseStream()
	$reader = New-Object IO.StreamReader($stream)
	$result = $reader.ReadToEnd()
	$stream.Close()
	$reader.Close()
	$jsonSerializer = New-Object Web.Script.Serialization.JavaScriptSerializer
	$jsonSerializer.DeserializeObject($result)
}
$write_host = { param($response)
	$stream = $response.GetResponseStream()
	$reader = New-Object IO.StreamReader($stream)
	$result = $reader.ReadToEnd()
	$stream.Close()
	$reader.Close()
	Write-Host $result
}
$write_response = { param($response)
	$reqstream = $response.GetResponseStream()
	$sr = new-object System.IO.StreamReader $reqstream
	$result = $sr.ReadToEnd()
	Write-Host "Response content => $result"
}
$parse_ms_headers = { param ($response)
	$result = @()
	$response.Headers | % {
		if($_.StartsWith("x-ms")) {
			$result += @{ name = $_; value = $response.Headers[$_] }
		}
	}
	$result
}
