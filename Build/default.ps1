Include ".\helpers.ps1"

properties {
	$cleanMessage = 'Executed Clean!'

	$solutionDirectory = (Get-Item $solutionFile).DirectoryName
	$outputDirectory = "$solutionDirectory\.build"
	$temporaryOutputDirectory = "$outputDirectory\temp"

	$publishedNUnitTestsDirectory = "$temporaryOutputDirectory\_PublishedNUnitTests"
	$publishedMSTestTestsDirectory = "$temporaryOutputDirectory\_PublishedMSTestTests"
	$publishedXUnitTestsDirectory = "$temporaryOutputDirectory\_PublishedXUnitTests"
	$publishedApplicationsDirectory = "$temporaryOutputDirectory\_PublishedApplications"
	$publishedWebsitesDirectory = "$temporaryOutputDirectory\_PublishedWebsites"
	$publishedLibrariesDirectory = "$temporaryOutputDirectory\_PublishedLibraries"

	$testResultsDirectory = "$outputDirectory\TestResults"
	$NUnitTestResultsDirectory = "$testResultsDirectory\NUnit"
	$MSTestTestResultsDirectory = "$testResultsDirectory\MSTest"
	$xUnitTestResultsDirectory = "$testResultsDirectory\xUnit"

	$testCoverageDirectory = "$outputDirectory\TestCoverage"
	$testCoverageReportPath = "$testCoverageDirectory\OpenCover.xml"
	$testCoverageFilter = "+[*]* -[xunit.*]* -[*.NUnitTests]* -[*.Tests]* -[*.xUnitTests]*"
	$testCoverageExcludeByAttribute = "System.Diagnostics.CodeAnalysis.ExcludeFromcodeCoverageAttribute"
	$testCoverageExcludeByFile = "*\*Designer.cs;*\*.g.cs;*\*.g.i.cs"

	$packagesOutputDirectory = "$outputDirectory\Packages"
	$applicationsOutputDirectory = "$packagesOutputDirectory\Applications"
	$librariesOutputDirectory = "$packagesOutputDirectory\Libraries"

	$buildConfiguration = "Release"
	$buildPlatform = "Any CPU"

	$packagesPath = "$solutionDirectory\packages"
	$NUnitExe = (Find-PackagePath $packagesPath "NUnit.ConsoleRunner") + "\Tools\nunit3-console.exe"
	$xUnitExe = (Find-PackagePath $packagesPath "xUnit.Runner.Console") + "\Tools\xunit.console.exe"
	$vsTestExe = (Get-ChildItem ("C:\Program Files (x86)\Microsoft Visual Studio*\Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe")).FullName | Sort-Object $_ | select -Last 1
	$openCoverExe = (Find-PackagePath $packagesPath "OpenCover") + "\Tools\OpenCover.console.exe"
	$reportGeneratorExe = (Find-PackagePath $packagesPath "ReportGenerator") + "\Tools\ReportGenerator.exe"
	$7ZipExe = (Find-PackagePath $packagesPath "7-Zip.CommandLine") + "\Tools\7za.exe"
	$nugetExe = (Find-PackagePath $packagesPath "NuGet.CommandLine") + "\Tools\NuGet.exe"
}

FormatTaskName "`r`n`r`n-------- Executing {0} Task --------"

task default -depends Test

