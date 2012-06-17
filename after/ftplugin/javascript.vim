


inoremap <silent> <Plug>ExpandStatementESC <C-R>=<SID>ExpandStatement("\e")<CR>
inoremap <silent> <Plug>ExpandStatementCR <C-R>=<SID>ExpandStatement("\r")<CR>
inoremap <silent> <Plug>BackspaceHandler <C-R>=<SID>BackspaceHandler()<CR>

" Expand abbreviations next to cursor using:
" <Space><bs>
imap <buffer> <ESC> <Space><bs><Plug>ExpandStatementESC
imap <buffer> <CR> <Space><bs><Plug>ExpandStatementCR
imap <buffer> <BS> <BS><Plug>BackspaceHandler

iabb <expr> <buffer> is <SID>InComment() ? "is" : "==="
iabb <expr> <buffer> isnt <SID>InComment() ? "isnt" : "!=="
iabb <expr> <buffer> not <SID>InComment() ? "not" : "!"
iabb <expr> <buffer> and <SID>InComment() ? "and" : "&&"
iabb <expr> <buffer> or <SID>InComment() ? "or" : "\|\|"

function! s:SyntaxName(l, c, ...) "{{{
    let trans = a:0 > 0 ? a:1 : 0
    return synIDattr(synID(a:l, a:c, trans), 'name')
endfunction "}}}

function! s:FirstWord() "{{{
    let t = getline('.') =~ '^\w\+$'
    return t
endfunction "}}}

function! s:InFunction() "{{{
    let line = getline('.')
    return line =~ '\w\+\s*('
endfunction "}}}

function! s:InComment() " {{{
    let syn = s:SyntaxName(line('.'), col('.') - 1, 1)
    if syn =~? 'comment'
        return 1
    else
        return 0
    endif
endfunction "}}}

function! s:MatchDefineConst() "{{{
    let line = getline('.')
    return line =~ '^#define \w\+\s'
endfunction "}}}

function! s:MatchIf() "{{{
    let line = getline('.')
    return line =~ '^\s*if'
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

function! s:MatchSwitch() "{{{
    let line = getline('.')
    return line =~ '^\s\+switch'
endfunction "}}}

function! s:MatchCase() "{{{
    let line = getline('.')
    return line =~ '^\s\+\(case\|default\).*[^:]$'
endfunction "}}}

function! s:MatchSingleWordStatement() "{{{
    let line = getline('.')
    return line =~ '^\s\+\w\+$'
endfunction "}}}

function! s:MatchFunctionDefinition() "{{{
    let line = getline('.')
    return line =~ '^\S\+\s\+\S\+' &&
                \ line =~ '(.*)' &&
                \ line !~ '='
endfunction "}}}

function! s:MatchInclude() " {{{
    let line = getline('.')
    return line =~ '^#include\s\+\S\+\s*$' &&
                \ line !~ '\(<.*>\|".*"\)'
endfunction "}}}

function! s:EOL() "{{{
    if col('.') == col('$')
        return 1
    else
        return 0
    endif
endfunction "}}}

function! s:BlankLine() "{{{
    return getline('.') =~ '^\s*$'
endfunction "}}}

function! s:AlreadyEnded() "{{{
    let line = getline('.')
    return line =~ '[:;,&|({+\-*/%]$' &&
                \ line !~ '\(--\|++\)$' 
endfunction "}}}

function! s:Macro() "{{{
    return getline('.') =~ '^#'
endfunction "}}}

function! s:LocalFile(includeName) "{{{
    return glob(a:includeName) != ''
endfunction "}}}

function!  s:NextLineClosesDataStructure() "{{{
    " let nextLine = getline(line('.') + 1)
    let nextLine = getline(nextnonblank(line('.') + 1))
    return nextLine =~ '^};$'
endfunction "}}}

function! s:InsideEnum() "{{{
    let braceLine = s:InsideWhat()
    return braceLine =~ '^\s*enum'
endfunction "}}}

function! s:InsideDataStructure() "{{{
    let braceLine = s:InsideWhat()
    return braceLine =~ '\(enum\|union\|struct\)'
endfunction "}}}

function! s:InsideWhat() "{{{
    let saveCursor = getpos('.')
    " Search backwards to open brace that isn't in a string
    let prevBrace = searchpair('{', '', '}', 'bW', 'synIDattr(synID(line("."), col("."), 0), "name") =~? "string"')
    let braceLine = getline(prevBrace)
    call setpos('.', saveCursor)
    return braceLine
endfunction "}}}

function! s:EndLine(key) "{{{
    Log "EndLine " . a:key
    let eolChar = ';'
    let insideEnum = s:InsideEnum()
    if insideEnum
        let eolChar = ','
    endif

    if a:key == "\r"
        if s:InComment() || s:AlreadyEnded() || s:BlankLine() || s:Macro()
            Log a:key
            return a:key
        else
            Log eolChar . a:key
            return eolChar . a:key
        endif
    elseif a:key == "\e"
        if s:InComment() || s:AlreadyEnded() || s:BlankLine() || !s:EOL() || s:Macro() || (s:NextLineClosesDataStructure() && insideEnum)
            Log a:key
            return a:key
        else
            Log eolChar . a:key
            return eolChar . a:key
        endif
    endif
    Log 'unknown key ' . a:key
    return a:key
endfunction "}}}

