let s:Process = vital#fern#import('Async.Promise.Process')

" Execute `svn status --xml` inside the working copy root and parse the
" result.  Resolves to a list of [absolute_path, item, props] entries where
" the path uses Unix slashes so it can be compared directly with node._path.
"
" Rejects with the process result dict when svn exits non-zero, or with the
" CancelledError string when the token is canceled.
function! fern_svn_status#process#status(wcroot, token) abort
  let l:Profile = fern#profile#start('fern_svn_status#process#status')
  return s:Process.start(
        \ ['svn', 'status', '--xml', '--non-interactive'],
        \ {
        \   'cwd': a:wcroot,
        \   'token': a:token,
        \   'reject_on_failure': v:true,
        \ },
        \)
        \.then({ v -> s:parse_status(join(v.stdout, "\n"), a:wcroot) })
        \.finally({ -> l:Profile() })
endfunction

" Parse `svn status --xml` output.  svn pretty-prints the XML with each
" attribute on its own indented line, and item/props may appear in either
" order, so we walk the lines with a small state machine rather than assume a
" single-line tag format.
function! s:parse_status(xml, wcroot) abort
  let root = fern#internal#filepath#to_slash(a:wcroot)
  let entries = []
  let in_entry = v:false
  let path = ''
  let item = ''
  let props = ''
  for line in split(a:xml, "\n")
    if line =~# '^\s*<entry\>'
      let in_entry = v:true
      let path = ''
      let item = ''
      let props = ''
    elseif in_entry && line =~# '\<path="'
      let path = s:xml_decode(matchstr(line, '\<path="\zs[^"]*\ze"'))
    elseif in_entry && line =~# '\<item="'
      let item = matchstr(line, '\<item="\zs[^"]*\ze"')
    elseif in_entry && line =~# '\<props="'
      let props = matchstr(line, '\<props="\zs[^"]*\ze"')
    elseif line =~# '^\s*</entry>'
      if in_entry && path !=# '' && item !=# ''
        call add(entries, [root . '/' . path, item, props])
      endif
      let in_entry = v:false
    endif
  endfor
  return entries
endfunction

" Decode the five predefined XML entities plus numeric character references.
" &amp; is decoded last so that a literal "&lt;" (serialized as "&amp;lt;")
" is not mistaken for an escaped "<".
function! s:xml_decode(str) abort
  let str = a:str
  let str = substitute(str, '&lt;', '<', 'g')
  let str = substitute(str, '&gt;', '>', 'g')
  let str = substitute(str, '&quot;', '"', 'g')
  let str = substitute(str, '&apos;', "'", 'g')
  let str = substitute(str, '&#x\x\+;', '\=nr2char(str2nr(submatch(1), 16))', 'g')
  let str = substitute(str, '&#\d\+;', '\=nr2char(str2nr(submatch(1), 10))', 'g')
  let str = substitute(str, '&amp;', '\&', 'g')
  return str
endfunction
