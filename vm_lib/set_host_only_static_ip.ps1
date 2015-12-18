param($adapterMacAddress, $ipAddress, $hostIpAddress)
$ErrorActionPreference = "stop"

$logFile = "C:\set_host_only_static_ip.ps1.log"
function run_cmd($commandName, $arguments, $expectedExitCode, $returnStdOut = $false) {
	$concatenatedArguments = ""
	$arguments | ForEach-Object {$concatenatedArguments += "$_ "}

	"INFO: run_cmd" | Add-Content $logFile
	"INFO: --command name: $($commandName)" | Add-Content $logFile
	"INFO: --arguments: $($arguments)" | Add-Content $logFile
	"INFO: --expected exit code: $($expectedExitCode)" | Add-Content $logFile
	
	$startInfo = New-Object Diagnostics.ProcessStartInfo
	$startInfo.FileName = $commandName
	$startInfo.UseShellExecute = $false
	$startInfo.Arguments = $concatenatedArguments
	$process = New-Object Diagnostics.Process
	$process.StartInfo = $startInfo
	$process.Start() | Out-Null
	$process.WaitForExit()
	$exitCode = $process.ExitCode
	"INFO: --exit code: $($exitCode)" | Append-Content $logFile
	if($exitCode -ne $expectedExitCode) {
		$errorMessage = "The command exited with a code of: $exitCode"
		throw $errorMessage
	}
}

"Starting" | Out-File $logFile
"adapterMacAddress: $($adapterMacAddress)" | Add-Content $logFile
"ipAddress: $($ipAddress)" | Add-Content $logFile
"hostIpAddress: $($hostIpAddress)" | Add-Content $logFile

$hostOnlyAdapterName = (Get-NetAdapter | ? { $_.MacAddress.Replace('-', '') -eq $adapterMacAddress }).Name
"hostOnlyAdapterName: $($hostOnlyAdapterName)" | Add-Content $logFile

run_cmd "netsh" @("interface", "ip", "set", "address", "`"$($hostOnlyAdapterName)`"", "Static", "`"$($ipAddress)`"", "`"255.255.255.0`"", "`"$($hostIpAddress)`"") 0
run_cmd "netsh" @("interface", "ip", "add", "dns", "`"$($hostOnlyAdapterName)`"", "`"$($hostIpAddress)`"") 0
"Done" | Add-Content $logFile
