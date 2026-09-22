<#
.SYNOPSIS
    输出移动应用备案需要的签名信息：应用公钥、证书 MD5 / SHA-1 / SHA-256 指纹。

.DESCRIPTION
    备案平台（工信部 / 各云服务商）要求填写"应用公钥"和"应用签名"。两者都来自签名证书本身，
    与上架的 APK 必须一致。本脚本只读取证书，不会修改密钥库，也不会把口令写进文件。

    两种用法：
      1) 从签名后的 APK 读取（推荐，取的就是实际发布包里的证书）
      2) 从密钥库读取（需要输入密钥库口令）

.EXAMPLE
    .\tools\Get-FilingSignature.ps1 -Apk .\app\build\outputs\apk\release\app-release.apk

.EXAMPLE
    .\tools\Get-FilingSignature.ps1 -Keystore ..\hbustpower-release.jks -Alias hbustpower
#>
[CmdletBinding(DefaultParameterSetName = 'Apk')]
param(
    [Parameter(ParameterSetName = 'Apk', Mandatory = $true)]
    [string]$Apk,

    [Parameter(ParameterSetName = 'Keystore', Mandatory = $true)]
    [string]$Keystore,

    [Parameter(ParameterSetName = 'Keystore', Mandatory = $true)]
    [string]$Alias,

    [string]$OutFile = "$PSScriptRoot\..\..\filing\签名信息.txt"
)

$ErrorActionPreference = 'Stop'

function Find-Tool([string]$name, [string[]]$candidates) {
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }
    $onPath = Get-Command $name -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    throw "找不到 $name，请确认已安装 JDK / Android SDK Build-Tools。"
}

$javaHome = if ($env:JAVA_HOME) { $env:JAVA_HOME } else { '' }
$keytool = Find-Tool 'keytool' @("$javaHome\bin\keytool.exe", 'C:\Program Files\Java\jdk-26.0.2.1\bin\keytool.exe')

$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { '' }
$temporaryPem = [System.IO.Path]::GetTempFileName()

function Get-Fingerprint([string]$algorithm, [byte[]]$bytes) {
    $hash = [System.Security.Cryptography.HashAlgorithm]::Create($algorithm).ComputeHash($bytes)
    ($hash | ForEach-Object { $_.ToString('X2') }) -join ':'
}

