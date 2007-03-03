set viminfo=""
set nocompatible
set updatecount=0
set visualbell
set ff=unix
set uc=0
set textwidth=70
set ruler
set history=50

set foldmethod=syntax
set foldclose=all
if &t_Co > 1
   syntax on
endif

set showfulltag

" --------------------
"  Taglist
" --------------------

let tlist_foo_settings = 'foo;m:macros;t:types;v:array types;g:module variables;i:interfaces;r:routines'
"let tlist_foo_settings = 'foo;m:macro;a:attribute;i:interface;f:function;s:subroutine'

" let Tlist_Ctags_Cmd = '/home/dylan/bin/ctags'
let Tlist_Auto_Open = 1
let Tlist_Use_Right_Window = 1
let Tlist_WinWidth = 45
let Tlist_Enable_Fold_Column = 0
" let Tlist_Display_Prototype = 1
" let Tlist_Display_Tag_Scope = 0

" --------------------
"  ShowMarks
" --------------------

let showmarks_include = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
let g:showmarks_enable = 1
" For marks a-z
highlight ShowMarksHLl gui=bold guibg=LightBlue guifg=Blue                      
" For marks A-Z
highlight ShowMarksHLu gui=bold guibg=LightRed guifg=DarkRed
" For all other marks
highlight ShowMarksHLo gui=bold guibg=LightYellow guifg=DarkYellow
" For multiple marks on the same line.
highlight ShowMarksHLm gui=bold guibg=LightGreen guifg=DarkGreen 
