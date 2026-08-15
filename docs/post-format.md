# Después de formatear

Esta es la intervención humana mínima para entregarle la restauración a Claude Code. No hace
falta un USB si Windows se reinstaló correctamente mediante **Restablecer este PC**.

## 1. Terminar Windows

1. Completá la configuración inicial de Windows 11 Pro.
2. Ejecutá Windows Update e instalá los drivers.
3. Reiniciá hasta que Windows Update no pida más reinicios.

## 2. Instalar lo mínimo

Abrí **Windows PowerShell** y ejecutá:

```powershell
winget install --id Git.Git --exact
winget install --id GitHub.cli --exact
winget install --id Microsoft.PowerShell --exact
irm https://claude.ai/install.ps1 | iex
```

Claude Code se instala para tu usuario en:

```text
%USERPROFILE%\.local\bin\claude.exe
```

No hay que elegir una carpeta ni instalarlo dentro de `C:\Briar` o del repositorio.

Si `winget` no aparece, actualizá **App Installer** desde Microsoft Store, cerrá la terminal
y volvé a abrirla.

## 3. Autenticar

Cerrá Windows PowerShell, abrí **PowerShell 7** y ejecutá:

```powershell
git --version
gh --version
claude --version
claude doctor
gh auth login
claude
```

`gh auth login` autentica el acceso al repositorio privado. La primera ejecución de `claude`
abre el inicio de sesión de Claude Code.

## 4. Darle la restauración a Claude

Pegá este mensaje dentro de Claude Code:

```text
Acabo de formatear Windows 11 Pro.

Cloná https://github.com/bygama/workstation.git en $HOME\workstation y tratá ese
repositorio como el estado deseado de esta computadora.

Leé primero el README raíz y la documentación de cada carpeta. Ejecutá las pruebas y el
simulacro completo antes de aplicar cambios. Si algo falla, detenete y explicame el problema.
Si todo está limpio, seguí la restauración en el orden canónico indicado por el repositorio.

Detenete y avisame cuando necesites una autenticación, permisos de administrador o un
reinicio. No ejecutes el debloat real sin mostrar primero -List y -WhatIfOnly, y dejalo para
el final. Aplicá el debloat solamente a mi usuario actual; nunca uses -AllUsers. No conviertas
automáticamente el estado actual de Windows en estado deseado.
```

Desde ese punto Claude se encarga de clonar, revisar, probar y aplicar el repositorio. Sólo
deberías intervenir para aprobar UAC, completar inicios de sesión, reiniciar cuando lo pida y
confirmar el debloat final.