function! s:ExpandStatement(key) "{{{
    Log "ExpandStatement " . a:key
    let line = getline('.')
    let mainAction = ""
    let endAction = ""
    if s:InComment()
        Log "match Comment"
    elseif line =~ ';$'
        Log "match ';$'"
    elseif s:MatchIf() "{{{
        Log "match if"
        let newLine = substitute(line, '^\(\s*\w\+\)\s\+\(.*\)$', '\1 (\2) {', '')
        call setline('.', newLine)
        let mainAction = "\eo}\ek"
        let endAction = "o"
        "}}}
    elseif s:MatchElse() "{{{
        Log "match else"
        let mainAction = "\ebC} else {"
        let endAction = "\r"
        "}}}
    elseif s:MatchElseIf() "{{{
        Log "match else if"
        let newLine = substitute(line, '^\(\s*\)else if\s\+\(.*\)$', '\1else if (\2) {', '')
        call setline('.', newLine)
        let mainAction =  "\eI} \e"
        let endAction =  "o"
        "}}}
    elseif s:MatchFor() "{{{
        Log "match for"
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
                    let newLine = lineIndent . "for (".iterator." = ".start."; ".iterator." < ".limit."; ".iterator." += ".step.") {"
                else
                    let newLine = lineIndent . "for (".iterator." = 0; ".iterator." < limit; ".iterator."++) {"
                endif
            else
                let newLine = substitute(line, '^\(\s*\w\+\)\s\+\(.*\)$', '\1 (\2) {', '')
            endif
        endif
        call setline('.', newLine)
        let mainAction = "\eo}\ek"
        let endAction = "o"
        " }}}
    elseif s:MatchWhile() "{{{
        Log "match while"
        if line =~ '^\s*while$'
            let newLine = substitute(line, '^\(\s*\w\+\)$', '\1 (1) {', '')
        else
            let newLine = substitute(line, '^\(\s*\w\+\)\s\+\(.*\)$', '\1 (\2) {', '')
        endif
        call setline('.', newLine)
        let mainAction = "\eo}\ek"
        let endAction = "o"
        "}}}
    elseif s:MatchDoWhile() "{{{
        Log "match do while"
        let newLine = substitute(line, '^\(\s*\w\+\).*$', '\1 {', '')
        let closeLine = substitute(line, '^\(\s*\)\w\+\s\+\w\+\s\+\(.*\)$', '\1} while (\2);', '')
        call setline('.', newLine)
        call append('.', closeLine)
        let endAction = "\eo"
        "}}}
    elseif s:MatchSwitch() "{{{
        Log "match switch"
        let newLine = substitute(line, '^\(\s*\w\+\)\s\+\(.*\)$', '\1 (\2) {', '')
        call setline('.', newLine)
        let mainAction = "\eodefault:\rbreak;\r}\ekkk"
        let endAction = "ocase "
        "}}}
    elseif s:MatchCase() " {{{
        let nextLine = getline(line('.')+1)
        if nextLine =~ '^\s\+break;'
            let mainAction = ":\eObreak;\ej"
        else
            let mainAction = ":\rbreak;\ek"
        endif
        let endAction = "o"
        "}}}
    " match structure initialization
    elseif line =~ '=\s*{{\s*$' "{{{
        Log "match initialization"
        let mainAction = "\eo};\ek"
        let endAction = "o"
        "}}}
    " match enum, struct or union
    elseif line =~ '\(enum\|struct\|union\)' && line !~ '[{}]$' && s:EOL() "{{{
        Log "match enum|struct|union"
        if line !~ 'enum\s*$'
            let typedefLine = substitute(line, '^\(\s*\)\(enum\|struct\|union\)\s\+\(\w\+\).*', '\1typedef \2 \3 \3;', '')
            call append(line('.') - 1, typedefLine)
        endif
        let mainAction = " {\eo};\r\ekk"
        let endAction = "o"
        "}}}
    " match include macro
    elseif s:MatchDefineConst() " {{{
        Log "match #define <CONST>"
        let newLine = substitute(line, '^\(#define \)\(\w\+\)\s', '\1\U\2 ', '')
        call setline('.', newLine)
        "}}}
    elseif s:MatchInclude() " {{{
        Log "match #include"
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
        let endAction = "\r"
        "}}}
    elseif s:MatchSingleWordStatement() && !s:InsideDataStructure() "{{{
        Log "match single word statement"
        Log line
        if line =~ '\(break\|continue\)'
            Log "break \| continue"
            let mainAction = ";"
        else
            Log "NOT break \| continue"
            let mainAction = "();"
        endif
        let endAction = "\r"
    "}}}
    elseif line =~ '^int main\(()\)\?$' "{{{
        Log "match int main"
        let newLine = substitute(line, '()$', '', '')
        call setline('.', newLine)
        let mainAction = "(int argc, char *argv[]) {\rreturn 0;\r}\ekk"
        let endAction = "o"
        "}}}
    elseif s:MatchFunctionDefinition() && s:EOL() "{{{
        Log "match function definition"
        let mainAction = " {\eo}\r\ekk"
        let endAction = "o"
        "}}}
    else "{{{
        Log 'unmatched ' . line
        "}}}
    endif

    Log "end if else switches"
    if mainAction == ""
        Log "mainAction empty"
        return s:EndLine(a:key)
    else
        Log "key " . a:key
        if a:key == "\r"
            return mainAction . endAction
        else
            return mainAction . "\e"
        endif
    endif
endfunction " }}}

function! s:BackspaceHandler() "{{{
    let line = getline('.')
    if line =~ "//$"
        call setline(line('.'), substitute(line,'\(.*\)//\s\?$','\1',''))
    endif
    return ""
endfunction "}}}

"  vim: fdm=marker
