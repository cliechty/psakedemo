Include ".\helpers.ps1"

properties {
	$testMessage = 'Executed Test!'
	$compileMessage = 'Executed Compile!'
	$cleanMessage = 'Executed Clean!'

	$solutionDirectory = (Get-Item $solutionFile).DirectoryName
	$outputDirectory = "$solutionDirectory\.build"
	$temporaryOutputDirectory = "$outputDirectory\temp"

	$publishedNUnitTestsDirectory = "$temporaryOutputDirectory\_PublishedNUnitTests"
	$publishedMSTestTestsDirectory = "$temporaryOutputDirectory\_PublishedMSTestTests"
	$publishedXUnitTestsDirectory = "$temporaryOutputDirectory\_PublishedXUnitTests"

	$testResultsDirectory = "$outputDirectory\TestResults"
	$NUnitTestResultsDirectory = "$testResultsDirectory\NUnit"
	$MSTestTestResultsDirectory = "$testResultsDirectory\MSTest"
	$xUnitTestResultsDirectory = "$testResultsDirectory\xUnit"

	$buildConfiguration = "Release"
	$buildPlatform = "Any CPU"

	$packagesPath = "$solutionDirectory\packages"
	$NUnitExe = (Find-PackagePath $packagesPath "NUnit.ConsoleRunner") + "\Tools\nunit3-console.exe"
	$xUnitExe = (Find-PackagePath $packagesPath "xUnit.Runner.Console") + "\Tools\xunit.console.exe"
	$vsTestExe = (Get-ChildItem ("C:\Program Files (x86)\Microsoft Visual Studio*\Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe")).FullName | Sort-Object $_ | select -Last 1
}

FormatTaskName "`r`n`r`n-------- Executing {0} Task --------"

task default -depends Test

task Init -description "Initializes the build by removing previous artifacts and creating output directories" `
			-requiredVariables outputDirectory, temporaryOutputDirectory {

	Assert ("Debug", "Release" -contains $buildConfiguration) `
			"Invalid build configuration '$buildConfiguration'. Valid values are 'Debug' or 'Release'"

	Assert ("x86", "x64", "Any CPU" -contains $buildPlatform) `
			"Invalid build platform '$buildPlatform'. Valid values are 'x86', 'x64' or 'Any CPU'"

	# Check that all tools are available
	Write-Host "Checking that all required tools are available"

	Assert (Test-Path $NUnitExe) "NUnit Console could not be found"
	Assert (Test-Path $xUnitExe) "xUnit Console could not be found"
	Assert (Test-Path $vsTestExe) "VSTest Console could not be found"

	# Remove previous build results
	if (Test-Path $outputDirectory) {
		Write-Host "Removing output directory located at $outputDirectory"
		Remove-Item $outputDirectory -Force -Recurse
	}

	Write-Host "Creating output directory located at $outputDirectory"
	New-Item $outputDirectory -ItemType Directory | Out-Null

	Write-Host "Creating temporary directory located at $temporaryOutputDirectory"
	New-Item $temporaryOutputDirectory -ItemType Directory | Out-Null
}

task Clean -description "Remove temporary files" {
	Write-Host $cleanMessage
}

task Compile `
	-depends Init `
	-description "Compile the code"  `
	-requiredVariables solutionFile, buildConfiguration, buildPlatform, temporaryOutputDirectory `
{
	Write-Host "Building solution $solutionFile"
	Exec {
		msbuild $solutionFile "/p:Configuration=$buildConfiguration;Platform=$buildPlatform;OutDir=$temporaryOutputDirectory"
	}
}

task TestNUnit `
	-depends Compile `
	-description "Run NUnit tests" `
	-precondition { return Test-Path $publishedNUnitTestsDirectory } `
{
	$testAssemblies = Prepare-Tests -testRunnerName "NUnit" `
									-publishedTestsDirectory $publishedNUnitTestsDirectory `
									-testResultsDirectory $NUnitTestResultsDirectory

	$outputParameter = "--result:" + $NUnitTestResultsDirectory + "\NUnit.xml"

	Exec {
		&$nunitExe $testAssemblies $outputParameter
	}
}

task TestXUnit `
	-depends Compile `
	-description "Run xUnit tests" `
	-precondition { return Test-Path $publishedxUnitTestsDirectory } `
{
	$testAssemblies = Prepare-Tests -testRunnerName "xUnit" `
									-publishedTestsDirectory $publishedxUnitTestsDirectory `
									-testResultsDirectory $xUnitTestResultsDirectory

	Exec {
		&$xunitExe $testAssemblies -nologo -noshadow -xml "$xUnitTestResultsDirectory\xUnit.xml"
	}
}

task TestMSTest `
	-depends Compile `
	-description "Run MSTest tests" `
	-precondition { return Test-Path $publishedMSTestTestsDirectory } `
{
	$testAssemblies = Prepare-Tests -testRunnerName "MSTest" `
									-publishedTestsDirectory $publishedMSTestTestsDirectory `
									-testResultsDirectory $MSTestTestResultsDirectory

	# vstest console doesn't have any option to change the output directory
	# so we need to change the working directory
	Push-Location $MSTestTestResultsDirectory
	Exec {
		&$vsTestExe $testAssemblies /Logger:trx 
	}
	Pop-Location

	# move the .trx file back to $MSTestTestResultsDirectory
	Move-Item -Path $MSTestTestResultsDirectory\TestResults\*.trx -Destination $MSTestTestResultsDirectory\MSTest.trx

	Remove-Item $MSTestTestResultsDirectory\TestResults
}

task Test -depends Compile, TestNUnit, TestXUnit, TestMSTest -description "Run unit tests" {
	Write-Host $testMessage
}