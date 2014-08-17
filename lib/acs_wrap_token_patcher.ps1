$ErrorActionPreference = "stop"

[Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null
function new_acs_wrap_token_patcher { 
	param(
		[ValidateNotNullOrEmpty()]$namespace = $(throw "namespace is mandatory"),
		[ValidateNotNullOrEmpty()]$identityName = $(throw "identityName is mandatory"),
		[ValidateNotNullOrEmpty()]$key = $(throw "key is mandatory"),
		[ValidateNotNullOrEmpty()]$acsRestClient = $(throw "acsRestClient is mandatory")
	)
	$obj = New-Object PSObject -Property @{ Namespace = $namespace; IdentityName = $identityName; Key = $key; AcsRestClient = $acsRestClient; }
	$obj | Add-Member -Type ScriptMethod execute { param($options)
		$encodedKey = [Web.HttpUtility]::UrlEncode($this.Key)
		$content = "wrap_name=$($this.IdentityName)&wrap_password=$encodedKey&wrap_scope=http://$($this.Namespace).servicebus.windows.net/"

		$result = $this.AcsRestClient.Request(@{
			Verb = "POST";
			Resource = "WRAPV0.9";
			Content = $content;
			ContentType = "application/x-www-form-urlencoded";
			ProcessResponse = $parse_text
		})

		$responseProperties = $result.Split('&')
		$tokenProperty = $responseProperties[0].Split('=')
		$token = [Uri]::UnescapeDataString($tokenProperty[1])

		$options.AuthorizationHeader = "WRAP access_token=`"$token`""
	}
	$obj
}
