# fern-svn-status.vim

Add [Subversion](https://subversion.apache.org/) status badges to
[fern.vim](https://github.com/lambdalisue/fern.vim) — the SVN counterpart of
[fern-git-status](https://github.com/lambdalisue/fern-git-status.vim).

Open fern inside a Subversion working copy and every node that differs from the
repository gets a badge:

```
subproject/                 [-]
  src/
    main.c                  [M]   (modified)
    newfile.c               [A]   (added)
    legacy.c                [D]   (deleted)
    fixme.c                 [C]   (conflicted)
    scratch.c               [?]   (unversioned)
    build.log               [I]   (ignored)
```

The status is fetched asynchronously with `svn status --xml --no-ignore` (local only, no
network access) and written into `node.badge`, so it works with any renderer
that appends the badge — including
[fern-renderer-nerdfont](https://github.com/lambdalisue/fern-renderer-nerdfont.vim).

## Installation

Using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'lambdalisue/fern.vim'
Plug 'sqlmap3/vim-fern-svn-status'
```

## Usage

Just open fern inside a Subversion working copy.  Badges appear automatically
and update as you expand/collapse nodes.

Run `:FernSvnStatusRefresh` to force a refresh (e.g. after committing from
another terminal).

## Configuration

| Variable | Default | Description |
| --- | --- | --- |
| `g:fern_svn_status_disable_startup` | `0` | Disable auto-registration on startup; call `fern_svn_status#init()` manually. |
| `g:fern_svn_status#disable_ignored` | `0` | Hide ` [I]` badges. |
| `g:fern_svn_status#disable_unversioned` | `0` | Hide ` [?]` badges. |
| `g:fern_svn_status#disable_directories` | `0` | Disable the ` [-]` directory summary. |
| `g:fern_svn_status#stained_character` | `'-'` | Character shown on a directory that contains a change. |
| `g:fern_svn_status#stained_items` | see below | Item statuses that mark an ancestor directory as stained. |
| `g:fern_svn_status#status_chars` | see below | Maps an SVN item status to a display character. |

### Status characters

The default mapping follows Subversion's own `svn status` single-letter codes:

| item | char | item | char |
| --- | --- | --- | --- |
| `modified` | `M` | `missing` / `incomplete` | `!` |
| `added` | `A` | `obstructed` | `~` |
| `deleted` | `D` | `unversioned` | `?` |
| `replaced` | `R` | `ignored` | `I` |
| `conflicted` | `C` | `external` | `X` |

Property-only changes (the second column of `svn status`) are surfaced as `M`
or `C`.  Override `g:fern_svn_status#status_chars` to use Nerd Font glyphs or
other characters, e.g.:

```vim
let g:fern_svn_status#status_chars = {
      \ 'modified': 'M',
      \ 'added': 'A',
      \ 'deleted': 'D',
      \ 'conflicted': 'C',
      \ 'unversioned': '?',
      \ 'ignored': 'I',
      \}
```

The default `g:fern_svn_status#stained_items` is
`['modified', 'added', 'deleted', 'replaced', 'conflicted', 'missing',
'incomplete', 'obstructed', 'unversioned']`.

## Requirements

- Vim 8.2+ or Neovim 0.4+
- [fern.vim](https://github.com/lambdalisue/fern.vim)
- Subversion 1.7+ (`svn` on `$PATH`)

## License

MIT — see [LICENSE](LICENSE).
