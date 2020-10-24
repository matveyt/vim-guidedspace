" Vim GuidedSpace plugin
" Maintainer:   matveyt
" Last Change:  2020 Oct 24
" License:      https://unlicense.org
" URL:          https://github.com/matveyt/vim-guidedspace

" This is only to allow user to skip the plugin load
if exists('g:loaded_guidedspace')
    finish
endif

let s:save_cpo = &cpo
set cpo&vim

" If hl-Conceal has any background and is not linked (yet)
" then we make it follow hl-Whitespace (or hl-SpecialKey)
function s:patch_conceal() abort
    let l:id = hlID('Conceal')
    if !empty(synIDattr(l:id, 'bg')) && l:id == synIDtrans(l:id)
        execute 'hi! link Conceal' hlexists('Whitespace') ? 'Whitespace' : 'SpecialKey'
    endif
endfunction

" Add syntax elements to show guides
function s:add_guides(width) abort
    " also require indent plugin for this buffer
    " it saves us from filtering out many "special" buffers
    " Note: ":filetype indent on" must precede ":syntax on" or it won't work!
    if !get(g:, 'syntax_on') || !get(b:, 'did_indent')
        return
    endif

    " GuidedSpace is here for performance reasons
    " GuidedChar still includes dreaded \@<= part,
    " because some other groups may have "contains=ALL"
    execute printf('syntax match GuidedSpace /^\s\{%d,}/', 1 + a:width)
        \ 'transparent containedin=ALL contains=GuidedChar'
    execute printf('syntax match GuidedChar /\(^\s\+\)\@<= \{%d}/ms=e', a:width)
        \ 'contained conceal cchar='..nr2char(get(g:, 'GuidedChar', 0xA6))

    " &conceallevel and &concealcursor are local to window!
    for l:winid in win_findbuf(bufnr())
        let [l:tabnr, l:winnr] = win_id2tabwin(l:winid)
        if gettabwinvar(l:tabnr, l:winnr, '&conceallevel') == 0
            call settabwinvar(l:tabnr, l:winnr, '&conceallevel',
                \ get(g:, 'GuidedLevel', 2))
            call settabwinvar(l:tabnr, l:winnr, '&concealcursor',
                \ get(g:, 'GuidedCursor', 'ni'))
        endif
    endfor
endfunction

" Safely remove syntax for guides
function s:remove_guides() abort
    try
        syntax clear GuidedSpace GuidedChar
    catch | endtry
endfunction

" Set trap for Syntax event
const s:thisfile = expand('<sfile>')
function s:trap_events(on) abort
    augroup GuidedSpace | au!
    if a:on
        autocmd ColorScheme * call s:patch_conceal()
        autocmd OptionSet shiftwidth
            \   call s:remove_guides()
            \ | call s:add_guides(shiftwidth())
        autocmd OptionSet tabstop
            \   if !&shiftwidth
            \ |     call s:remove_guides()
            \ |     call s:add_guides(&tabstop)
            \ | endif
        autocmd Syntax * call s:add_guides(shiftwidth())
        autocmd User GuidedSpace
            \   call s:remove_guides()
            \ | call s:add_guides(shiftwidth())
    else
        autocmd User GuidedSpace call s:remove_guides()
    endif
    augroup end

    " hook into Vim syntax plugin, see :h synload-2
    if a:on
        call s:patch_conceal()
        let g:mysyntaxfile = s:thisfile
    else
        unlet! g:mysyntaxfile
    endif
endfunction

" User command implementation
function s:user_command(bang, ...) abort
    if a:bang
        if a:0
            " trap events only
            call s:trap_events(a:1)
        else
            " force Syntax update only
            doautoall User GuidedSpace
        endif
    else
        " do both
        call s:trap_events(get(a:, 1, 1))
        doautoall User GuidedSpace
    endif
endfunction

" Reset event trap
call s:trap_events(get(g:, 'syntax_on'))
if v:vim_did_enter && exists(':GuidedSpace') != 2
    " if loading plugin after VimEnter then force Syntax update
    doautoall User GuidedSpace
endif

command! -bar -bang -nargs=? GuidedSpace call s:user_command(<bang>0, <args>)

let &cpo = s:save_cpo
unlet s:save_cpo