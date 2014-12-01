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
			Write-Host "Trying Remote Session"
			& $sessionFunc $session
		} finally {
			Write-Host "Disposing Remote Session"
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
				Import-Module ServerManager 
				Add-WindowsFeature as-net-framework
				$context.CmdLine.InstallerExecute($context.Installers.DotNet45, @("/passive", "/norestart", "/Log C:\net45.log"), 0)
				Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
				$context.CmdLine.AddToPath("C:\ProgramData\chocolatey\bin")
			})
		})
	}
	$obj | Add-Member -Type ScriptMethod _installIsoMounter -Value {
		$this.RemoteSession({ param($session)
			$session.Execute({ param($context, $installers)
				$context.CmdLine.Execute("C:\ProgramData\chocolatey\bin\cinst", @("VirtualCloneDrive"), 0)
			},
			@($this.Installers))
		})
	}
	$obj | Add-Member -Type ScriptMethod -Name _enableCredSsp -Value {
		Write-Host "**** Start Enable CredSSP ****"
		$this.NegotiateRemoteSession({ param($session)
			$session.Execute({ param($context)
				Write-Host "**** Start Creating CredSSP Jobs ****"
				$context.RunCmdAsScheduledTask("EnableCredSSP", "winrm set winrm/config/service/auth '@{CredSSP=\""true\""}'", 0)
				Write-Host "**** End Creating CredSSP Jobs ****"
			})
		}, "Default")
		Write-Host "**** End Enable CredSSP ****"
	}
	$obj | Add-Member -Type ScriptMethod _configureServer -Value {
		$this.RemoteSession({ param($sesson)
			$session.Execute({
				Set-ExecutionPolicy RemoteSigned

				#Fix wsman resource settings
				Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB 0
				Set-Item WSMan:\localhost\Shell\MaxProcessesPerShell 0

				#Fix explorer settings
				$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
				Set-ItemProperty $key Hidden 1
				Set-ItemProperty $key HideFileExt 0
				Set-ItemProperty $key ShowSuperHidden 1

				#disable server management screens at startup
				Set-ItemProperty -Path HKLM:\Software\Microsoft\ServerManager -Name DoNotOpenServerManagerAtLogon -Value 1
				Set-ItemProperty -Path HKLM:\Software\Microsoft\ServerManager\Oobe -Name DoNotOpenInitialConfigurationTasksAtLogon -Value 1

				#disable internet explorer enhanced security
				Set-ItemProperty `
					-Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" `
					-Name "IsInstalled" `
					-Value 0

				#disable loopback check
				New-ItemProperty HKLM:\System\CurrentControlSet\Control\Lsa -Name "DisableLoopbackCheck" -Value 1 -PropertyType dword
				
				#disable windows update
				$cmdLine.Execute("sc", @("config wuauserv", "start= disabled"), 0)
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
		$this._installIsoMounter()
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
