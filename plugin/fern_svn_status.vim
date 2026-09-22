if exists('g:loaded_fern_svn_status')
  finish
endif
let g:loaded_fern_svn_status = 1

command! -bar FernSvnStatusRefresh call fern_svn_status#refresh()

if !get(g:, 'fern_svn_status_disable_startup', 0)
  augroup fern-svn-status-internal
    autocmd!
    autocmd VimEnter * ++once call fern_svn_status#init()
  augroup END
endif
