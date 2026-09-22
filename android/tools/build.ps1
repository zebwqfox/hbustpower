param([switch]$IsolatedVerification)
$ErrorActionPreference = 'Stop'
$projectDir = Split-Path $PSScriptRoot -Parent
$previousJavaHome = $env:JAVA_HOME
$previousJavaOptions = $env:JAVA_TOOL_OPTIONS
try {
    if (-not $env:JAVA_HOME -or -not (Test-Path (Join-Path $env:JAVA_HOME 'bin/java.exe'))) {
        $properties = & java -XshowSettings:properties -version 2>&1 | Out-String
        $javaMatch = [regex]::Match($properties, 'java.home\s*=\s*([^\r\n]+)')
        if (-not $javaMatch.Success) { throw '请安装 JDK 并设置有效的 JAVA_HOME。' }
        $env:JAVA_HOME = $javaMatch.Groups[1].Value.Trim()
    }
    # A short ASCII socket directory avoids Windows JDK loopback path failures.
    $socketDir = Join-Path $env:SystemDrive 'Temp/hbust-java'
    New-Item -ItemType Directory -Force $socketDir | Out-Null
    $env:JAVA_TOOL_OPTIONS = "$previousJavaOptions -Djdk.net.unixdomain.tmpdir=$socketDir".Trim()
    $buildArgs = @('-p', $projectDir, 'testDebugUnitTest', 'assembleDebug', 'lintDebug')
    if ($IsolatedVerification) { $buildArgs += '-PisolatedVerification' }
    & (Join-Path $projectDir 'gradlew.bat') @buildArgs
    if ($LASTEXITCODE -ne 0) { throw "构建失败，退出码 $LASTEXITCODE" }
} finally {
    $env:JAVA_HOME = $previousJavaHome
    $env:JAVA_TOOL_OPTIONS = $previousJavaOptions
}
