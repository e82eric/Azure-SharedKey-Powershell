function new_remote_session_context ($adminUser, $cmdLine, $vmStruct) {
	$obj = New-Object psobject -Property @{
		Name = $vmStruct.Name;
		InstallersDirectory = $vmStruct.InstallersDirectory;
		IsoDrive = $vmStruct.IsoDrive;
		AdminUser = $adminUser;
		CmdLine = $cmdLine;
		Installers = $vmStruct.Installers
		IpAddress = $vmStruct.IpAddress
	}
	
	$obj | Add-Member -Type ScriptMethod -Name RunCmdAsScheduledTask -Value { param($jobName, $cmdText, $expectedExitCode)
		Write-Host "INFO: RunCmdAsScheduledTask. JobName: $($jobName), CmdText: $($cmdText), ExpectedExitCode: $($expectedExitCode)"
		$this.CmdLine.Execute(
			"schtasks",
			@("/CREATE", "/TN", $jobName, "/SC ONCE", "/SD 01/01/2020", "/ST 00:00:00", "/RL HIGHEST","/RU $($this.AdminUser.Name)", "/RP $($this.AdminUser.Password.PlainText)", "/TR `"$cmdText`"", "/F"),
			0
		)
		$this.CmdLine.Execute("schtasks", @("/RUN", "/I", "/TN $jobName"), 0)
		
		$jobResult = -1
		
		Start-Sleep -S 5
		
		while($true) {
			Write-Host "INFO: Checking job status"
			$schedule = new-object -com("Schedule.Service")
			$schedule.connect()
			$tasks = $schedule.getfolder("\").gettasks(0)
			$task = $tasks | ? { $_.Name -Match $jobName }
			$jobResult = $task.LastTaskResult
			
			Write-Host "INFO: --Task Name: $($task.Name)"
			Write-Host "INFO: --Task State: $($task.State)"
			Write-Host "INFO: --Task Last Result: $($task.LastTaskResult)"

			if($task.State -eq 3) {
				break
			}

			Start-Sleep -S 2
		}
		
		if($jobResult -ne $expectedExitCode) {
			throw "Job exited with: $jobResult"
		}
	}
	
	$obj | Add-Member -Type ScriptMethod MountIso -Value { param($name)
		$isoPath = "{0}\{1}" -f $this.InstallersDirectory,$name
		Write-Host "INFO: Mounting Iso. Name: $($name), IsoPath: $($isoPath)"
		Mount-DiskImage -ImagePath $isoPath
		Write-Host "INFO: Done Mounting Iso. Name: $($name), IsoPath: $($isoPath)"
	}

	$obj | Add-Member -Type ScriptMethod _setItemProperty { param(
		[ValidateNotNullOrEmpty()] $path = $(throw "empty paraemter"),
		[ValidateNotNullOrEmpty()] $name = $(throw "empty paraemter"),
		[ValidateNotNullOrEmpty()] $expected = $(throw "empty paraemter")
	)
		$existingValue = (Get-ItemProperty $path)."$($name)"
		if($expected -eq $existingValue) {
			Write-Host "INFO: Registry item property already exists, calling Remove-ItemProperty. Path: $($path), Name: $($name)"
			Remove-ItemProperty -Path $path -Name $name
		} else {
			Write-Host "INFO: Registry item property does not already exist, skipping call to Remove-ItemProperty. Path: $($path), Name: $($name)"
		}
		Set-ItemProperty -Path $path -Name $name -Value $expected
		Write-Host "INFO: Done setting registry item property. Path: $($path), Name: $($name)"
	}

	$obj
}
