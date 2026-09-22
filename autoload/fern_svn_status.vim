let s:PROCESSING_VARNAME = 'fern_svn_status_processing'

let s:CancellationToken = vital#fern#import('Async.CancellationToken')

function! fern_svn_status#init() abort
  if exists('s:ready')
    return
  endif
  let s:ready = 1
  call fern#hook#add('viewer:highlight', function('s:on_highlight'))
  call fern#hook#add('viewer:syntax', function('s:on_syntax'))
  call fern#hook#add('viewer:redraw', function('s:on_redraw'))
endfunction

function! s:options() abort
  return {
        \ 'include_ignored': !g:fern_svn_status#disable_ignored,
        \ 'include_unversioned': !g:fern_svn_status#disable_unversioned,
        \ 'include_directories': !g:fern_svn_status#disable_directories,
        \ 'stained_character': g:fern_svn_status#stained_character,
        \ 'stained_items': g:fern_svn_status#stained_items,
        \ 'status_chars': g:fern_svn_status#status_chars,
        \}
endfunction

function! s:on_highlight(...) abort
  highlight default link FernSvnStatusBracket Comment
  highlight default link FernSvnStatusModified Special
  highlight default link FernSvnStatusAdded Special
  highlight default link FernSvnStatusDeleted WarningMsg
  highlight default link FernSvnStatusReplaced Special
  highlight default link FernSvnStatusConflicted ErrorMsg
  highlight default link FernSvnStatusMissing WarningMsg
  highlight default link FernSvnStatusUnversioned Comment
  highlight default link FernSvnStatusIgnored Comment
  highlight default link FernSvnStatusExternal Comment
  highlight default link FernSvnStatusStained WarningMsg
endfunction

function! s:on_syntax(...) abort
  syntax match FernSvnStatusBracket /.*/ contained containedin=FernBadge
  syntax match FernSvnStatus /\[\zs.\ze\]/ contained containedin=FernSvnStatusBracket
  syntax match FernSvnStatusModified   /M/ contained containedin=FernSvnStatus
  syntax match FernSvnStatusAdded      /A/ contained containedin=FernSvnStatus
  syntax match FernSvnStatusDeleted    /D/ contained containedin=FernSvnStatus
  syntax match FernSvnStatusReplaced   /R/ contained containedin=FernSvnStatus
  syntax match FernSvnStatusConflicted /C/ contained containedin=FernSvnStatus
  syntax match FernSvnStatusMissing    /!/ contained containedin=FernSvnStatus
  syntax match FernSvnStatusUnversioned /?/ contained containedin=FernSvnStatus
  syntax match FernSvnStatusIgnored    /I/ contained containedin=FernSvnStatus
  syntax match FernSvnStatusExternal   /X/ contained containedin=FernSvnStatus
  syntax match FernSvnStatusStained    /-/ contained containedin=FernSvnStatus
endfunction

function! s:on_redraw(helper) abort
  let bufnr = a:helper.bufnr
  let processing = getbufvar(bufnr, s:PROCESSING_VARNAME, 0)
  if a:helper.fern.scheme !=# 'file' || processing
    return
  endif
  call fern_svn_status#investigator#investigate(a:helper, s:options())
        \.then({ m -> map(
        \   copy(a:helper.fern.visible_nodes),
        \   { _, v -> s:update_node(m, v) },
        \) })
        \.then({ _ -> s:redraw(a:helper) })
        \.catch({ e -> s:handle_error(e) })
endfunction

function! s:update_node(status_map, node) abort
  let path = resolve(fern#internal#filepath#to_slash(a:node._path))
  let status = get(a:status_map, path, '')
  let a:node.badge = status ==# '' ? '' : printf(' [%s]', status)
  return a:node
endfunction

function! s:redraw(helper) abort
  let bufnr = a:helper.bufnr
  call setbufvar(bufnr, s:PROCESSING_VARNAME, 1)
  return a:helper.async.redraw()
        \.then({ _ -> setbufvar(bufnr, s:PROCESSING_VARNAME, 0) })
endfunction

function! s:handle_error(err) abort
  let msg = s:error_message(a:err)
  if msg ==# s:CancellationToken.CancelledError
    " Superseded by a newer request; nothing to report.
    return
  endif
  if msg =~# 'is not an executable' || (type(a:err) is# v:t_dict && get(a:err, 'exitval', 0) == 122)
    " The `svn` executable is unavailable (System.Job refuses to start it, or
    " Vim reports exit code 122 when exec fails).  Ignore silently.
    return
  endif
  if msg =~? 'not a working copy' || msg =~# 'E155007'
    " fern was opened outside a Subversion working copy.
    return
  endif
  call fern#logger#error(msg)
endfunction

function! s:error_message(err) abort
  if type(a:err) is# v:t_string
    return a:err
  elseif type(a:err) is# v:t_dict
    " A vital Promise that rejected with a thrown exception carries
    " {'throwpoint', 'exception'} rather than a process result.
    if has_key(a:err, 'exception')
      return a:err.exception
    elseif has_key(a:err, 'stderr') && type(a:err.stderr) is# v:t_list
      let stderr = join(a:err.stderr, "\n")
      return stderr !=# '' ? stderr : string(a:err)
    endif
    return string(a:err)
  endif
  return string(a:err)
endfunction

" Force a refresh of every visible fern buffer, e.g. after committing from
" another terminal.  Triggering a redraw re-runs the `viewer:redraw` hook.
function! fern_svn_status#refresh() abort
  for bufnr in range(1, bufnr('$'))
    if !buflisted(bufnr) || getbufvar(bufnr, '&filetype', '') !=# 'fern'
      continue
    endif
    try
      call fern#helper#new(bufnr).async.redraw()
    catch
    endtry
  endfor
endfunction

let g:fern_svn_status#disable_ignored = get(g:, 'fern_svn_status#disable_ignored', 0)
let g:fern_svn_status#disable_unversioned = get(g:, 'fern_svn_status#disable_unversioned', 0)
let g:fern_svn_status#disable_directories = get(g:, 'fern_svn_status#disable_directories', 0)
let g:fern_svn_status#stained_character = get(g:, 'fern_svn_status#stained_character', '-')
let g:fern_svn_status#stained_items = get(g:, 'fern_svn_status#stained_items', [
      \ 'modified',
      \ 'added',
      \ 'deleted',
      \ 'replaced',
      \ 'conflicted',
      \ 'missing',
      \ 'incomplete',
      \ 'obstructed',
      \ 'unversioned',
      \])
let g:fern_svn_status#status_chars = get(g:, 'fern_svn_status#status_chars', {
      \ 'modified': 'M',
      \ 'added': 'A',
      \ 'deleted': 'D',
      \ 'replaced': 'R',
      \ 'conflicted': 'C',
      \ 'missing': '!',
      \ 'incomplete': '!',
      \ 'obstructed': '~',
      \ 'unversioned': '?',
      \ 'ignored': 'I',
      \ 'external': 'X',
      \})
