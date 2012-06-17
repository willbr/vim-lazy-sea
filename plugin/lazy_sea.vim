
if exists("g:loaded_lazy_sea") || &cp
    finish
endif
let g:loaded_lazy_sea = 1

let s:pluginDir = expand("<sfile>:p:h:h")
let s:logging = 1

function! s:log(str) "{{{
    if exists("s:logging")
        echom a:str
    endif
endfunction "}}}

command! -nargs=1 Log call <SID>log(<args>)

function! lazy_sea#test() "{{{
    let s:successCount = 0
    let s:failCount = 0
    let s:failed = []
    let s:debugMessages = []

    for f in filter(split(glob( s:pluginDir . "/tests/*"), "\n"), 'isdirectory(v:val)')
        call s:ParseTestDir(f)
    endfor

    call s:ClearBuffer()
    call setline(1, "Lazy C Tests")
    call s:puts(strftime("%c"))
    call s:puts("")
    if len(s:failed)
        call s:puts("fails:")
        for fail in s:failed
            let [f, input, expectedOutput, output] = fail
            call s:puts(f)
            call s:eputs("input", input)
            call s:eputs("expectedOutput", expectedOutput)
            call s:eputs("output", output)
            call s:puts("")
        endfor
        call s:puts("")
    endif
    call s:puts("failed: " . s:failCount)
    call s:puts("succeeded: " . s:successCount)
    call s:puts("total: " . (s:failCount + s:successCount))

    if len(s:debugMessages)
        call s:puts("")
        for line in s:debugMessages
            call s:puts(line)
        endfor
    endif

    write! lazy_sea_test.txt
    exit
endfunction "}}}

" Testing Functions {{{

function! s:ClearBuffer() "{{{
    normal ggdG
endfunction "}}}

function! s:GetBuffer() "{{{
    return getline(0, line('$'))
endfunction "}}}

function! s:puts(str) "{{{
    call append(line('$'), a:str)
endfunction "}}}

function! s:eputs(name, str) "{{{
    let lines = []
    for line in a:str
        call add(lines, substitute(line, ' ', '·', 'g'))
    endfor
    call append(line('$'), a:name)
    call append(line('$'), lines)
    call append(line('$'), "end".a:name)
endfunction "}}}


function! s:ParseTestDir(folder) "{{{
    let filetype = substitute(a:folder, '.*/\(.*\)$', '\1', '')
    exec "setfiletype " . filetype
    for f in split(glob( a:folder . "/*.txt"), "\n")
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
            let s:successCount += 1
        else
            call add(s:failed, [f, input, expectedOutput, output])
            let s:failCount += 1
        endif
    endfor
endfunction "}}}

function! s:debugLog(msg) "{{{
    call add(s:debugMessages, a:msg)
endfunction "}}}

function! s:RunTest(input, expectedOutput) "{{{
    call s:ClearBuffer()
    execute "normal i" . substitute(substitute(substitute(join(a:input, "\r"),
    \ '<BS>',"\<BS>",'g'),
    \ '<ESC>', "\<ESC>", 'g'),
    \ '<LEFT>', "\<LEFT>", 'g')
    let buffer = getline(0, line('$'))
    return [buffer ==# a:expectedOutput, buffer]
endfunction "}}}

"}}}

"  vim: fdm=marker
