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

function! s:MatchIf() "{{{
    let line = getline('.')
    return line =~ '^\s\+if'
endfunction "}}}

function! s:MatchElse() "{{{
    let line = getline('.')
    return line =~ '^\s\+else\s*$'
endfunction "}}}

function! s:MatchElseIf() "{{{
    let line = getline('.')
    return line =~ '^\s\+else if'
endfunction "}}}

function! s:MatchFor() "{{{
    let line = getline('.')
    return line =~ '^\s\+for'
endfunction "}}}

function! s:MatchWhile() "{{{
    let line = getline('.')
    return line =~ '^\s\+while'
endfunction "}}}

function! s:MatchDoWhile() "{{{
    let line = getline('.')
    return line =~ '^\s\+do while'
endfunction "}}}

function! s:MatchSingleWordStatement() "{{{
    let line = getline('.')
    return line =~ '^\s\+\w\+$'
endfunction "}}}

function! s:MatchFunctionDefinition() "{{{
    let line = getline('.')
    return line =~ '^\S\+\s\+\S\+' &&
                \ line !~ '='
endfunction "}}}

function! s:MatchInclude() " {{{
    let line = getline('.')
    return line =~ '^#include\s\+\S\+\s*$' &&
                \ line !~ '\(<.*>\|".*"\)'
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
    return getline('.') =~ '[;,&|({+\-*/%]$'
endfunction "}}}

function! Macro() "{{{
    return getline('.') =~ '^#'
endfunction "}}}

function! s:LocalFile(includeName) "{{{
    return glob(a:includeName) != ''
endfunction "}}}

function!  s:NextLineClosesStructure() "{{{
    echom 'next line closes structure?'
    " let nextLine = getline(line('.') + 1)
    let nextLine = getline(nextnonblank(line('.') + 1))
    echom nextLine
    return nextLine =~ '^};$'
endfunction "}}}

function! s:InsideStructure() "{{{
    let saveCursor = getpos('.')
    let r = 0
    " Search backwards to open brace that isn't in a string
    let prevBrace = searchpair('{', '', '}', 'bW', 'synIDattr(synID(line("."), col("."), 0), "name") =~? "string"')
    if prevBrace
        let braceLine = getline(prevBrace)
        if braceLine =~ '=\s\+{' || braceLine =~ '\(enum\|structure\|union\)'
            let r = 1
        endif
    endif
    call setpos('.', saveCursor)
    return r
endfunction "}}}

function! s:EndLine(key) "{{{
    echom 'endline' a:key

    let eolChar = ';'
    if s:InsideStructure()
        let eolChar = ','
    endif

    if a:key == "\r"
        if InComment() || AlreadyEnded() || BlankLine() || Macro()
            return a:key
        else
            return eolChar . a:key
        endif
    elseif a:key == "\e"
        if InComment() || AlreadyEnded() || BlankLine() || !EOL() || Macro() || s:NextLineClosesStructure()
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
    if InComment() || line =~ ';$'
        echom 'match comment or ;$'
        return "\r"
    elseif s:MatchIf() "{{{
        echom 'match if'
        let newLine = substitute(line, '^\(\s*\w\+\)\s\+\(.*\)$', '\1 (\2) {', '')
        call setline('.', newLine)
        return "\eo}\eO"
        "}}}
    elseif s:MatchElse() "{{{
        echom 'match else'
        return "\ebC} else {\r"
        "}}}
    elseif s:MatchElseIf() "{{{
        echom 'match else if'
        let newLine = substitute(line, '^\(\s*\)else if\s\+\(.*\)$', '\1else if (\2) {', '')
        call setline('.', newLine)
        return "\eI} \eo}\eO"
        "}}}
    elseif s:MatchFor() "{{{
        echom 'match for'
        if line =~ '^\s*for$'
            let newLine = substitute(line, '^\(\s*\w\+\)$', '\1 (;;) {', '')
        else
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
        endif
        call setline('.', newLine)
        return "\eo}\eO"
        " }}}
    elseif s:MatchWhile() "{{{
        echom 'match while'
        if line =~ '^\s*while$'
            let newLine = substitute(line, '^\(\s*\w\+\)$', '\1 (1) {', '')
        else
            let newLine = substitute(line, '^\(\s*\w\+\)\s\+\(.*\)$', '\1 (\2) {', '')
        endif
        call setline('.', newLine)
        return "\eo}\eO"
        "}}}
    elseif s:MatchDoWhile() "{{{
        echom 'match do'
        let newLine = substitute(line, '^\(\s*\w\+\).*$', '\1 {', '')
        let closeLine = substitute(line, '^\(\s*\)\w\+\s\+\w\+\s\+\(.*\)$', '\1} while (\2);', '')
        call setline('.', newLine)
        call append('.', closeLine)
        return "\eo"
        "}}}
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
    elseif s:MatchInclude() " {{{
        echom 'match include'
        let includeName = substitute(line, '^#include\s\+\(\S\+\)\s*$', '\1', '')
        if includeName !~ '\.'
            let includeName = includeName . '.h'
        endif
        if s:LocalFile(includeName)
            let newLine = "#include \"" . includeName . "\""
        else
            let newLine = "#include <" . includeName . ">"
        endif
        call setline('.', newLine)
        call cursor(0, col('$'))
        return "\r"
        "}}}
    elseif s:MatchSingleWordStatement() && !s:InsideStructure() "{{{
        echom 'match single word statement'
        return "();\r"
    "}}}
    elseif line =~ '^int main\(()\)\?$' "{{{
        echom 'match int main'
        return "(int argc, char *argv[]) {\eo}\r\ekO"
        "}}}
    elseif s:MatchFunctionDefinition() && EOL() "{{{
        echom 'function! ' . line
        if line =~ ')\s*$'
            return " {\eo}\r\ekO"
        else
            return "() {\eo}\r\ekO"
        endif
        "}}}
    else
        echom 'unmatched ' . line
    endif
    return s:EndLine("\r")
endfunction " }}}

function! s:BackspaceHandler() "{{{
    echom 'bs' '"'.getline('.').'"'
    let line = getline('.')
    if line =~ "//$"
        echom 'bs comment'
        call setline(line('.'), substitute(line,'\(.*\)//\s\?$','\1',''))
    endif
    return ""
endfunction "}}}

" {{{ Maps and abbreviations
"
inoremap <expr> <silent> <Plug>EndLineEsc  <SID>EndLine("<Esc>")
inoremap <silent> <Plug>ExpandStatement  <C-R>=<SID>ExpandStatement()<CR>
inoremap <silent> <Plug>BackspaceHandler  <C-R>=<SID>BackspaceHandler()<CR>
" Expand abbreviations next to cursor using:
" <Space><bs>
imap <buffer> <ESC> <Space><bs><Plug>EndLineEsc
imap <buffer> <CR> <Space><bs><Plug>ExpandStatement
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
