# EmuOrbit Mega Drive — fonte GPL

Este repositório contém somente a fonte correspondente do core de Mega Drive
usado pelo EmuOrbit Advance. Não inclui código Java/Kotlin, interface, recursos,
ROMs, BIOS, telemetria, anúncios ou qualquer outro componente do aplicativo.

## Conteúdo

- `core/blastem`: submódulo do [BlastEm libretro](https://github.com/libretro/blastem),
  fixado em `f1bc9321879d9c9e435b65de54f2a283560c400f`.
- `patches/0001-emuorbit-android-libretro.patch`: remove o fechamento duplicado
  de streams `.smd`, evitando uma falha no carregamento desses arquivos.
- `scripts/build-android-arm64.ps1`: script mínimo para gerar o core libretro
  Android para `arm64-v8a` sem alterar o checkout original.

O BlastEm é disponibilizado sob GPL-3.0-or-later. Os avisos e termos originais
estão em [`core/blastem/COPYING`](core/blastem/COPYING). Este repositório
preserva o commit exato e o patch aplicado durante a compilação.

## Clonar e compilar

```powershell
git clone --recurse-submodules https://github.com/MateusSouzaAlves/mega-drive.git
cd mega-drive
.\scripts\build-android-arm64.ps1
```

O script localiza o Android NDK pelo `ANDROID_NDK_HOME`, `ANDROID_NDK_ROOT` ou
pelo SDK padrão do Windows. Para usar outro NDK:

```powershell
.\scripts\build-android-arm64.ps1 -NdkRoot 'C:\caminho\para\ndk'
```

O resultado é gravado em `artifacts/android/arm64-v8a/libretro.so`. Ele é o
core libretro genérico; o renomeio privado da biblioteca e a ponte JNI pertencem
ao aplicativo e não fazem parte deste repositório de fonte GPL.

## Reprodutibilidade

O script verifica o commit do submódulo e aplica o patch com `git apply --check`
antes do build. Ele usa um worktree temporário, Android API 26 e LTO desativado,
reproduzindo a compilação do core sem alterar a fonte original. Os dois arquivos
C de configuração são gerados no worktree a partir de `rom.db` e `systems.cfg`
para contornar uma incompatibilidade do `sed` do Windows. Nenhum binário gerado
deve ser versionado aqui.


## Component source refresh — 2026-10-24

This tip updates the component sources/recipes identified in the source
snapshot manifest. Older tags/commits remain historical snapshots. It does
not assert that this entire current snapshot was the source of an earlier
Play release, and does not certify the closed combined app or publish its
remaining private host. References above to older artifact hashes or private
application tags retain historical scope; they are not publicly available
host-source substitutes. See SOURCE_REFRESH.md and releases/component-source-2026-10-24/manifest.json.
