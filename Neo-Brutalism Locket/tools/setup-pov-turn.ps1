param([string]$ProjectRef)

$ErrorActionPreference = 'Stop'
$povRoot = Split-Path -Parent $PSScriptRoot
if (-not $ProjectRef) {
    $povLinkedRef = Join-Path $povRoot 'supabase/.temp/project-ref'
    if (Test-Path -LiteralPath $povLinkedRef) {
        $ProjectRef = (Get-Content -LiteralPath $povLinkedRef -Raw).Trim()
    } else {
        $ProjectRef = Read-Host 'Supabase project ref'
    }
}
if ($ProjectRef -notmatch '^[a-z0-9]{20}$') {
    throw 'Invalid Supabase project ref.'
}

$povApp = (Read-Host 'Metered app name (the part before .metered.live)').Trim()
if ($povApp -notmatch '^[a-zA-Z0-9-]+$') {
    throw 'Enter only the Metered app name, without https:// or .metered.live.'
}
$povSecureKey = Read-Host 'Metered TURN secret API key (hidden)' -AsSecureString
$povKeyPointer = [IntPtr]::Zero
$povSecretFile = Join-Path ([IO.Path]::GetTempPath()) ('pov-turn-' + [guid]::NewGuid() + '.env')
try {
    $povKeyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($povSecureKey)
    $povKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($povKeyPointer)
    if ([string]::IsNullOrWhiteSpace($povKey) -or $povKey -match '[\r\n]') {
        throw 'A single-line Metered secret API key is required.'
    }
    # Keep the secret out of command arguments, terminal output and the repository.
    $povEscapedKey = $povKey.Replace('\', '\\').Replace('"', '\"')
    $povEnv = "METERED_APP=$povApp`nMETERED_SECRET_KEY=`"$povEscapedKey`"`n"
    [IO.File]::WriteAllText($povSecretFile, $povEnv, (New-Object Text.UTF8Encoding($false)))
    Push-Location -LiteralPath $povRoot
    try {
        & npx.cmd --yes supabase secrets set --project-ref $ProjectRef --env-file $povSecretFile
        if ($LASTEXITCODE -ne 0) { throw 'Could not save TURN configuration to Supabase.' }
        & npx.cmd --yes supabase functions deploy pov-ice --project-ref $ProjectRef
        if ($LASTEXITCODE -ne 0) { throw 'Could not deploy pov-ice.' }
    } finally {
        Pop-Location
    }
    Write-Host 'TURN configured. End the current POV session and scan a new QR code on both phones.'
} finally {
    if ($povKeyPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($povKeyPointer)
    }
    if (Test-Path -LiteralPath $povSecretFile) {
        Remove-Item -LiteralPath $povSecretFile -Force
    }
    $povKey = $null
    $povEnv = $null
    $povEscapedKey = $null
    $povSecureKey.Dispose()
}
