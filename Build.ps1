echo "build: Build started"

$env:Path = "$pwd/.dotnetcli;$env:Path"

Push-Location $PSScriptRoot

if(Test-Path .\artifacts) {
	echo "build: Cleaning .\artifacts"
	Remove-Item .\artifacts -Force -Recurse
}

& dotnet restore --no-cache

$branch = @{ $true = $env:APPVEYOR_REPO_BRANCH; $false = $(git symbolic-ref --short -q HEAD) }[$env:APPVEYOR_REPO_BRANCH -ne $NULL];
$revision = @{ $true = "{0:00000}" -f [convert]::ToInt32("0" + $env:APPVEYOR_BUILD_NUMBER, 10); $false = "local" }[$env:APPVEYOR_BUILD_NUMBER -ne $NULL];
$suffix = @{ $true = ""; $false = "$($branch.Substring(0, [math]::Min(10,$branch.Length)))-$revision"}[$branch -eq "main" -and $revision -ne "local"]

echo "build: Version suffix is $suffix"

foreach ($src in ls src/*) {
    Push-Location $src

	echo "build: Packaging project in $src"

    if($suffix) {
        & dotnet pack -c Release --include-source -o ..\..\artifacts --version-suffix=$suffix
    } else {
        & dotnet pack -c Release --include-source -o ..\..\artifacts
    }

    if($LASTEXITCODE -ne 0) { throw "build failed" }

    Pop-Location
}

foreach ($test in ls test/*.PerformanceTests) {
    Push-Location $test

	echo "build: Building performance test project in $test"

    & dotnet build -c Release
    if($LASTEXITCODE -ne 0) { throw "test failed" }

    Pop-Location
}

foreach ($test in ls test/*.Tests) {
    Push-Location $test

	echo "build: Testing project in $test"

    & dotnet test -c Release
    if($LASTEXITCODE -ne 0) { throw "test failed" }

    Pop-Location
}

Pop-Location
