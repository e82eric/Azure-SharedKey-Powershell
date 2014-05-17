$ErrorActionPreference = "stop"

function new_service_bus_rest_client { param($namespace, $password)
	$obj = New-Object PSObject -Property @{ Namespace = $namespace; Password = $password }
	$obj | Add-Member -Type ScriptMethod _get_swt_token {
		[Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null
		$acsUrl = "https://$($this.Namespace)-sb.accesscontrol.windows.net/WRAPV0.9/"
		$encodedPassword = [Web.HttpUtility]::UrlEncode($this.Password)
		$requestBody = "wrap_name=owner&wrap_password=$encodedPassword&wrap_scope=http://$($this.namespace).servicebus.windows.net/"

		$result = $this._request(@{ Verb = "POST"; Url = $acsUrl; Content= $requestBody; ContentType = "application/x-www-form-urlencoded"; OnResponse = $parse_text })

		$responseProperties = $result.Split('&')
		$tokenProperty = $responseProperties[0].Split('=')
		$token = [Uri]::UnescapeDataString($tokenProperty[1])

		"WRAP access_token=`"$token`""
	}
	$obj | Add-Member -Type ScriptMethod request { param($options)
		$token = $this._get_swt_token()
		if($null -eq $options.Headers) {
			$options.Headers = @()
		}
		$options.Headers += @{ name = "authorization"; value = $token }
		$this._request($options)
	}
	$obj | Add-Member -Type ScriptMethod _request { param($options)
		if($null -eq $options.Url) {
			$options.Url = "https://$($this.namespace).servicebus.windows.net/$($options.Resource)"
		}

		$request = [Net.WebRequest]::Create($options.Url)
        $request.Method = $options.Verb

		if($null -ne $options.Headers) {
			$options.Headers | % { $request.Headers.Add($_.name, $_.value) }
		}
		
		if($null -ne $options.ContentType) {
			$request.ContentType = $options.ContentType
		}

		if($null -ne $options.Content) {
			$request.ContentLength = $options.Content.Length
			$requestStream = $request.GetRequestStream()
			$byteArray = [Text.Encoding]::UTF8.GetBytes($options.Content)
			$requestStream.Write($byteArray, 0, $byteArray.Length) | Out-Null
			$requestStream.Close() | Out-Null
		}

		$response = $null
		$result = $null
		
		try {
			$response = $request.GetResponse()
			if($options.OnResponse -ne $null) {
				$result = & $options.OnResponse $response
			}
		} finally {
			if($null -ne $response) {
				$response.Close() | Out-Null
			}
		}
		
		$result
	}
	$obj
}
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
