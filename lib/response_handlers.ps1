$parse_text = { param ($response, $announcer)
	$announcer.Debug("Process response as text")
	$stream = $response.GetResponseStream()
	$reader = New-Object IO.StreamReader($stream)
	$result = $reader.ReadToEnd()
	$stream.Close()
	$reader.Close()
	$result
}
$parse_xml = { param ($response, $announcer)
	$announcer.Debug("Process response as xml")
	$stream = $response.GetResponseStream()
	$reader = New-Object IO.StreamReader($stream)
	$result = $reader.ReadToEnd()
	$stream.Close()
	$reader.Close()
	[xml]$result
}
$parse_json = { param($response, $announcer)
	$announcer.Debug("Process response as json")
	[Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions") | Out-Null
	$stream = $response.GetResponseStream()
	$reader = New-Object IO.StreamReader($stream)
	$result = $reader.ReadToEnd()
	$stream.Close()
	$reader.Close()
	$jsonSerializer = New-Object Web.Script.Serialization.JavaScriptSerializer
	$jsonSerializer.DeserializeObject($result)
}
$write_host = { param($response, $announcer)
	$announcer.Debug("Process response as Write-Host")
	$stream = $response.GetResponseStream()
	$reader = New-Object IO.StreamReader($stream)
	$result = $reader.ReadToEnd()
	$stream.Close()
	$reader.Close()
	$announcer.Write($result)
}
$write_response = { param($response, $announcer)
	$announcer.Debug("Process response as Write-Host Response content => {0}")
	$reqstream = $response.GetResponseStream()
	$sr = New-Object IO.StreamReader $reqstream
	$result = $sr.ReadToEnd()
	$sr.Close()
	$reqstream.Close()
	$announcer.Write("Response content => $($result)")
}
$parse_null = { param($response, $announcer)
	$announcer.Debug("Process response as null")
	$reqstream = $response.GetResponseStream()
	$reqstream.Close()
}
$parse_ms_headers = { param ($response, $announcer)
	$announcer.Debug("Process response as ms headers")
	$result = @()
	$response.Headers | % {
		if($_.StartsWith("x-ms")) {
			$result += @{ name = $_; value = $response.Headers[$_] }
		}
	}
	$stream = $response.GetResponseStream()
	$stream.Close()
	$result
}
