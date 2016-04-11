$ErrorActionPreference = "stop"

function new_shell { param(
	[ValidateNotNullOrEmpty()] $defaultWorkingDirectory = $(throw "empty parameter"),
	$announcer
)
	$obj = New-Object PSObject @{ defaultWorkingDirectory = $defaultWorkingDirectory; Announcer = $announcer }
	$obj | Add-Member -Type ScriptMethod Execute { param(
		[ValidateNotNullOrEmpty()] $commandName = $(throw "empty parameter"),
		$arguments,
		[ValidateNotNullOrEmpty()] $acceptableExitCodes = $(throw "empty parameter"),
		$startInfoFunc
	)
		$this.Announcer.ApiTrace("Execute", @{ commandName = $commandName; arguments = $arguments; acceptableExitCodes = $acceptableExitCodes; })
    $oPsi = New-Object Diagnostics.ProcessStartInfo
    $oPsi.CreateNoWindow = $true
    $oPsi.UseShellExecute = $false
    $oPsi.RedirectStandardOutput = $true
    $oPsi.RedirectStandardError = $true
    $oPsi.FileName = $commandName
		$oPsi.WorkingDirectory = $this.defaultWorkingDirectory
    if (! [String]::IsNullOrEmpty($arguments)) {
        $oPsi.Arguments = $arguments
    }

    $oProcess = New-Object Diagnostics.Process
    $oProcess.StartInfo = $oPsi

    $oStdOutBuilder = New-Object Text.StringBuilder
    $oStdErrBuilder = New-Object Text.StringBuilder

    $sScripBlock = {
        if (! [String]::IsNullOrEmpty($EventArgs.Data)) {
            $Event.MessageData.AppendLine($EventArgs.Data)
        }
    }
    $oStdOutEvent = Register-ObjectEvent -InputObject $oProcess `
        -Action $sScripBlock -EventName 'OutputDataReceived' `
        -MessageData $oStdOutBuilder
    $oStdErrEvent = Register-ObjectEvent -InputObject $oProcess `
        -Action $sScripBlock -EventName 'ErrorDataReceived' `
        -MessageData $oStdErrBuilder

    $oProcess.Start() | Out-Null
    $oProcess.BeginOutputReadLine()
    $oProcess.BeginErrorReadLine()
    $oProcess.WaitForExit() | Out-Null

    Unregister-Event -SourceIdentifier $oStdOutEvent.Name
    Unregister-Event -SourceIdentifier $oStdErrEvent.Name

    $result = New-Object -TypeName PSObject -Property ([Ordered]@{
        "ExeFile"  = $sExeFile;
        "Args"     = $cArgs -join " ";
        "ExitCode" = $oProcess.ExitCode;
        "StdOut"   = $oStdOutBuilder.ToString().Trim();
        "StdErr"   = $oStdErrBuilder.ToString().Trim()
    })

		$this.Announcer.Info("Process Exit Code: $($result.ExitCode)")
		$this.Announcer.Info("Process StdOut")
		$this.Announcer.Write($result.StdOut)
		if($false -eq [string]::IsNullOrEmpty($result.StdErr)) {
			$this.Announcer.Info("Process StdErr")
			$this.Announcer.Write($result.StdErr)
		} else {
			$this.Announcer.Info("Process did not contain any StdErr")
		}

		if(!($acceptableExitCodes -Contains $result.ExitCode)) {
			$this.Announcer.Error("Process exited with unexpected exit code. fileName: $($commandName), arguments: $($arguments), acceptableExitCodes: $($acceptableExitCodes), actual exit code: $($result.ExitCode)")
			throw
		}
		$this.Announcer.Info("Process exited with expected exit code. fileName: $($commandName), arguments: $($arguments), acceptableExitCodes: $($acceptableExitCodes), actual exit code: $($result.ExitCode)")
		$result
	}
	$obj
}
