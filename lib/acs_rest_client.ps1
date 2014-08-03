param($restLibDir)

. "$restLibDir\request_builder.ps1"
. "$restLibDir\retry_handler.ps1"
. "$restLibDir\request_handler.ps1"
. "$restLibDir\response_handlers.ps1"

[Reflection.Assembly]::LoadWithPartialName("System.Security.Cryptography") | Out-Null
[Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null
[Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions") | Out-Null

function new_acs_rest_client { param($namespace, $key)
  $requestBuilder = new_request_builder
  $retryHandler = new_retry_handler $write_response
  $requestHandler = new_request_handler $requestBuilder $retryHandler

  $obj = New-Object PSObject -Property @{ 
    RequestHandler = $requestHandler;
    Namespace = $namespace;
    Key = $key;
  }
  $obj | Add-Member -Type ScriptMethod Request { param($verb, $resource, $content)
    $token = $this._getToken()

    $url = "https://$($this.Namespace)-sb.accesscontrol.windows.net/v2/mgmt/$resource"

    $params = @{
      MsHeaders = @();
      AuthorizationHeader = "Bearer $($token.access_token)";
      Options = @{
        Url = $url;
        RetryCount = 3;
        Verb = $verb;
        ContentType = "application/atom+xml";
        Content = $content;
        ProcessResponse = $parse_xml;
      }
    }

    $this.RequestHandler.Execute($params)
  }
  $obj | Add-Member -Type ScriptMethod _getToken {
    $url = "https://$($this.Namespace)-sb.accesscontrol.windows.net/v2/OAuth2-13?"

    $encodedKey = [Web.HttpUtility]::UrlEncode($this.Key) 
    $encodedScope = [Web.HttpUtility]::UrlEncode("https://$($this.Namespace)-sb.accesscontrol.windows.net/v2/mgmt/service/") 
    $content = "grant_type=client_credentials&client_id=SBManagementClient&client_secret=$encodedKey&scope=$encodedScope"

    $requestParams = @{
      MsHeaders = @();
      Options = @{
        Url = $url;
        RetryCount = 3;
        ContentType = "application/x-www-form-urlencoded";
        Verb = "POST";
        Content = $content;
        ProcessResponse = $parse_json;
      }
    }

    $this.requestHandler.Execute($requestParams)
  }
  $obj
}
