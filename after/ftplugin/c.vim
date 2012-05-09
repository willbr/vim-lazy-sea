function! SyntaxName(l, c, ...) "{{{
    let trans = a:0 > 0 ? a:1 : 0
    return synIDattr(synID(a:l, a:c, trans), 'name')
endfunction "}}}

function! FirstWord() "{{{
    let t = getline('.') =~ '^\w\+$'
    return t
endfunction "}}}

function! s:InFunction() "{{{
    let line = getline('.')
    return line =~ '\w\+\s*('
endfunction "}}}

function! InComment() " {{{
    let syn = SyntaxName(line('.'), col('.') - 1, 1)
    if syn =~? 'comment'
        return 1
    else
        return 0
    endif
endfunction "}}}

function! EOL() "{{{
    if col('.') == col('$')
        return 1
    else
        return 0
    endif
endfunction "}}}

function! BlankLine() "{{{
    return getline('.') =~ '^\s*$'
endfunction "}}}

function! AlreadyEnded() "{{{
    return getline('.') =~ '[;,&|({[\]+\-*/%]$'
endfunction "}}}

function! Macro() "{{{
    return getline('.') =~ '^#'
endfunction "}}}

function! s:LocalFile(includeName) "{{{
    return glob(a:includeName) != ''
endfunction "}}}

function! InExpandStatement() "{{{
    return getline('.') =~ '^\s*\(while\|for\|if\)'
endfunction "}}}

function! s:EndLine(key) "{{{
    let saveCursor = getpos('.')
    " Search backwards to open brace that isn't in a string
    let prevBrace = searchpair('{', '', '}', 'bW', 'synIDattr(synID(line("."), col("."), 0), "name") =~? "string"')

    let eolChar = ';'
    if prevBrace
        let braceLine = getline(prevBrace)
        if braceLine =~ '=\s\+{' || braceLine =~ "enum"
            let eolChar = ','
        endif
    endif
    call setpos('.', saveCursor)

    if a:key == "\r"
        if InComment() || AlreadyEnded() || BlankLine() || Macro()
            return a:key
        else
            return eolChar . a:key
        endif
    elseif a:key == "\e" " <Esc>
        if InComment() || AlreadyEnded() || BlankLine() || !EOL() || Macro()
            return a:key
        else
            return eolChar . a:key
        endif
    endif
    echom 'unknown key ' . a:key
    return a:key
endfunction "}}}

