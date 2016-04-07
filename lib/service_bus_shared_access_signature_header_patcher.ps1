$ErrorActionPreference = "stop"

function new_service_bus_shared_access_signature_header_patcher { 
	param(
		[ValidateNotNullOrEmpty()]$sasProvider = $(throw "sasProvider is mandatory"),
		$announcer
	)
	$obj = New-Object PSObject -Property @{ SasProvider = $sasProvider; Announcer = $announcer; }
	$obj | Add-Member -Type ScriptMethod execute { param($options)
		$sas = $this.SasProvider.GetHeader()
		$this.Announcer.Verbose("Setting authorization header: $($sas)")
		$options.AuthorizationHeader = $sas
	}
	$obj
}
