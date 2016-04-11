param(
	[ValidateNotNullOrEmpty()] $environment = $(throw "empty parameter"),
	$workingDir = (Resolve-Path .\).Path
)
$ErrorActionPreference = "stop"

. "$($workingDir)\config_environment.ps1"

$script:envConfig = get_environment_configuration $environment $workingDir
$script:envConfig.Scripts | % {
	. "$($_)"
}

$script:announcer = new_announcer
$script:shell = new_shell $workingDir $script:announcer

function deploy_package {
	$nugetCliPath = $script:envConfig.NugetCli.Path
	$packagePath = $script:envConfig.Package.Path
	$feedDirectory = $script:envConfig.NugetFeed.Directory

	$script:shell.Execute($nugetCliPath, @("add", $packagePath, "-source $($feedDirectory)"), 0)
}
