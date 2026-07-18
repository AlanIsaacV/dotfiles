# Neovim

Una configuración de Neovim pequeña, con un perfil completo en macOS y otro
ligero para SSH y Linux. Es un complemento de Zed: sirve para editar rápido,
navegar un repositorio y revisar cambios desde la terminal.

## Requirements

- Neovim 0.11 o más reciente, instalado fuera de este módulo.
- `git` para instalar los plugins la primera vez.
- Opcionales: `fzf`, `rg` (ripgrep) y `fd` mejoran las búsquedas.

## Installation

Instala este módulo con el gestor de dotfiles del repositorio. Este enlaza
`modules/nvim/dotfiles/nvim` con `~/.config/nvim`; no instala el binario de
Neovim ni usa `apt`, Homebrew o `sudo`.

Después del enlace, instala los plugins del perfil activo:

```sh
modules/nvim/bootstrap.sh
```

En el Mac, instala también los servidores de lenguaje para Python, Go y Rust:

```sh
NVIM_PROFILE=local modules/nvim/bootstrap.sh --install-lsp
```

## Profiles

`NVIM_PROFILE=local` o `NVIM_PROFILE=remote` siempre tiene prioridad. Sin esa
variable, macOS fuera de SSH usa `local`; cualquier sesión SSH y cualquier
equipo Linux usa `remote`.

El perfil remoto carga tema, árbol, búsqueda y ayuda de atajos cuando sus
plugins compartidos ya están instalados. No instala ni carga LSP, completado,
formato o paneles Git. Para no retrasar una sesión SSH sin red, el primer
arranque remoto no descarga nada: ejecuta `bootstrap.sh` explícitamente cuando
tengas conexión. Sin plugins, Neovim sigue abriendo como editor nativo.

El perfil local añade indicadores Git en el árbol, revisión visual de cambios,
LSP para Python/Go/Rust, completado y formato explícito.

## First run

El primer inicio puede descargar `lazy.nvim` y los plugins del perfil actual.
Para revisar el estado después:

```sh
nvim '+checkhealth'
```

## Key bindings

La tecla líder es `Espacio`. Espera un instante tras pulsarla para ver las
acciones disponibles.

| Atajo | Acción | Perfil |
| --- | --- | --- |
| `<Space>e` | Mostrar u ocultar el árbol de archivos | Ambos |
| `<Space>ff` | Buscar archivos | Ambos |
| `<Space>fg` | Buscar texto en el proyecto | Ambos |
| `<Space>gd` | Abrir o cerrar la revisión Git con diffs | Local |
| `<Space>ld` | Ir a definición | Local |
| `<Space>lr` | Buscar referencias | Local |
| `<Space>la` | Acciones de código | Local |
| `<Space>cf` | Formatear el búfer actual | Local |

Los movimientos y comandos habituales de Vim permanecen intactos. Guardar no
formatea ni modifica archivos automáticamente.

## Troubleshooting

- Si el árbol o la búsqueda muestran un aviso de plugin ausente, ejecuta
  `modules/nvim/bootstrap.sh` con red y `git` disponible.
- Si la búsqueda es limitada en un servidor, instala `fzf`, `rg` o `fd` si la
  política del servidor lo permite; Neovim seguirá funcionando sin ellos.
- Para confirmar el perfil actual, ejecuta
  `:echo g:dotfiles_nvim_profile` dentro de Neovim.
