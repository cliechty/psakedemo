param(
	[Int32]$buildNumber=0,
	[String]$branchName="localBuild",
	[String]$gitCommitHash="unknownHash",
	[Switch]$isMainBranch=$False
)

cls

# '[p]sake' is the same as 'psake' but $Error is not polluted
Remove-Module [p]ake

# find psake's path
$psakeModule = (Get-ChildItem (".\packages\psake*\tools\psake.psm1")).FullName | Sort-Object $_ | select -Last 1

Import-Module $psakeModule

Invoke-psake -buildFile .\Build\default.ps1 `
			-taskList Package `
			-framework 4.6.1 `
			-properties @{ 
				"buildConfiguration" = "Release" 
				"buildPlatform" = "Any CPU" } `
			-parameters @{ 
				"solutionFile" = "..\psake.sln" 
				"buildNumber" = $buildNumber
				"branchName" = $branchName
				"gitCommitHash" = $gitCommitHash
				"isMainBranch" = $isMainBranch
			}

Write-Host "Build exit code: " $LASTEXITCODE

# Propagating the exit code so that builds actually fail when there is a problem
exit $LASTEXITCODE