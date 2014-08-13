$ErrorActionPreference = "stop"

function new_certificate_authentication_handler { param($cert)
	$obj = New-Object PSObject -Property @{ Cert = $cert; }
	$obj | Add-Member -Type ScriptMethod Handle { param($options)
		$options.ClientCertificate = $this.Cert
	}
	$obj
}