try {
    if ($PSCmdlet.ParameterSetName -eq 'Apk') {
        if (-not (Test-Path $Apk)) { throw "APK 不存在：$Apk" }
        $buildTools = @()
        if ($sdk) {
            $buildTools = Get-ChildItem "$sdk\build-tools" -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending | ForEach-Object { "$($_.FullName)\apksigner.bat" }
        }
        $apksigner = Find-Tool 'apksigner' $buildTools
        Write-Host "读取 APK 证书：$Apk" -ForegroundColor Cyan
        $report = & $apksigner verify --print-certs $Apk 2>$null
        if ($LASTEXITCODE -ne 0) { throw "apksigner 校验失败，APK 可能未签名。" }
        # apksigner 打印的是十六进制摘要；证书本体另取一份用于计算公钥。
        $fingerprints = $report | Select-String -Pattern 'digest:' | ForEach-Object { $_.Line.Trim() }
        $certificateBytes = & {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $archive = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $Apk))
            try {
                $entry = $archive.Entries | Where-Object { $_.FullName -match '^META-INF/.*\.(RSA|EC|DSA)$' } | Select-Object -First 1
                if (-not $entry) { return $null }
                $stream = $entry.Open()
                $buffer = New-Object System.IO.MemoryStream
                $stream.CopyTo($buffer)
                $stream.Dispose()
                $buffer.ToArray()
            } finally { $archive.Dispose() }
        }
        if ($certificateBytes) {
            Add-Type -AssemblyName System.Security
            $signed = New-Object System.Security.Cryptography.Pkcs.SignedCms
            $signed.Decode($certificateBytes)
            $certificate = $signed.Certificates[0]
        } else {
            throw "APK 只有 v2/v3 签名块，无法在此读取证书；请改用 -Keystore 方式。"
        }
    } else {
        if (-not (Test-Path $Keystore)) { throw "密钥库不存在：$Keystore" }
        Write-Host "读取密钥库：$Keystore（别名 $Alias）" -ForegroundColor Cyan
        Write-Host "keytool 会提示输入密钥库口令，口令只在 keytool 内部使用，不会写入任何文件。" -ForegroundColor Yellow
        & $keytool -exportcert -rfc -keystore $Keystore -alias $Alias -file $temporaryPem
        if ($LASTEXITCODE -ne 0) { throw "导出证书失败。" }
        $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new((Resolve-Path $temporaryPem))
        $fingerprints = @()
    }

    $raw = $certificate.RawData
    $publicKeyDer = $certificate.PublicKey.EncodedKeyValue.RawData
    $publicKeyBase64 = [Convert]::ToBase64String($publicKeyDer)
    $publicKeyHex = ($publicKeyDer | ForEach-Object { $_.ToString('X2') }) -join ''
    $md5 = Get-Fingerprint 'MD5' $raw
    $sha1 = Get-Fingerprint 'SHA1' $raw
    $sha256 = Get-Fingerprint 'SHA256' $raw
    $md5Plain = ($md5 -replace ':', '').ToLower()
    $sha256Plain = ($sha256 -replace ':', '').ToLower()

    $lines = @(
        "移动应用备案 · 签名信息"
        "生成时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        "来源：" + $(if ($PSCmdlet.ParameterSetName -eq 'Apk') { (Resolve-Path $Apk).Path } else { (Resolve-Path $Keystore).Path + "（别名 $Alias）" })
        ""
        "证书主题：$($certificate.Subject)"
        "证书颁发者：$($certificate.Issuer)"
        "序列号：$($certificate.SerialNumber)"
        "有效期：$($certificate.NotBefore.ToString('yyyy-MM-dd')) 至 $($certificate.NotAfter.ToString('yyyy-MM-dd'))"
        "签名算法：$($certificate.SignatureAlgorithm.FriendlyName)"
        "公钥算法：$($certificate.PublicKey.Oid.FriendlyName) $($certificate.PublicKey.Key.KeySize) 位"
        ""
        "== 应用签名（证书指纹）=="
        "MD5      ：$md5"
        "SHA-1    ：$sha1"
        "SHA-256  ：$sha256"
        "（部分平台要求去掉冒号的小写形式）"
        "MD5      ：$md5Plain"
        "SHA-256  ：$sha256Plain"
        ""
        "== 应用公钥 =="
        "Base64：$publicKeyBase64"
        ""
        "HEX：$publicKeyHex"
        ""
        "若平台明确要求 SubjectPublicKeyInfo 格式，可用下面的 PEM 证书执行："
        "  openssl x509 -in cert.pem -pubkey -noout"
        ""
        "== 证书 PEM（如平台要求上传证书文件）=="
        "-----BEGIN CERTIFICATE-----"
        ([Convert]::ToBase64String($raw) -split '(.{64})' | Where-Object { $_ })
        "-----END CERTIFICATE-----"
    )
    if ($fingerprints) { $lines += @("", "== apksigner 原始输出 ==") + $fingerprints }

    $directory = Split-Path $OutFile -Parent
    if (-not (Test-Path $directory)) { New-Item -ItemType Directory -Force $directory | Out-Null }
    $lines | Set-Content -Encoding utf8 $OutFile
    $lines | Write-Host
    Write-Host ""
    Write-Host "已写入：$((Resolve-Path $OutFile).Path)" -ForegroundColor Green
    Write-Host "该文件含公钥和指纹（可公开），但不含私钥或口令。" -ForegroundColor Green
} finally {
    Remove-Item $temporaryPem -ErrorAction SilentlyContinue
}
