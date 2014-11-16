$ErrorActionPreference = "stop"

function new_acs_client_token_patcher { 
	param(
		[ValidateNotNullOrEmpty()]$namespace = $(throw "namespace is mandatory"),
		[ValidateNotNullOrEmpty()]$key = $(throw "key is mandatory"))
	$obj = New-Object PSObject -Property @{ Namespace = $namespace; Key = $key; AcsRestClient = $null; }
	$obj | Add-Member -Type ScriptMethod execute { param($options)
		if($options.Resource -ne "v2/OAuth2-13?" -And $options.Resource -ne "WRAPV0.9") {
			$encodedKey = [Web.HttpUtility]::UrlEncode($this.Key) 
			$encodedScope = [Web.HttpUtility]::UrlEncode("https://$($this.Namespace)-sb.accesscontrol.windows.net/v2/mgmt/service/") 
			$content = "grant_type=client_credentials&client_id=SBManagementClient&client_secret=$encodedKey&scope=$encodedScope"

			$token = $this.AcsRestClient.Request(@{
				Verb = "POST";
				Resource = "v2/OAuth2-13?";
				Content = $content;
				ContentType = "application/x-www-form-urlencoded";
				ProcessResponse = $parse_json
			})

			$options.AuthorizationHeader = "Bearer $($token.access_token)"
		}
	}
	$obj
}