function! s:ExpandStatement() "{{{
    echom 'es'
    let line = getline('.')
    " match logic statements
    if InExpandStatement()
        echom 'ies'
        if line =~ '^\s*while$'
            let newLine = substitute(line, '^\(\s*\w\+\)$', '\1 (1) {', '')
        elseif line =~ '^\s*for$'
            let newLine = substitute(line, '^\(\s*\w\+\)$', '\1 (;;) {', '')
        elseif line =~ '^\s*for'
            let forArgs = substitute(line, '^\s*\w\+\(.*\)$', '\1', '')
            let lineIndent = substitute(line, '^\(\s*\).*$', '\1', '')
            if forArgs =~ '\w\+\s\+in\s\+range'
                let iterator = substitute(forArgs, '.\{-}\(\w\+\)\s\+in\s\+range.*', '\1', '')
                let rangeArgV = split(substitute(forArgs, '^.*range\s\+\(.*\)\s*$', '\1', ''))
                let rangeArgC = len(rangeArgV)
                if rangeArgC == 1
                    let limit = rangeArgV[0]
                    let newLine = lineIndent . "for (".iterator." = 0; ".iterator." < ".limit."; ".iterator."++) {"
                elseif rangeArgC == 2
                    let [start, limit] = rangeArgV
                    let newLine = lineIndent . "for (".iterator." = ".start."; ".iterator." < ".limit."; ".iterator."++) {"
                elseif rangeArgC == 3
                    let [start, limit, step] = rangeArgV
                    let newLine = lineIndent . "for (".iterator." = ".start."; ".iterator." < ".limit."; ".iterator."+=".step.") {"
                else
                    let newLine = lineIndent . "for (".iterator." = 0; ".iterator." < limit; ".iterator."++) {"
                endif
            else
                let newLine = substitute(line, '^\(\s*\w\+\)\s\+\(.*\)$', '\1 (\2) {', '')
            endif
        else
            let newLine = substitute(line, '^\(\s*\w\+\)\s\+\(.*\)$', '\1 (\2) {', '')
        endif
        call setline('.', newLine)
        return "\eo}\eO"
    " match structure inizilization
    elseif line =~ '=\s*{\s*$'
        echom 'assign {'
        return "\eo};\eO"
    " match enum, struct or union
    elseif line =~ '\(enum\|struct\|union\)' && line !~ '[{}]$' && EOL()
        echom 'enum|struct|union'
        if line !~ 'enum\s*$'
            let typedefLine = substitute(line, '^\(\s*\)\(enum\|struct\|union\)\s\+\(\w\+\).*', '\1typedef \2 \3 \3;', '')
            call append(line('.') - 1, typedefLine)
        endif
        return " {\eo};\r\ekO"
    " match include macro
    elseif line =~ '^#include\s\+\S\+\s*$' && line !~ '\(<.*>\|".*"\)'
        echom 'include'
        let includeName = substitute(line, '^#include\s\+\(\S\+\)\s*$', '\1', '')
        if includeName !~ '\.'
            let includeName = includeName . '.h'
        endif
        if s:LocalFile(includeName)
            let newLine = "#include \"" . includeName . "\""
        else
            let newLine = "#include <" . includeName . ">"
        endif
        echo line
        echo includeName
        echo newLine
        call setline('.', newLine)
        call cursor(0, col('$'))
        return "\r"
    " match function! definition
    elseif s:InFunction() && line !~ '[{;]$' && EOL()
        echom 'function! ' . line
        if line =~ ')\s*$'
            return " {\eo}\r\ekO"
        else
            return "() {\eo}\r\ekO"
        endif
    elseif line =~ '^int main$'
        return "(int argc, char *argv[]) {\eo}\r\ekO"
    else
        echom 'unmatched ' . line
    endif
    return s:EndLine("\r")
endfunction " }}}

function! s:BackspaceHandler() "{{{
    if getline('.') == "// "
        call setline(line('.'), "")
    endif
    return ""
endfunction "}}}

" {{{ Maps and abbreviations
"
inoremap <expr> <silent> <Plug>EndLineEsc  <SID>EndLine("<Esc>")
inoremap <silent> <Plug>ExpandStatement  <C-R>=<SID>ExpandStatement()<CR>
inoremap <silent> <Plug>BackspaceHandler  <C-R>=<SID>BackspaceHandler()<CR>
" uses imap to call itself; forces abbreviations next to the cursor to be
" expanded
imap <buffer> <ESC> <ESC><Plug>EndLineEsc
imap <buffer> <CR> <CR><BS><Plug>ExpandStatement
imap <buffer> <BS> <BS><Plug>BackspaceHandler

iabb <expr> <buffer> is InComment() ? "is" : "=="
iabb <expr> <buffer> isnt InComment() ? "isnt" : "!="
iabb <expr> <buffer> not InComment() ? "not" : "!"
iabb <expr> <buffer> and InComment() ? "and" : "&&"
iabb <expr> <buffer> or InComment() ? "or" : "\|\|"

iabb <expr> <buffer> null InComment() ? "null" : "NULL"
iabb <expr> <buffer> eof InComment() ? "eof" : "EOF"

iabb <expr> <buffer> include FirstWord() ? "#include" : "include"
iabb <expr> <buffer> define FirstWord() ? "#define" : "define"
iabb <expr> <buffer> ifndef FirstWord() ? "#ifndef" : "ifndef"
iabb <expr> <buffer> undef FirstWord() ? "#undef" : "undef"
iabb <expr> <buffer> if FirstWord() ? "#if" : "if"
iabb <expr> <buffer> elif FirstWord() ? "#elif" : "elif"
iabb <expr> <buffer> else FirstWord() ? "#else" : "else"
" }}}
"  vim: fdm=marker
