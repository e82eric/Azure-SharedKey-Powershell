$ErrorActionPreference = "stop"

function get_environment_configuration { param(
	[ValidateNotNullOrEmpty()] $name = $(throw "empty parameter"),
	[ValidateNotNullOrEmpty()] $workingDir = $(throw "empty parameter")
)
	switch($name) {
		"local" {
			$deployType = "local"
			$packageDir = "C:\temp\packages"
			$utilsDir = (Resolve-Path "$($workingDir)").Path
			$toolsDir = (Resolve-Path "$($workingDir)").Path
			$binariesDir = (Resolve-Path "$($workingDir)").Path
		}
	}

	$result = @{
		Scripts = @(
			"$($utilsDir)\shell.ps1",
			"$($utilsDir)\announcer.ps1"
		);
		NugetCli = @{
			Path = "$($toolsDir)\nuget.exe";
		}
		NugetFeed = @{
			Type = $deployType;
			Directory = $packageDir;
		};
		Package = @{
			Path = "$($binariesDir)\rest-library-for-azure.1.0.0.0.nupkg";
		}
	}
	
	$result
}
