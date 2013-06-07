if !hasmapto('<Plug>MsTestTestMethod')
	map <buffer> <unique> <LocalLeader>tm <Plug>MsTestTestMethod
endif
if !hasmapto('<Plug>MsTestTestClass')
	map <buffer> <unique> <LocalLeader>tc <Plug>MsTestTestClass
endif
if !hasmapto('<Plug>MsTestTestAssembly')
	map <buffer> <unique> <LocalLeader>ta <Plug>MsTestTestAssembly
endif
noremap <buffer> <Plug>MsTestTestMethod :MsTestTestMethod<CR>
noremap <buffer> <Plug>MsTestTestClass :MsTestTestClass<CR>
noremap <buffer> <Plug>MsTestTestAssembly :MsTestTestAssembly<CR>

if !exists(":MsTestTestMethod")
	command -buffer MsTestTestMethod :call MsTestTestMethod()
endif
if !exists(":MsTestTestClass")
	command -buffer MsTestTestClass :call MsTestTestClass()
endif
if !exists(":MsTestTestAssembly")
	command -buffer MsTestTestAssembly :call MsTestTestAssembly()
endif

let s:xsltfile = expand("<sfile>:p:h:h")."/MsTest2Simple.xslt"
let s:namespaceRegex = 'namespace\s\+\zs[a-zA-Z0-9-.]*'
let s:classRegex = '^\s*\[TestClass\]\s*\n\(\s\|\w\)*\s\+class\s*\zs[a-zA-Z0-9_]*'
let s:methodRegex = '^\s*\[TestMethod\]\s*\n\(\s\|\w\|[<>]\)*\s\+\zs[a-zA-Z0-9_]*\ze('

function! MsTestTestClass() range
	let [l:namespace, l:class, l:method] = s:GetTest()
	let l:test = l:namespace.'.'.l:class
	return s:RunTest(l:test)
endfunction

function! MsTestTestMethod() range
	let [l:namespace, l:class, l:method] = s:GetTest()
	let l:test = l:namespace.'.'.l:class.'.'.l:method
	return s:RunTest(l:test)
endfunction

function! MsTestTestAssembly() range
	let l:test = s:GetContainerName()
	return s:RunTest(l:test)
endfunction

function! s:PreTestMake()
	make
	if !empty(getqflist())
		let l:continueAnyway = confirm("Make failed, continue anyway?", "&Yes\n&No", 1, "Question")
		if l:continueAnyway == 1
			return 0
		else
			return -1
		endif
	endif
	return 0
endfunction

function! s:GetTest()
	let l:oldview = winsaveview()
	try
		let l:found = search(s:classRegex, "Wbcn")
		if l:found <= 0
			let l:found = search(s:classRegex, "wbc")
			call cursor(l:found)
		endif

		let l:namespace = s:FindMatch(s:namespaceRegex)
		let l:class = s:FindMatch(s:classRegex)
		let l:method = s:FindMatch(s:methodRegex)

		return [l:namespace, l:class, l:method]
	finally
		call winrestview(l:oldview)
	endtry
endfunction

function! s:GetContainerName()
	let l:container = glob("*.Tests", 0, 1)
	if (empty(l:container))
		let l:container = glob("*.Test", 0, 1)
	endif
	return l:container[0]
endfunction

function! s:SortFileByMod(a, b)
	let l:aT = getftime(a:a)
	let l:bT = getftime(a:b)
	return l:aT == l:bT ? 0 : l:aT < l:bT ? 1 : -1
endfunction

