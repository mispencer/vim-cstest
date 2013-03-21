if !hasmapto('<Plug>MsTestRunTest')
	map <buffer> <unique> <LocalLeader>t <Plug>MsTestRunTest
endif
noremap <buffer> <Plug>MsTestRunTest :MsTestRunTest<CR>

if !exists(":MsTestRunTest") 
	command -buffer MsTestRunTest :call <SID>MsTestRunTest()
endif

let s:xsltfile = expand("<sfile>:p:h:h")."/MsTest2Simple.xslt"

function! GetTest()
	let l:namespace = s:FindMatch('namespace\s\+\zs[a-zA-Z0-9-.]*')
	let l:class = s:FindMatch('^\s*\[TestClass\]\s*\n\(\s\|\w\)*\s\+class\s*\zs[a-zA-Z0-9_]*')
	let l:method = s:FindMatch('^\s*\[TestMethod\]\s*\n\(\s\|\w\|[<>]\)*\s\+\zs[a-zA-Z0-9_]*\ze(')
	let l:test = l:namespace.'.'.l:class.'.'.l:method
	return l:test
endfunction

function! s:MsTestRunTest() range
	make
	if !empty(getqflist()) 
		return
	endif
	let l:test = GetTest()

	echo "Testing [" l:test "]"
	"redraw | echo "[" l:namespace "] [" l:class "] [" l:method "] [" l:test "]" | sleep 1
	
	let l:testResultFile = "TestResult.trx"

	let l:containerName = glob("*.Tests")
	let l:containerPath = l:containerName.'/bin/Local/'.l:containerName.'.dll'
	"redraw | echo "[" l:containerName "] [" l:containerPath "]"

	if filereadable(l:testResultFile)
		call delete(l:testResultFile)
	endif
	let l:shellcommand = "mstest.exe /testcontainer:".l:containerPath." /resultsfile:".l:testResultFile."  /test:".l:test
	call system(l:shellcommand)
	"botright new
	"setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile wrap
	"execute "r!xsltproc.exe -o - ".s:xsltfile." ".l:testResultFile
	execute "!xsltproc.exe -o - ".s:xsltfile." ".l:testResultFile
	"let l:traces = matchlist(l:result, "in \\(.*\\):line \\(\\d\\+\\)")
	"echo "[" l:traces "]"
	"echo "[" l:file "][" l:line "]"
endfunction

function! s:FindMatch(regex)
	let l:oldview = winsaveview()
	let l:found = search(a:regex, "Wbc")
	"redraw | echo "[" a:regex "] [" l:found "]" | sleep 1
	let l:result = ""
	let l:line = ""
	if l:found > 0
		let l:line = getline(line('.')-1)."\n".getline('.')
		let l:result = matchstr(l:line, a:regex)
	endif
	"redraw | echo "[" l:result "] [" l:line "]" | sleep 1

	call winrestview(l:oldview)

	return l:result
endfunction
