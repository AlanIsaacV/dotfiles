# Neovim

Una configuración de Neovim pequeña, con un perfil completo en macOS y otro
ligero para SSH y Linux. Es un complemento de Zed: sirve para editar rápido,
navegar un repositorio y revisar cambios desde la terminal.

## Requirements

- Neovim, instalado fuera de este módulo: 0.12 o más reciente en el perfil
  `dev`, porque treesitter y `blink.cmp` no cargan por debajo de esa versión;
  0.11 basta en el perfil remoto. `:checkhealth dotfiles` exige la que pide el
  perfil activo, así que el mismo binario puede pasar en remoto y fallar en
  `dev`.
- `git` para instalar los plugins la primera vez.
- El CLI `tree-sitter` en el perfil `dev`: es quien genera y compila los parsers.
  dotcli lo instala en macOS con la fórmula `tree-sitter-cli` de Homebrew, no con
  `tree-sitter`, que solo trae la librería. Si falta, no verás ningún error: el
  resaltado vuelve en silencio al motor de expresiones regulares de Vim.
- Opcionales: `fzf`, `rg` (ripgrep) y `fd` mejoran las búsquedas; `cc` (un
  compilador de C) es lo que invoca `tree-sitter build` para cada parser.

## Installation

Instala este módulo con dotcli, el gestor de dotfiles del repositorio:
selecciónalo en la lista y confirma la instalación. Eso enlaza
`modules/nvim/dotfiles/nvim` con `~/.config/nvim` y, en macOS, instala con
Homebrew el CLI `tree-sitter`; no instala el binario de Neovim ni usa `apt` o
`sudo`.

Después no queda nada por ejecutar. La primera vez que abras Neovim, él mismo
descarga `lazy.nvim` y los plugins del perfil activo. En el perfil `dev`, mason
instala por su cuenta los servidores de lenguaje de Python, Go y Rust, pero no
al abrir Neovim: lo hace la primera vez que abres un archivo de esos lenguajes.
Su interfaz sigue a mano con `:Mason`.

Las herramientas que instala mason quedan en el `PATH` de cualquier shell fish
nueva, así que `gopls` y compañía también se ejecutan desde la terminal.

## Profiles

`NVIM_PROFILE=dev` o `NVIM_PROFILE=remote` siempre tiene prioridad. Sin esa
variable, macOS fuera de SSH usa `dev`; cualquier sesión SSH y cualquier
equipo Linux usa `remote`.

El perfil remoto carga tema, árbol, búsqueda y ayuda de atajos cuando sus
plugins compartidos ya están instalados. No instala ni carga LSP, completado,
formato o paneles Git. El primer arranque remoto lanza la descarga de
`lazy.nvim` en segundo plano y no la espera: Neovim abre de inmediato como
editor nativo, haya red o no, y la sesión SSH nunca se retrasa por el clon. Al
terminar la descarga, un aviso pide reiniciar Neovim para cargar los plugins.
Esa descarga de fondo se abandona sola a los 30 segundos si no llega a
GitHub; entonces avisa del fallo y el siguiente arranque lo vuelve a intentar.

El perfil `dev` añade indicadores Git en el árbol, revisión visual de cambios,
LSP para Python/Go/Rust, completado y formato explícito. El resaltado y la
indentación los hace treesitter en lugar del motor de expresiones regulares de
Vim, y los diagnósticos se muestran como líneas virtuales debajo de la línea del
cursor: el mensaje completo sin recortar, que desaparece al mover el cursor y
deja el signo en la columna lateral.

Ese perfil no carga mason, mason-lspconfig ni nvim-lspconfig al arrancar:
los tres esperan a que abras un archivo de Python, Go o Rust, y `blink.cmp`
espera a que entres en modo inserción por primera vez.

## First run

El primer inicio abre de inmediato y descarga `lazy.nvim` en segundo plano.
Esa primera sesión trabaja sin plugins: el árbol y la búsqueda avisan de que
aún no están instalados. Cuando la descarga termina lo dice un aviso; reinicia
Neovim y ahí sí carga los plugins del perfil actual. Si cierras Neovim antes de
que acabe, no queda nada a medias y el siguiente inicio lo reintenta.

Para revisar el estado después:

```sh
nvim '+checkhealth dotfiles'
```

## Key bindings

La tecla líder es `Espacio`. Espera un instante tras pulsarla para ver las
acciones disponibles.

| Atajo | Acción | Perfil |
| --- | --- | --- |
| `<Space>e` | Mostrar u ocultar el árbol de archivos | Ambos |
| `<Space>ff` | Buscar archivos | Ambos |
| `<Space>fg` | Buscar texto en el proyecto | Ambos |
| `<Space>gd` | Abrir o cerrar la revisión Git con diffs | `dev` |
| `<Space>ld` | Ir a definición | `dev` |
| `<Space>lr` | Buscar referencias | `dev` |
| `<Space>la` | Acciones de código | `dev` |
| `<Space>cf` | Formatear el búfer actual | `dev` |

Los movimientos y comandos habituales de Vim permanecen intactos. Guardar no
formatea ni modifica archivos automáticamente.

## Troubleshooting

- Si el árbol o la búsqueda muestran un aviso de plugin ausente, la descarga
  todavía no ha terminado o no encontró red. Vuelve a abrir Neovim con red
  disponible: reintenta la descarga en segundo plano, otra vez sin retrasar el
  arranque. Con `:checkhealth dotfiles` revisas si la versión de Neovim y las
  herramientas externas (`fzf`, `rg`, `fd`, `tree-sitter`, `cc`) están en orden.
- Si la búsqueda es limitada en un servidor, instala `fzf`, `rg` o `fd` si la
  política del servidor lo permite; Neovim seguirá funcionando sin ellos.
- Para confirmar el perfil actual, ejecuta
  `:echo g:dotfiles_nvim_profile` dentro de Neovim.
