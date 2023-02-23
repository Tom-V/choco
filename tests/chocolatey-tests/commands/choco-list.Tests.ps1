﻿<#
    .Synopsis
        Tests for `choco list` and aliases

    .Link
        https://github.com/chocolatey/choco/blob/master/src/chocolatey.tests.integration/scenarios/ListScenarios.cs
#>
param(
    # Which command to test (used for testing aliases instead of the base command, 'list')
    [string[]]$Command = @(
        "list"
        "find"
        "search"
    )
)

Import-Module helpers/common-helpers

Describe "choco <_>" -ForEach $Command -Tag Chocolatey, ListCommand, SearchCommand, FindCommand {
    BeforeDiscovery {
        $licensedProxyFixed = Test-PackageIsEqualOrHigher 'chocolatey.extension' 2.2.0-beta -AllowMissingPackage
    }

    BeforeAll {
        Remove-NuGetPaths
        Initialize-ChocolateyTestInstall -Source $PSScriptRoot\testpackages
        Invoke-Choco install installpackage --version 1.0.0 --confirm
        Invoke-Choco install upgradepackage --version 1.0.0 --confirm
        $VersionRegex = "[^v]\d+\.\d+\.\d+"
        # Ensure that we remove any compatibility package before running the tests
        $null = Invoke-Choco uninstall chocolatey-compatibility.extension -y --force
        $currentCommand = $_
    }

    AfterAll {
        Remove-ChocolateyTestInstall
    }

    Context "Searching packages with no filter (Happy Path)" {
        BeforeAll {
            $Output = Invoke-Choco $_
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Lists available packages once" {
            # Possible that I need to add a second source to make this valid
            $Output.String | Should -Match "upgradepackage"
        }

        It "Contains packages and versions with a space between them" {
            $Output.Lines | Should -Contain "upgradepackage 1.1.0"
        }

        It "Should not contain pipe-delimited values" {
            $Output.Lines | Should -Not -Contain "upgradepackage|1.1.0"
        }

        It "Should contain a summary" {
            $Output.String | Should -Match "\d+ packages found"
        }
    }

    Context "Searching for a particular package" {
        BeforeAll {
            $Output = Invoke-Choco $_ upgradepackage
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Contains packages and versions with a space between them" {
            $Output.Lines | Should -Contain "upgradepackage 1.1.0"
        }

        It "Does not contain available packages that do not match" {
            $Output.Lines | Should -Not -Contain "installpackage 1.0.0"
        }

        It "Should contain a summary" {
            $Output.Lines | Should -Contain "1 packages found."
        }
    }

    Context "Searching all available packages" {
        BeforeAll {
            $Output = Invoke-Choco $_ --AllVersions
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Shows each instance of an available package" {
            ($Output.Lines -like "upgradepackage*").Count | Should -Be 2
        }

        It "Contains packages and versions with a space between them" {
            $Output.Lines | Should -Contain "upgradepackage 1.0.0"
        }

        It "Should not contain pipe-delimited packages and versions" {
            $Output.Lines | Should -Not -Contain "upgradepackage|1.0.0"
        }

        It "Should contain a summary" {
            $Output.String | Should -Match "\d+ packages found"
        }
    }

    # TODO: Using All versions and pre release together is currently broken
    # in vNext of Chocolatey CLI.
    Context "Searching all available packages (allowing prerelease)" -Tag Broken {
        BeforeAll {
            $Output = Invoke-Choco $_ --AllVersions --PreRelease
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Shows each instance of an available package" {
            # Due to a bug (https://github.com/chocolatey/choco/issues/2763) Sometimes all upgradepackage packages aren't returned
            # This works around that issue by testing that we got up to 4 results, and tests that a query for the package directly does return all 4
            ($Output.Lines -like "upgradepackage*").Count | Should -BeLessOrEqual 4
            ((Invoke-Choco $_ upgradepackage --AllVersions --PreRelease).Lines -like "upgradepackage*").Count | Should -Be 4
        }

        It "Contains packages and versions with a space between them" {
            ($Output.Lines -like "upgradepackage *").Count | Should -BeLessOrEqual 4
        }

        It "Should not contain pipe-delimited packages and versions" {
            ($Output.Lines -like "upgradepackage|*").Count | Should -Be 0
        }

        It "Should contain a summary" {
            $Output.String | Should -Match "\d+ packages found"
        }
    }

    # Issue: https://github.com/chocolatey/choco/issues/1843
    Context "Searching exact package with displaying all versions" -Skip:(-Not (Test-ChocolateyVersionEqualOrHigherThan "0.10.16-beta-233")) {
        BeforeAll {
            $Output = Invoke-Choco $_ upgradepackage --AllVersions --exact
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Shows version <_> of the package" -ForEach @("1.1.0"; "1.0.0") {
            $Output.Lines | Should -Contain "upgradepackage $_"
        }
    }

    Context "Searching packages with Verbose" {
        BeforeAll {
            $Output = Invoke-Choco $_ --Verbose
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Should contain packages and version with a space between them" {
            $Output.Lines | Should -Contain "upgradepackage 1.1.0"
        }

        It "Should contain a description" {
            $Output.String | Should -Match "Description:"
        }

        It "Should contain a download count" {
            $Output.String | Should -Match "Number of Downloads:"
        }

        It "Should not contain pipe-delimited packages and versions" {
            $Output.Lines | Should -Not -Contain "upgradepackage|1.1.0"
        }

        It "Should contain a summary" {
            $Output.String | Should -Match "\d+ packages found."
        }
    }

    Context "Listing local packages" {
        BeforeAll {
            $Output = Invoke-Choco $_ --LocalOnly
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Should contain packages and version with a space between them" {
            $Output.Lines | Should -Contain "upgradepackage 1.0.0"
        }

        It "Should not contain pipe-delimited packages and versions" {
            $Output.Lines | Should -Not -Contain "upgradepackage|1.0.0"
        }

        It "Should contain a summary" {
            $Output.String | Should -Match "\d+ packages installed"
        }
    }

    Context "Listing local packages (limiting output)" {
        BeforeAll {
            $Output = Invoke-Choco $_ --LocalOnly --LimitOutput
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Should not contain packages and version with a space between them" {
            $Output.Lines | Should -Not -Contain "upgradepackage 1.0.0"
        }

        It "Should contain pipe-delimited packages and versions" {
            $Output.Lines | Should -Contain "upgradepackage|1.0.0"
        }

        It "Should not contain a summary" {
            $Output.String | Should -Not -Match "\d+ packages installed"
        }
    }

    Context "Listing local packages (limiting output, ID only)" {
        BeforeAll {
            $Output = Invoke-Choco $_ --LocalOnly --IdOnly
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Should contain package name(s)" {
            $Output.Lines | Should -Contain "upgradepackage"
        }

        It "Should not contain any version numbers" {
            $Output.String | Should -Not -Match $VersionRegex
        }
    }

    Context "Listing packages with no sources enabled" {
        BeforeAll {
            Disable-ChocolateySource -All

            $Output = Invoke-Choco $_ --LimitOutput
        }

        AfterAll {
            $null = Invoke-Choco source enable --Name TestSource
            $null = Invoke-Choco source enable --Name hermes
        }

        It "Exits with Failure (1)" {
            $Output.ExitCode | Should -Be 1
        }

        It "Outputs an appropriate message to indicate the failure to search no sources, and nothing else" {
            $Output.String | Should -MatchExactly "^Unable to search for packages when there are no sources enabled for[\r\n]* packages and none were passed as arguments.$"
        }
    }

    Context "Searching for an exact package" {
        BeforeAll {
            $Output = Invoke-Choco $_ exactpackage --Exact
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Should contain packages and version with a space between them" {
            $Output.Lines | Should -Contain "exactpackage 1.0.0"
        }

        It "Should not contain packages that don't exactly match" {
            $Output.String | Should -Not -Match "exactpackage\.dontfind"
        }

        It "Should contain a summary" {
            $Output.Lines | Should -Contain "1 packages found."
        }
    }

    Context "Searching for an exact package with zero results" {
        BeforeAll {
            $Output = Invoke-Choco $_ exactpackage123 --Exact
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0  # This is fine?
        }

        It "Should not have any results" {
            $Output.String | Should -Not -Match $VersionRegex
        }

        It "Should not contain packages that don't exactly match" {
            $Output.String | Should -Not -Match "exactpackage\.dontfind"
        }

        It "Should contain a summary" {
            $Output.Lines | Should -Contain "0 packages found."
        }
    }

    # Issue: https://gitlab.com/chocolatey/collaborators/choco-licensed/-/issues/530 (NOTE: Proxy bypassing also works on Chocolatey FOSS)
    Context "Listing packages on source using proxy and proxy bypass list" -Skip:(!$licensedProxyFixed) {
        BeforeAll {
            Restore-ChocolateyInstallSnapshot
            $null = Invoke-Choco config set --name=proxy --value="https://invalid.chocolatey.org/"
            $null = Invoke-Choco config set --name=proxyBypassList --value="hermes.chocolatey.org"

            $Output = Invoke-Choco $_ mvc
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Displays the package <_>" -ForEach @("mvcmusicstore-db 1.2.0"; "mvcmusicstore-web 1.2.0") {
            $Output.Lines | Should -Contain $_
        }

        It "Displays amount of packages found" {
            $Output.Lines | Should -Contain "2 packages found."
        }
    }

    # Issue: https://gitlab.com/chocolatey/collaborators/choco-licensed/-/issues/530 (NOTE: Proxy bypassing also works on Chocolatey FOSS)
    Context "Listing packages on source using proxy and proxy bypass list on command" -Skip:(!$licensedProxyFixed) {
        BeforeAll {
            Restore-ChocolateyInstallSnapshot
            $null = Invoke-Choco config set --name=proxy --value="https://invalid.chocolatey.org/"

            $Output = Invoke-Choco $_ mvc "--proxy-bypass-list=hermes.chocolatey.org"
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Displays the package <_>" -ForEach @("mvcmusicstore-db 1.2.0"; "mvcmusicstore-web 1.2.0") {
            $Output.Lines | Should -Contain $_
        }

        It "Displays amount of packages found" {
            $Output.Lines | Should -Contain "2 packages found."
        }
    }

    # Issue: https://github.com/chocolatey/choco/issues/2304
    Context "Listing packages with exact and all version displayed without pre-release argument" -Skip:(-Not (Test-ChocolateyVersionEqualOrHigherThan "0.10.16-beta-233")) {
        BeforeAll {
            Restore-ChocolateyInstallSnapshot

            $Output = Invoke-Choco $_ --exact --all-versions isexactversiondependency
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Should list package isexactversiondependency v<_>" -ForEach @("1.0.1"; "1.0.0"; "2.0.0"; "1.1.0") {
            $Output.Lines | Should -Contain "isexactversiondependency $_"
        }

        It "Should not list package isexactversiondependency v<_>" -ForEach @("1.0.0-beta") {
            $Output.Lines | Should -Not -Contain "isexactversiondependency $_"
        }
    }

    Context "Listing packages with exact, all versions and pre-release arguments" -Skip:(-Not (Test-ChocolateyVersionEqualOrHigherThan "0.10.16-beta-233")) {
        BeforeAll {
            Restore-ChocolateyInstallSnapshot

            $Output = Invoke-Choco $_ --exact --all-versions --prerelease isexactversiondependency
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0
        }

        It "Should list package isexactversiondependency v<_>" -ForEach @("1.0.1"; "1.0.0"; "2.0.0"; "1.1.0"; "1.0.0-beta") {
            $Output.Lines | Should -Contain "isexactversiondependency $_"
        }
    }

    Context "WebPI source should show a deprecation message" {
        BeforeAll {
            Restore-ChocolateyInstallSnapshot

            $Output = Invoke-Choco $_ --source=webpi
        }

        It "Should show the deprecation warning" {
            $Output.Lines | Should -Contain 'The `webpi` source is deprecated and will be removed in Chocolatey v2.0.0.' -Because $Output.String
        }
    }

    Context "Searching for older stable version" {
        BeforeAll {
            Restore-ChocolateyInstallSnapshot -Quick

            $Output = Invoke-Choco $_ upgradepackage --version 1.0.0
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0 -Because $Output.String
        }

        It "Should output the package found" {
            $Output.Lines | Should -Contain "upgradepackage 1.0.0" -Because $Output.String
        }

        It "Should output the amount of packages found" {
            $Output.Lines | Should -Contain "1 packages found." -Because $Output.String
        }
    }

    Context "Searching for older pre-release version" {
        BeforeAll {
            Restore-ChocolateyInstallSnapshot -Quick

            $Output = Invoke-Choco $_ upgradepackage --version 1.1.1-beta --pre
        }

        It "Exits with Sucess (0)" {
            $Output.ExitCode | Should -Be 0 -Because $Output.String
        }

        It "Should output the package found" {
            $Output.Lines | Should -Contain "upgradepackage 1.1.1-beta" -Because $Output.String
        }

        It "Should output the amount of packages found" {
            $Output.Lines | Should -Contain "1 packages found." -Because $Output.String
        }
    }

    Context "Searching for pre-release package without using --pre as an argument" {
        BeforeAll {
            Restore-ChocolateyInstallSnapshot -Quick

            $Output = Invoke-Choco $_ upgradepackage --version 1.1.1-beta
        }

        It "Exits with Sucess (0)" {
            $Output.ExitCode | Should -Be 0 -Because $Output.String
        }

        It "Should not output the package found" {
            $Output.Lines | Should -Not -Contain "upgradepackage 1.1.1-beta" -Because $Output.String
        }

        It "Should output the amount of packages found" {
            $Output.Lines | Should -Contain "0 packages found." -Because $Output.String
        }
    }

    # This test is non-functional in v1, as it can not actually find any of the packages.
    # It seems to exit out of the results too early to find them.
    Context "Search for chocolatey on Page <Page>" -Skip -ForEach @(
        @{
            Page = 0
            Name = 'chocolatey'
            NotExpected = 'chocolatey-agent'
        }
        @{
            Page = 1
            Name = 'chocolatey-agent'
            NotExpected = 'chocolatey'
        }
    ) {
        BeforeAll {
            Restore-ChocolateyInstallSnapshot -Quick

            $Output = Invoke-Choco $currentCommand chocolatey --version 0.11.2 --page $Page --page-size 1
        }

        It "Exits with Success (0)" {
            $Output.ExitCode | Should -Be 0 -Because $Output.String
        }

        It "Should output package <Name> in the results" {
            $Output.Lines | Should -Contain "$Name 0.11.2" -Because $Output.String
        }

        It "Should not output unexpected package <Name> in the results" {
            $Output.Lines | Should -Not -Contain "$NotExpected 0.11.2" -Because $Output.String
        }

        It "Should output the amount of packages found" {
            $Output.Lines | Should -Contain "1 packages found." -Because $Output.String
        }
    }

    # This needs to be the last test in this block, to ensure NuGet configurations aren't being created.
    Test-NuGetPaths
}
