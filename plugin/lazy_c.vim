
if exists("g:loaded_lazy_c") || &cp
    finish
endif
let g:loaded_lazy_c = 1

let s:pluginDir = expand("<sfile>:p:h:h")
let s:logging = 1

inoremap <silent> <Plug>ExpandStatementESC <C-R>=<SID>ExpandStatement("\e")<CR>
inoremap <silent> <Plug>ExpandStatementCR <C-R>=<SID>ExpandStatement("\r")<CR>
inoremap <silent> <Plug>BackspaceHandler <C-R>=<SID>BackspaceHandler()<CR>

function! s:log(str) "{{{
    if exists("s:logging")
        echom a:str
    endif
endfunction "}}}

function! lazy_c#mappings() "{{{
    " Expand abbreviations next to cursor using:
    " <Space><bs>
    imap <buffer> <ESC> <Space><bs><Plug>ExpandStatementESC
    imap <buffer> <CR> <Space><bs><Plug>ExpandStatementCR
    imap <buffer> <BS> <BS><Plug>BackspaceHandler

    iabb <expr> <buffer> is <SID>InComment() ? "is" : "=="
    iabb <expr> <buffer> isnt <SID>InComment() ? "isnt" : "!="
    iabb <expr> <buffer> not <SID>InComment() ? "not" : "!"
    iabb <expr> <buffer> and <SID>InComment() ? "and" : "&&"
    iabb <expr> <buffer> or <SID>InComment() ? "or" : "\|\|"

    iabb <expr> <buffer> null <SID>InComment() ? "null" : "NULL"
    iabb <expr> <buffer> eof <SID>InComment() ? "eof" : "EOF"

    iabb <expr> <buffer> include <SID>FirstWord() ? "#include" : "include"
    iabb <expr> <buffer> define <SID>FirstWord() ? "#define" : "define"
    iabb <expr> <buffer> ifndef <SID>FirstWord() ? "#ifndef" : "ifndef"
    iabb <expr> <buffer> undef <SID>FirstWord() ? "#undef" : "undef"
    iabb <expr> <buffer> if <SID>FirstWord() ? "#if" : "if"
    iabb <expr> <buffer> else <SID>FirstWord() ? "#else" : "else"
    if exists("s:logging")
        command! -nargs=1 Log call <SID>log(<args>)
    endif
endfunction "}}}

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
    return getline('.') =~ '[;,&|({+\-*/%]$'
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
        let mainAction = "\eo}\e"
        let endAction = "O"
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
        let mainAction = "\eo}\e"
        let endAction = "O"
        " }}}
    elseif s:MatchWhile() "{{{
        Log "match while"
        if line =~ '^\s*while$'
            let newLine = substitute(line, '^\(\s*\w\+\)$', '\1 (1) {', '')
        else
            let newLine = substitute(line, '^\(\s*\w\+\)\s\+\(.*\)$', '\1 (\2) {', '')
        endif
        call setline('.', newLine)
        let mainAction = "\eo}\e"
        let endAction = "O"
        "}}}
    elseif s:MatchDoWhile() "{{{
        Log "match do while"
        let newLine = substitute(line, '^\(\s*\w\+\).*$', '\1 {', '')
        let closeLine = substitute(line, '^\(\s*\)\w\+\s\+\w\+\s\+\(.*\)$', '\1} while (\2);', '')
        call setline('.', newLine)
        call append('.', closeLine)
        let endAction = "\eo"
        "}}}
    " match structure initialization
    elseif line =~ '=\s*{{\s*$'
        Log "match initialization"
        let mainAction = "\eo};\e"
        let endAction = "O"
    " match enum, struct or union
    elseif line =~ '\(enum\|struct\|union\)' && line !~ '[{}]$' && s:EOL()
        Log "match enum|struct|union"
        if line !~ 'enum\s*$'
            let typedefLine = substitute(line, '^\(\s*\)\(enum\|struct\|union\)\s\+\(\w\+\).*', '\1typedef \2 \3 \3;', '')
            call append(line('.') - 1, typedefLine)
        endif
        let mainAction = " {\eo};\r\ek"
        let endAction = "O"
    " match include macro
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
        let mainAction = "();"
        let endAction = "\r"
    "}}}
    elseif line =~ '^int main\(()\)\?$' "{{{
        Log "match int main"
        let mainAction = "(int argc, char *argv[]) {\eo}\r\ek"
        let endAction = "O"
        "}}}
    elseif s:MatchFunctionDefinition() && s:EOL() "{{{
        Log "match function definition"
        let mainAction = " {\eo}\r\ek"
        let endAction = "O"
        "}}}
    else
        Log 'unmatched ' . line
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

" ==================================================
" Testing Functions

function! s:ClearBuffer()
    normal ggdG
endfunction

function! s:GetBuffer()
    return getline(0, line('$'))
endfunction

function! s:puts(str)
    call append(line('$'), a:str)
endfunction

function! s:eputs(name, str)
    let lines = []
    for line in a:str
        call add(lines, substitute(line, ' ', '·', 'g'))
    endfor
    call append(line('$'), a:name)
    call append(line('$'), lines)
    call append(line('$'), "end".a:name)
endfunction

function! lazy_c#test()
    set filetype=c
    let successCount = 0
    let failCount = 0
    let failed = []
    for f in split(glob( s:pluginDir . "/tests/*.txt"), "\n")
        let input = []
        let expectedOutput = []
        let splitFound = 0
        for line in readfile(f)
            if line == "%"
                let splitFound = 1
            elseif splitFound == 0
                call add(input, line)
            else
                call add(expectedOutput, line)
            endif
        endfor
        let [result, output] = s:RunTest(input, expectedOutput)
        if result == 1
            let successCount += 1
        else
            call add(failed, [f, input, expectedOutput, output])
            let failCount += 1
        endif
    endfor

    call s:ClearBuffer()
    call setline(1, "Lazy C Tests")
    call s:puts(strftime("%c"))
    call s:puts("")
    if len(failed)
        call s:puts("fails:")
        for fail in failed
            let [f, input, expectedOutput, output] = fail
            call s:puts(f)
            call s:eputs("input", input)
            call s:eputs("expectedOutput", expectedOutput)
            call s:eputs("output", output)
            call s:puts("")
        endfor
        call s:puts("")
    endif
    call s:puts("failed: " . failCount)
    call s:puts("succeeded: " . successCount)
    call s:puts("total: " . (failCount + successCount))
    write! lazy_c_test.txt
    exit
endfunction

function! s:RunTest(input, expectedOutput)
    call s:ClearBuffer()
    execute "normal i" . substitute(substitute(substitute(join(a:input, "\r"),
    \ '<BS>',"\<BS>",'g'),
    \ '<ESC>', "\<ESC>", 'g'),
    \ '<LEFT>', "\<LEFT>", 'g')
    let buffer = getline(0, line('$'))
    return [buffer == a:expectedOutput, buffer]
endfunction

"  vim: fdm=marker
