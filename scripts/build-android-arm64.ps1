[CmdletBinding()]
param(
    [ValidateSet('arm64-v8a')]
    [string] $Abi = 'arm64-v8a',
    [string] $NdkRoot,
    [string] $OutputDirectory
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$coreRoot = Join-Path $repositoryRoot 'core\blastem'
$patch = Join-Path $repositoryRoot 'patches\0001-emuorbit-android-libretro.patch'
$expectedCommit = 'f1bc9321879d9c9e435b65de54f2a283560c400f'

if (-not (Test-Path -LiteralPath (Join-Path $coreRoot '.git'))) {
    throw 'O submódulo core/blastem não foi inicializado. Execute git submodule update --init --recursive.'
}

$actualCommit = (& git -C $coreRoot rev-parse HEAD).Trim()
if ($actualCommit -ne $expectedCommit) {
    throw "O core não está no commit esperado: $expectedCommit. Encontrado: $actualCommit."
}

if ([string]::IsNullOrWhiteSpace($NdkRoot)) {
    $NdkRoot = if ($env:ANDROID_NDK_HOME) {
        $env:ANDROID_NDK_HOME
    } elseif ($env:ANDROID_NDK_ROOT) {
        $env:ANDROID_NDK_ROOT
    } else {
        $sdkRoot = if ($env:ANDROID_SDK_ROOT) {
            $env:ANDROID_SDK_ROOT
        } elseif ($env:ANDROID_HOME) {
            $env:ANDROID_HOME
        } else {
            Join-Path $env:LOCALAPPDATA 'Android\Sdk'
        }
        Get-ChildItem -LiteralPath (Join-Path $sdkRoot 'ndk') -Directory |
            Sort-Object Name -Descending |
            Select-Object -First 1 |
            ForEach-Object FullName
    }
}

if ([string]::IsNullOrWhiteSpace($NdkRoot) -or -not (Test-Path -LiteralPath $NdkRoot)) {
    throw 'Android NDK não encontrado. Informe -NdkRoot com o diretório do NDK.'
}

$make = Join-Path $NdkRoot 'prebuilt\windows-x86_64\bin\make.exe'
$ndkLlvm = (Join-Path $NdkRoot 'toolchains\llvm\prebuilt\windows-x86_64').Replace('\', '/')
if (-not (Test-Path -LiteralPath $make)) {
    throw "make.exe não encontrado no Android NDK: $make"
}

$programFiles = if ([string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
    'C:\Program Files'
} else {
    $env:ProgramFiles
}
$gitUnixBin = Join-Path $programFiles 'Git\usr\bin'
if (-not (Test-Path -LiteralPath $gitUnixBin)) {
    throw "Utilitários GNU do Git não encontrados: $gitUnixBin"
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repositoryRoot "artifacts\android\$Abi"
}

function Write-EmbeddedTextSource {
    param(
        [Parameter(Mandatory)] [string] $InputFile,
        [Parameter(Mandatory)] [string] $OutputFile,
        [Parameter(Mandatory)] [string] $VariableName
    )

    $literals = Get-Content -LiteralPath $InputFile | ForEach-Object {
        '"' + $_.Replace('\', '\\').Replace('"', '\"') + '\n"'
    }
    $content = "const char $VariableName[] = " + ($literals -join "`n") + ";`n"
    [System.IO.File]::WriteAllText(
        $OutputFile,
        $content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

$worktree = Join-Path ([System.IO.Path]::GetTempPath()) "mega-drive-glp-blastem-$PID"
try {
    & git -C $coreRoot worktree add --detach $worktree $expectedCommit
    if ($LASTEXITCODE -ne 0) {
        throw 'Não foi possível criar o worktree temporário do core.'
    }

    & git -C $worktree apply --check $patch
    if ($LASTEXITCODE -ne 0) {
        throw 'O patch Android não corresponde ao commit fixado do core.'
    }
    & git -C $worktree apply $patch
    if ($LASTEXITCODE -ne 0) {
        throw 'Não foi possível aplicar o patch Android do core.'
    }

    Write-EmbeddedTextSource (Join-Path $worktree 'rom.db') (Join-Path $worktree 'rom.db.c') 'rom_db_data'
    Write-EmbeddedTextSource (Join-Path $worktree 'systems.cfg') (Join-Path $worktree 'systems.cfg.c') 'systems_cfg_data'

    $previousPath = $env:PATH
    $previousShell = $env:SHELL
    try {
        $env:PATH = $gitUnixBin + [System.IO.Path]::PathSeparator + $previousPath
        $env:SHELL = Join-Path $gitUnixBin 'sh.exe'
        & $make -C $worktree -f Makefile.libretro "platform=android-arm64" "NDK_LLVM=$ndkLlvm" `
            'ANDROID_API=26' 'PYTHON=python' 'NOLTO=1' '-j4'
        if ($LASTEXITCODE -ne 0) {
            throw 'A compilação Android do core falhou.'
        }
    } finally {
        $env:PATH = $previousPath
        $env:SHELL = $previousShell
    }

    $library = Join-Path $worktree 'blastem_libretro_android.so'
    if (-not (Test-Path -LiteralPath $library)) {
        throw "O core compilado não foi encontrado: $library"
    }
    New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
    Copy-Item -LiteralPath $library -Destination (Join-Path $OutputDirectory 'libretro.so') -Force
    Get-FileHash -Algorithm SHA256 (Join-Path $OutputDirectory 'libretro.so')
} finally {
    if (Test-Path -LiteralPath $worktree) {
        & git -C $coreRoot worktree remove --force $worktree
    }
}