task Init `
	-description "Initializes the build by removing previous artifacts and creating output directories" `
	-requiredVariables outputDirectory, temporaryOutputDirectory `
{
	Assert ("Debug", "Release" -contains $buildConfiguration) `
			"Invalid build configuration '$buildConfiguration'. Valid values are 'Debug' or 'Release'"

	Assert ("x86", "x64", "Any CPU" -contains $buildPlatform) `
			"Invalid build platform '$buildPlatform'. Valid values are 'x86', 'x64' or 'Any CPU'"

	# Check that all tools are available
	Write-Host "Checking that all required tools are available"

	Assert (Test-Path $NUnitExe) "NUnit Console could not be found"
	Assert (Test-Path $xUnitExe) "xUnit Console could not be found"
	Assert (Test-Path $vsTestExe) "VSTest Console could not be found"
	Assert (Test-Path $openCoverExe) "OpenCover Console could not be found"
	Assert (Test-Path $reportGeneratorExe) "ReportGenerator Console could not be found"
	Assert (Test-Path $7ZipExe) "7-Zip Command Line could not be found"
	Assert (Test-Path $nugetExe) "NuGet Command Line could not be found"

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


task Compile `
	-depends Init `
	-description "Compile the code"  `
	-requiredVariables solutionFile, buildConfiguration, buildPlatform, temporaryOutputDirectory `
{
	Write-Host "Building solution $solutionFile"
	Exec {
		msbuild $solutionFile "/p:Configuration=$buildConfiguration;Platform=$buildPlatform;OutDir=$temporaryOutputDirectory;NuGetExePath=$nugetExe"
	}
}

task TestNUnit `
	-depends Compile `
	-description "Run NUnit tests" `
	-precondition { return Test-Path $publishedNUnitTestsDirectory } `
{
	$testAssemblies = Prepare-Tests -testRunnerName "NUnit" `
									-publishedTestsDirectory $publishedNUnitTestsDirectory `
									-testResultsDirectory $NUnitTestResultsDirectory `
									-testCoverageDirectory $testCoverageDirectory

	$targetArgs = "$testAssemblies --result:`"`"$NUnitTestResultsDirectory\NUnit.xml`"`""

	# Run OpenCover, which in turn will run NUnit
	Run-Tests -openCoverExe $openCoverExe `
			-targetExe $nunitExe `
			-targetArgs $targetArgs `
			-coveragePath $testCoverageReportPath `
			-filter $testCoverageFilter `
			-excludebyattribute:$testCoverageExcludeByAttribute `
			-excludeByfile:$testCoverageExcludeByFile
}

task TestXUnit `
	-depends Compile `
	-description "Run xUnit tests" `
	-precondition { return Test-Path $publishedxUnitTestsDirectory } `
{
	$testAssemblies = Prepare-Tests -testRunnerName "xUnit" `
									-publishedTestsDirectory $publishedxUnitTestsDirectory `
									-testResultsDirectory $xUnitTestResultsDirectory `
									-testCoverageDirectory $testCoverageDirectory

	$targetArgs = "$testAssemblies -nologo -noshadow -xml `"`"$xUnitTestResultsDirectory\xUnit.xml`"`""

	# Run OpenCover, which in turn will run NUnit
	Run-Tests -openCoverExe $openCoverExe `
			-targetExe $xUnitExe `
			-targetArgs $targetArgs `
			-coveragePath $testCoverageReportPath `
			-filter $testCoverageFilter `
			-excludebyattribute:$testCoverageExcludeByAttribute `
			-excludeByfile:$testCoverageExcludeByFile
}

