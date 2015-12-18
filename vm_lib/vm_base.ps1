$ErrorActionPreference = "stop"

function new_vm_base ($name, $installersDirectory, $isoDrive) {
	$obj = New-Object PSObject -Property @{
		Name = $name;
		AdminUser = $null;
		WorkingDirectory = $null;
		InstallersDirectory = $installersDirectory;
		IsoDrive = $isoDrive;
		LibDir = $null;
		WinRmUri = $null;
		Installers = $null
	}
	$obj | Add-Member -Type ScriptMethod SetInstallers { param($val) 
		$this.Installers = $val
		$this._validateInstallers()
	}
	$obj | Add-Member -Type ScriptMethod SetAdminUser { param($val)
		$this.AdminUser = $val 
	}
	$obj | Add-Member -Type ScriptMethod SetWorkingDirectory { param($val)
		$this.WorkingDirectory = $val 
	}
	$obj | Add-Member -Type ScriptMethod SetLibDir { param($val)
		$this.LibDir = $val 
	}
	$obj | Add-Member -Type ScriptMethod -Name _remoteSession -Value { param ($session, $sessionFunc)
		try {
			Write-Host "INFO: Trying Remote Session"
			& $sessionFunc $session
		} finally {
			Write-Host "INFO: Disposing Remote Session"
			if ($null -ne $session) {
				$session.Dispose()
			}
		}
	}
	$obj | Add-Member -Type ScriptMethod -Name NegotiateRemoteSession -Value { param ($sessionFunc)
		$session = new_negotiate_remote_session $this
		$this._remoteSession($session, $sessionFunc)
	}

	$obj | Add-Member -Type ScriptMethod -Name RemoteSession -Value { param ($sessionFunc)
		$session = new_credssp_remote_session $this
		$this._remoteSession($session, $sessionFunc)
	}
	$obj | Add-Member -Type ScriptMethod -Name _installChocolatey {
		$this.RemoteSession({ param($session)
			$session.Execute({ param($context)
				Write-Host "INFO: InstallChocolatey"
				Import-Module ServerManager 
				Write-Host "INFO: --Install .net 4.5"
				$context.CmdLine.InstallerExecute($context.Installers.DotNet45, @("/passive", "/norestart", "/Log C:\net45.log"), @(0, 3010, 5100))
				Write-Host "INFO: --Download and run chocolatey install script"
				Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
				Write-Host "INFO: --add chocolatey to path"
				$context.CmdLine.AddToPath("C:\ProgramData\chocolatey\bin")
			})
		})
	}
	$obj | Add-Member -Type ScriptMethod -Name _enableCredSsp -Value {
		Write-Host "**** Start Enable CredSSP ****"
		$this.NegotiateRemoteSession({ param($session)
			$session.Execute({ param($context)
				Write-Host "INFO: Enabling CredSSP"
				Write-Host "INFO: --Create Job"
				$context.RunCmdAsScheduledTask("EnableCredSSP", "winrm set winrm/config/service/auth '@{CredSSP=\""true\""}'", 0)
				Write-Host "INFO: --Done"
			})
		}, "Default")
		Write-Host "**** End Enable CredSSP ****"
	}
	$obj | Add-Member -Type ScriptMethod _configureServer -Value {
		$this.RemoteSession({ param($sesson)
			$session.Execute({ param($context)
				Write-Host "Setting execution policy to remote signed"
				Set-ExecutionPolicy RemoteSigned

				#Fix wsman resource settings
				Write-Host "INFO: Setting MaxMemoryPerShellMB to 0 for wsman"
				Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB 0
				Write-Host "INFO: Setting MaxProcessesPerShell to 0 for wsman"
				Set-Item WSMan:\localhost\Shell\MaxProcessesPerShell 0

				#Fix explorer settings
				$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
				Write-Host "INFO: Set-ItemProperty $($key) Hidden 1"
				Set-ItemProperty $key Hidden 1
				Write-Host "INFO: Set-ItemProperty $($key) HideFileExt 0"
				Set-ItemProperty $key HideFileExt 0
				Write-Host "INFO: Set-ItemProperty $($key) ShowSuperHidden 1"
				Set-ItemProperty $key ShowSuperHidden 1

				#disable server management screens at startup
				$context._setItemProperty("HKLM:\Software\Microsoft\ServerManager", "DoNotOpenServerManagerAtLogon", 1)
				$context._setItemProperty("HKLM:\Software\Microsoft\ServerManager\Oobe", "DoNotOpenInitialConfigurationTasksAtLogon", 1)

				#disable internet explorer enhanced security
				$context._setItemProperty("HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}", "IsInstalled", 0)

				#disable loopback check
				$context._setItemProperty("HKLM:\System\CurrentControlSet\Control\Lsa", "DisableLoopbackCheck", 1)
			})
		})
	}
	$obj | Add-Member -Type ScriptMethod Create -Value {
		$this._createVm()
		$this._waitForBoot()
		$this._setWinRmUri()
		$this._enableCredSSP()
		$this._configureServer()
		$this._downloadInstallers()
		$this._installChocolatey()
	}
	$obj | Add-Member -Type ScriptMethod Restart -Value {
		$this.RemoteSession({ param($sesson)
			$session.Execute({
				Restart-Computer -Force
			})
		})
		Start-Sleep -s 10
		$this._waitForBoot()
		$this._waitForWinRm()
	}
	$obj
}
