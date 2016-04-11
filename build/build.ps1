Framework "4.5.1"

properties {
	$script:rootDir = Resolve-Path ".."
	$script:buildDir = "$($rootDir)\build"
	$script:binariesDir = "$($rootDir)\binaries"
	$script:toolsDir = "$($rootDir)\tools"
	$script:utilsDir = "$($rootDir)\utils"
	$script:nugetCli = "$($toolsDir)\nuget.exe"	
	$script:rootSrcDir = "$($rootDir)\lib"
	$script:unitTestsDir = "$($rootDir)\unit_tests"
	$script:integrationTestsDir = "$($rootDir)\integration_tests"

	. "$($script:utilsDir)\shell.ps1"
	. "$($script:utilsDir)\announcer.ps1"
	$script:announcer = new_announcer
	$script:shell = new_shell $script:binariesDir $script:announcer
	$script:versionNumber = "1.0.0.0"

	Import-Module "$($script:toolsDir)\pester\pester.psm1"
}

task default -depends `
	clean, `
	add_install_items, `
	run_unit_tests, `
	package, `
	build_lib, `
	build_integration_tests

task clean {
	if($true -eq (Test-Path ..\binaries)) {
		Remove-Item $script:binariesDir -Force -Recurse 
	}
	New-Item $script:binariesDir -Type Directory | Out-Null
}

task package -Depends clean {
	$script:shell.Execute($script:nugetCli, @("pack", "$($script:rootDir)\lib.nuspec", "-OutputDirectory $($script:binariesDir)", "-BasePath $($rootDir)", "-Version $($script:versionNumber)"), 0) | Out-Null
}

task add_install_items {
	@(
		"$($script:buildDir)\deploy.ps1",
		"$($script:buildDir)\config_environment.ps1",
		"$($script:utilsDir)\announcer.ps1",
		"$($script:utilsDir)\shell.ps1",
		$script:nugetCli
	) | % {
		Copy-Item $_ $script:binariesDir
	}
}

task run_unit_tests {
	Invoke-Pester -relative_path $script:unitTestsDir
}

task build_lib {
	$outDir = "$($script:binariesDir)\lib"
	New-Item "$($script:binariesDir)\lib" -Type Directory
	Copy-Item "$($script:rootSrcDir)\*.ps1" $outDir
}

task build_integration_tests {
	$outDir = "$($script:binariesDir)\integration_tests"
	New-Item "$($script:binariesDir)\integration_tests" -Type Directory
	Copy-Item "$($script:integrationTestsDir)\*.ps1" $outDir
}