task TestMSTest `
	-depends Compile `
	-description "Run MSTest tests" `
	-precondition { return Test-Path $publishedMSTestTestsDirectory } `
{
	$testAssemblies = Prepare-Tests -testRunnerName "MSTest" `
									-publishedTestsDirectory $publishedMSTestTestsDirectory `
									-testResultsDirectory $MSTestTestResultsDirectory `
									-testCoverageDirectory $testCoverageDirectory

	# vstest console doesn't have any option to change the output directory
	# so we need to change the working directory
	Push-Location $MSTestTestResultsDirectory

	$targetArgs = "$testAssemblies /Logger:trx"

	# Run OpenCover, which in turn will run NUnit
	Run-Tests -openCoverExe $openCoverExe `
			-targetExe $vsTestExe `
			-targetArgs $targetArgs `
			-coveragePath $testCoverageReportPath `
			-filter $testCoverageFilter `
			-excludebyattribute:$testCoverageExcludeByAttribute `
			-excludeByfile:$testCoverageExcludeByFile

	Pop-Location

	# move the .trx file back to $MSTestTestResultsDirectory
	Move-Item -Path $MSTestTestResultsDirectory\TestResults\*.trx -Destination $MSTestTestResultsDirectory\MSTest.trx

	Remove-Item $MSTestTestResultsDirectory\TestResults
}

task Test `
	-depends Compile, TestNUnit, TestXUnit, TestMSTest `
	-description "Run unit tests" `
{
	Write-Host "Running Test?"
	if (Test-Path $testCoverageReportPath)
	{
		# Generate HTML test coverage report
		Write-Host "`r`nGenerating HTML test coverage report"

		Exec {
			&$reportGeneratorExe $testCoverageReportPath $testCoverageDirectory
		}

		Write-Host "Parsing OpenCover results"

		# Load the coverage report as XML
		$coverage = [xml](Get-Content -Path $testCoverageReportPath)

		$coverageSummary = $coverage.CoverageSession.Summary

		# Write class coverage
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsCCovered' value='$($coverageSummary.visitedClasses)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsCTotal' value='$($coverageSummary.numClasses)']"
		Write-Host ("##teamcity[buildStatisticValue key='CodeCoverageC' value='{0:N2}']" -f (($coverageSummary.visitedClasses / $coverageSummary.numClasses)*100))

		# Write method coverage
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsMCovered' value='$($coverageSummary.visitedMethods)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsMTotal' value='$($coverageSummary.numMethods)']"
		Write-Host ("##teamcity[buildStatisticValue key='CodeCoverageM' value='{0:N2}']" -f (($coverageSummary.visitedMethods / $coverageSummary.numMethods)*100))

		# Write branch coverage
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsBCovered' value='$($coverageSummary.visitedBranchPoints)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsBTotal' value='$($coverageSummary.numBranchPoints)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageB' value='$($coverageSummary.branchCoverage)']"

		# Write statement coverage
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsSCovered' value='$($coverageSummary.visitedSequencePoints)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsSTotal' value='$($coverageSummary.numSequencePoints)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageS' value='$($coverageSummary.sequenceCoverage)']"
	}
	else 
	{
		Write-Host "No coverage file found at: $testCoverageReportPath"
	}
}

task Package `
	-depends Compile, Test `
	-description "Package Application" `
	-requiredVariables publishedWebsitesDirectory, publishedApplicationsDirectory, `
						applicationsOutputDirectory, publishedLibrariesDirectory, librariesOutputDirectory `
{
	# Merge published websites and published applications paths
	$applications = @(Get-ChildItem $publishedWebsitesDirectory) + @(Get-ChildItem $publishedApplicationsDirectory)

	if ($applications.Length -gt 0 -and !(Test-Path $applicationsOutputDirectory))
	{
		New-Item $applicationsOutputDirectory -ItemType Directory | Out-Null
	}

	foreach($application in $applications)
	{
		$nuspecPath = $application.FullName + "\" + $application.Name + ".nuspec"

		Write-Host "Looking for nuspec file at $nuspecPath"

		if (Test-Path $nuspecPath)
		{
			Write-Host "Packaging $($application.Name) as a NuGet package"

			# load the nuspec file as XML
			$nuspec = [xml](Get-Content -Path $nuspecPath)
			$metadata = $nuspec.package.metadata

			# Edit the metadata
			$metadata.version = $metadata.version.Replace("[buildNumber]", $buildNumber)

			if (! $isMainBranch)
			{
				$metadata.version = $metadata.version + "-$branchName"
			}

			$metadata.releaseNotes = "Build Number: $buildNumber`r`nBranch Name: $branchName`r`nCommit Hash: $gitCommitHash"

			# Save the nuspec file
			$nuspec.Save((Get-Item $nuspecPath))

			# package with nuget
			Exec {
				&$nugetExe pack $nuspecPath -OutputDirectory $applicationsOutputDirectory
			}
		}
		else
		{
			Write-Host "Packaging $($application.Name) as a zip file"

			$archivePath = "$($applicationsOutputDirectory)\$($application.Name).zip"
			$inputDirectory = "$($application.FullName)\*"

			Exec { 
				&$7ZipExe a -r -mx3 $archivePath $inputDirectory
			}
		}

		# Moving NuGet libraries to the packages directory
		if (Test-Path $publishedLibrariesDirectory)
		{
			if (!(Test-Path $librariesOutputDirectory))
			{
				mkdir $librariesOutputDirectory | Out-Null

				Get-ChildItem -Path $publishedLibrariesDirectory -Filter "*.nupkg" -Recurse | Move-Item -Destination $librariesOutputDirectory
			}
		}
	}
}

task Clean `
	-depends Compile, Test, Package `
	-description "Remove temporary files" `
	-requiredVariables temporaryOutputDirectory `
{
	if (Test-Path $temporaryOutputDirectory)
	{
		Write-Host "Removing temporary ouput directory located at $temporaryOutputDirectory"

		Remove-Item $temporaryOutputDirectory -Force -Recurse
	}
}