function! s:RunTest(test)
	let l:pretestResult = s:PreTestMake()
	if l:pretestResult != 0
		return 0
	endif

	let l:testResultFile = "TestResults.trx"

	let l:containerName = s:GetContainerName()
	let l:containerDlls = glob(l:containerName."/**/".l:containerName.".dll", 0, 1)
	let l:containerDll = (sort(l:containerDlls, "s:SortFileByMod"))[0]
	let l:containerPath = '../'.l:containerDll

	echo "Testing [" a:test "][" l:containerPath "]"
	"redraw | echo "[" l:namespace "] [" l:class "] [" l:method "] [" l:test "]" | sleep 1

	let l:cwd = getcwd()
	let l:containerDir = "MsTestContainer"
	if !len(glob(l:containerDir, 1, 1))
		call mkdir(l:containerDir)
	endif
	execute "cd ".l:containerDir
	try
		if filereadable(l:testResultFile)
			call delete(l:testResultFile)
		endif
		let l:shellcommand = "mstest.exe /testcontainer:".l:containerPath." /resultsfile:".l:testResultFile." /test:".a:test
		let l:mstextout = system(l:shellcommand)
		if !filereadable(l:testResultFile)
			echo "Error[".v:shell_error."] [".l:mstextout.']'
			return -2
		endif
		call system("rm -r $USER'_'$COMPUTERNAME''*")
		"botright new
		"setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile wrap
		"execute "r!xsltproc.exe -o - ".s:xsltfile." ".l:testResultFile
		"execute "!xsltproc.exe -o - ".s:xsltfile." ".l:testResultFile
		"let l:traces = matchlist(l:result, "in \\(.*\\):line \\(\\d\\+\\)")
		"echo "[" l:traces "]"
		"echo "[" l:file "][" l:line "]"
		let l:testResultText = system("xsltproc.exe -o - ".s:xsltfile." ".l:testResultFile)
		let l:testResults = s:ParseTestResult(l:testResultText)
		if !empty(l:testResults)
			if setqflist(l:testResults) != 0
				throw "Setting quickfix list failed"
			endif
			"echo l:testResults
			do QuickFixCmdPost make
			cfirst
		else
			echo l:testResultText
		endif
	finally
		execute "cd ".l:cwd
	endtry
endfunction

function! s:ParseTestResult(testResultText)
	let l:testResultLines = split(a:testResultText, "\n")
	let l:testResults = []
	let l:testResult = {}
	"echo l:testResultLines
	for l:line in l:testResultLines
		if match(l:line, '^\(Total\|Failed\|Passed\):') >= 0
			"echo "Skipping ".l:line
		elseif match(l:line, '^T:') >= 0
			if (!empty(l:testResult))
				let l:testResult["text"] = l:testResult["test"].' '.l:testResult["output"].': '.l:testResult["message"]
				call insert(l:testResults, l:testResult)
			endif
			let l:testResult = {}
			let l:testName = matchlist(l:line, '^T: \(\w\+\)\s\(\w\+\)$')
			if !empty(l:testName)
				let l:testResult["test"] = l:testName[1]
				let l:testResult["output"] = l:testName[2]
			else
				throw 'Could not parse ['.l:line.'] for test/result'
			endif
		else
			let l:testOutput = matchlist(l:line, '^\s*\(Message\|Stacktrace\): \(.*\)$')
			if (!empty(l:testOutput))
				if l:testOutput[1] == "Message"
					let l:testResult["message"] = l:testOutput[2]
				elseif l:testOutput[1] == "Stacktrace"
					let l:testStack = matchlist(l:testOutput[2], '.*in \([a-zA-Z]\?:\?[^:]*\):line \(\d*\)$')
					if !empty(l:testStack)
						let l:testResult["filename"] = l:testStack[1]
						let l:testResult["lnum"] = l:testStack[2]
					else
						throw 'Could not parse ['.l:testOutput[2].'] for file/line'
					endif
				else
					throw "Matched ".l:testOutput[1]."!?!"
				endif
			else
				"echo "Couldn't match ".l:line
			endif
		endif
	endfor

	if (!empty(l:testResult))
		let l:testResult["text"] = l:testResult["test"].' '.l:testResult["output"].': '.l:testResult["message"]
		call insert(l:testResults, l:testResult)
	endif
	return l:testResults
endfunc

function! s:FindMatch(regex)
	let l:oldview = winsaveview()
	try
		let l:found = search(a:regex, "Wbc")
		"redraw | echo "[" a:regex "] [" l:found "]" | sleep 1
		let l:result = ""
		let l:line = ""
		if l:found > 0
			let l:line = getline(line('.')-1)."\n".getline('.')
			let l:result = matchstr(l:line, a:regex)
		endif
		"redraw | echo "[" l:result "] [" l:line "]" | sleep 1
		return l:result

	finally
		call winrestview(l:oldview)
	endtry

endfunction
