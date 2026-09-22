let s:CancellationTokenSource = vital#fern#import('Async.CancellationTokenSource')
let s:Promise = vital#fern#import('Async.Promise')

let s:GET_WCROOT_CACHE_VARNAME = 'fern_svn_status_get_wcroot_cache'
let s:GET_STATUS_SOURCE_VARNAME = 'fern_svn_status_get_status_source'

" Resolve to a dictionary mapping an absolute path (Unix slashes) to a single
" status character, e.g. {'/repo/file.c': 'M', '/repo/dir': '-'}.
function! fern_svn_status#investigator#investigate(helper, options) abort
  let wcroot = s:get_wcroot(a:helper)
  let entries = s:get_status(a:helper, wcroot)
  return s:Promise.all([wcroot, entries])
        \.then({ v -> s:build_status_map(v[0], v[1], a:options) })
endfunction

" Locate the SVN working copy root.  SVN 1.7+ keeps a single .svn directory at
" the root of the working copy, so finddir() with a trailing ';' walks upward
" until it finds one.  The result (a Promise) is cached per buffer since the
" fern root never changes within a buffer's lifetime.
function! s:get_wcroot(helper) abort
  let bufnr = a:helper.bufnr
  let cache = getbufvar(bufnr, s:GET_WCROOT_CACHE_VARNAME, v:null)
  if cache isnot# v:null
    return cache
  endif
  let root = fern#internal#filepath#to_slash(a:helper.fern.root._path)
  " Strip a trailing slash (but keep '/') so finddir() gets a clean base.
  let root = root ==# '/' ? root : substitute(root, '/$', '', '')
  let found = finddir('.svn', root . ';')
  if found ==# ''
    let p = s:Promise.reject('Not a Subversion working copy')
  else
    let p = s:Promise.resolve(fnamemodify(found, ':h'))
  endif
  call setbufvar(bufnr, s:GET_WCROOT_CACHE_VARNAME, p)
  return p
endfunction

" Run `svn status --xml`, canceling any previous in-flight request first so
" that a stale (slower) query can never overwrite a newer one.
function! s:get_status(helper, wcroot) abort
  let bufnr = a:helper.bufnr
  let previous = getbufvar(bufnr, s:GET_STATUS_SOURCE_VARNAME, v:null)
  if previous isnot# v:null
    call previous.cancel()
  endif
  let source = s:CancellationTokenSource.new()
  call setbufvar(bufnr, s:GET_STATUS_SOURCE_VARNAME, source)
  return a:wcroot.then({ root -> fern_svn_status#process#status(root, source.token) })
endfunction

function! s:build_status_map(wcroot, entries, options) abort
  let status_chars = a:options.status_chars
  let stained_items = a:options.stained_items
  let result = {}
  for [path, item, props] in a:entries
    if item ==# 'unversioned' && !a:options.include_unversioned
      continue
    elseif item ==# 'ignored' && !a:options.include_ignored
      continue
    endif
    let char = s:item_to_char(item, props, status_chars)
    if char ==# ''
      continue
    endif
    let result[path] = char
    if a:options.include_directories && index(stained_items, item) >= 0
      call s:stain_directories(result, path, a:options.stained_character)
    endif
  endfor
  return result
endfunction

function! s:item_to_char(item, props, status_chars) abort
  if has_key(a:status_chars, a:item)
    return a:status_chars[a:item]
  endif
  " Property-only changes (item is 'normal'/'none'): surface them as a content
  " change so they are still visible in the tree.
  if a:props ==# 'modified'
    return get(a:status_chars, 'modified', 'M')
  elseif a:props ==# 'conflicted'
    return get(a:status_chars, 'conflicted', 'C')
  endif
  return ''
endfunction

" Mark every ancestor directory of a stained path with the stained character.
function! s:stain_directories(map, path, char) abort
  let dir = fern#internal#path#dirname(a:path)
  while dir !=# '' && !has_key(a:map, dir)
    let a:map[dir] = a:char
    let dir = fern#internal#path#dirname(dir)
  endwhile
endfunction
