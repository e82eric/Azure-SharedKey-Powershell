$ErrorActionPreference = "stop"

function new_client_certificate_patcher { param($cert)
	$obj = New-Object PSObject -Property @{ Cert = $cert; }
	$obj | Add-Member -Type ScriptMethod execute { param($options)
		$options.ClientCertificate = $this.Cert
	}
	$obj
}
