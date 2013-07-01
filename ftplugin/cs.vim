if !hasmapto('<Plug>CsTestTestMethod')
	map <buffer> <unique> <LocalLeader>tm <Plug>CsTestTestMethod
endif
if !hasmapto('<Plug>CsTestTestClass')
	map <buffer> <unique> <LocalLeader>tc <Plug>CsTestTestClass
endif
if !hasmapto('<Plug>CsTestTestAssembly')
	map <buffer> <unique> <LocalLeader>ta <Plug>CsTestTestAssembly
endif
noremap <buffer> <Plug>CsTestTestMethod :CsTestTestMethod<CR>
noremap <buffer> <Plug>CsTestTestClass :CsTestTestClass<CR>
noremap <buffer> <Plug>CsTestTestAssembly :CsTestTestAssembly<CR>

if !exists(":CsTestTestMethod")
	command -buffer CsTestTestMethod :call CsTestTestMethod()
endif
if !exists(":CsTestTestClass")
	command -buffer CsTestTestClass :call CsTestTestClass()
endif
if !exists(":CsTestTestAssembly")
	command -buffer CsTestTestAssembly :call CsTestTestAssembly()
endif

let s:mstestXsltFile = expand("<sfile>:p:h:h")."/MsTest2Simple.xslt"
let s:nunitXsltFile = expand("<sfile>:p:h:h")."/NUnit2Simple.xslt"
let s:mstestExe = "mstest.exe"
let s:nunitExe = "/C/Program\ Files\ \(x86\)/NUnit\ 2.6.2/bin/nunit-console-x86.exe"
let s:namespaceRegex = 'namespace\s\+\zs[a-zA-Z0-9-.]*'
let s:nunitTestRegex = '\_^\s*using\s*NUnit'

let s:mstestClassRegex = '\_^\s*\[TestClass\]\s*\n\(\s\|\w\)*\s\+class\s*\zs[a-zA-Z0-9_]*'
let s:mstestMethodRegex = '\_^\s*\[TestMethod\]\s*\n\(\s\|\w\|[<>]\)*\s\+\zs[a-zA-Z0-9_]*\ze('

let s:nunitClassRegex = '\_^\s*\[TestFixture\]\s*\n\(\s\|\w\)*\s\+class\s*\zs[a-zA-Z0-9_]*'
let s:nunitMethodRegex = '\_^\s*\[Test\]\s*\n\%(\s*\[Explicit\]\s*\n\)\?\(\s\|\w\|[<>]\)*\s\+\zs[a-zA-Z0-9_]*\ze('

function! CsTestTestClass() range
	let [l:namespace, l:class, l:method] = s:GetTest()
	let l:test = l:namespace.'.'.l:class
	return CsTestRunTest(l:test)
endfunction

function! CsTestTestMethod() range
	let [l:namespace, l:class, l:method] = s:GetTest()
	let l:test = l:namespace.'.'.l:class.'.'.l:method
	return CsTestRunTest(l:test)
endfunction

function! CsTestTestAssembly() range
	let l:test = s:GetContainerName()
	return CsTestRunTest(l:test)
endfunction

function! s:PreTestMake()
	make
	if !empty(getqflist())
		let l:continueAnyway = confirm("Make failed, continue anyway?", "&Yes\n&No", 2, "Question")
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
		let l:testStyle = s:FindTestStyle()
		"echo "TestStyle:" . l:testStyle | sleep 1
		let l:classRegex = ""
		let l:methodRegex = ""
		if l:testStyle == "mstest"
			let l:classRegex = s:mstestClassRegex
			let l:methodRegex = s:mstestMethodRegex
		elseif l:testStyle == "nunit"
			let l:classRegex = s:nunitClassRegex
			let l:methodRegex = s:nunitMethodRegex
		else
			throw "Unknown test style"
		endif

		let l:found = search(l:classRegex, "Wbcn")
		if l:found <= 0
			let l:found = search(l:classRegex, "wbc")
			call cursor(l:found)
		endif

		let l:namespace = s:FindMatch(s:namespaceRegex)
		let l:class = s:FindMatch(l:classRegex)
		let l:method = s:FindMatch(l:methodRegex)

		return [l:namespace, l:class, l:method]
	finally
		call winrestview(l:oldview)
	endtry
endfunction

function! s:FindTestStyle()
	let l:oldview = winsaveview()
	try
		call cursor('$')
		let l:found = search(s:nunitTestRegex, "Wbcn")
		if l:found <= 0
			return "mstest"
		else
			return "nunit"
		endif
	finally
		call winrestview(l:oldview)
	endtry

endfunction

function! s:GetContainerName()
	let l:container = glob("*.Tests", 0, 1)
	if (empty(l:container))
		let l:container = glob("*.Test", 0, 1)
	endif
	if (empty(l:container))
		let l:container = glob("*/*.Test", 0, 1)
		call map(l:container, 'substitute(v:val, "[^/]*/", "", "")')
	endif
	if (empty(l:container))
		let l:container = glob("*/*.Tests", 0, 1)
		call map(l:container, 'substitute(v:val, "[^/]*/", "", "")')
	endif
	return l:container[0]
endfunction

function! s:SortFileByMod(a, b)
	let l:aT = getftime(a:a)
	let l:bT = getftime(a:b)
	return l:aT == l:bT ? 0 : l:aT < l:bT ? 1 : -1
endfunction

function! CsTestRunTest(test)
	let l:pretestResult = s:PreTestMake()
	if l:pretestResult != 0
		return 0
	endif

	let l:containerName = s:GetContainerName()
	"redraw | echo "[" l:containerName "]" | sleep 1
	let l:containerDlls = glob(l:containerName."/**/".l:containerName.".dll", 0, 1)
	if empty(l:containerDlls)
		let l:containerDlls = glob('*/'.l:containerName."/**/".l:containerName.".dll", 0, 1)
	endif
	let l:containerDll = (sort(l:containerDlls, "s:SortFileByMod"))[0]
	let l:containerPath = '../'.l:containerDll

	echo "Testing [" a:test "][" l:containerPath "]"
	"redraw | echo "[" l:namespace "] [" l:class "] [" l:method "] [" l:test "]" | sleep 1

	let l:cwd = getcwd()
	let l:containerDir = "TestContainer"
	if !len(glob(l:containerDir, 1, 1))
		call mkdir(l:containerDir)
	endif
	execute "cd ".l:containerDir

	try
		let l:testResultFile = "TestResults.xml"

		if filereadable(l:testResultFile)
			call delete(l:testResultFile)
		endif

		let l:shellcommand = "false"
		let l:xsltfile = ""

		let l:testStyle = s:FindTestStyle()
		if l:testStyle == "mstest"
			let l:shellcommand = s:mstestExe." /testcontainer:".l:containerPath." /resultsfile:".l:testResultFile." /test:".a:test
			let l:xsltfile = s:mstestXsltFile
		elseif l:testStyle == "nunit"
			let l:shellcommand = 'TMP= TEMP= '.shellescape(s:nunitExe)." ".l:containerPath." /result ".l:testResultFile." /run ".a:test
			let l:xsltfile = s:nunitXsltFile
		else
			throw "Unknown test style"
		endif

		"redraw | echo "Command: " l:shellcommand | sleep 3

		let l:mstextout = system(l:shellcommand)

		"redraw | echo "Out: " l:mstextout | sleep 3

		if !filereadable(l:testResultFile)
			echo "Error[".v:shell_error."] [".l:mstextout.']'
			return -2
		endif

		if l:testStyle == "mstest"
			call system("rm -r $USER'_'$COMPUTERNAME''*")
		endif

		"let l:traces = matchlist(l:result, "in \\(.*\\):line \\(\\d\\+\\)")
		"echo "[" l:traces "]"
		"echo "[" l:file "][" l:line "]"

		let l:testResultText = system("xsltproc.exe -o - ".l:xsltfile." ".l:testResultFile)
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
				let l:testResult["text"] = l:testResult["test"].' '.l:testResult["result"]
				if (has_key(l:testResult, 'message'))
					let l:testResult["text"] = l:testResult["text"].': '.l:testResult["message"]
				endif
				call insert(l:testResults, l:testResult)
			endif
			let l:testResult = {}
			let l:testName = matchlist(l:line, '^T: \([A-Za-z0-9_.-]\+\)\s\(\w\+\)$')
			if !empty(l:testName)
				let l:testResult["test"] = l:testName[1]
				let l:testResult["result"] = l:testName[2]
			else
				throw 'Could not parse ['.l:line.'] for test/result'
			endif
		else
			let l:testOutput = matchlist(l:line, '^\s*\(Message\|Stacktrace\): \(.*\)$')
			if (!empty(l:testOutput))
				if l:testOutput[1] == "Message"
					let l:testResult["message"] = l:testOutput[2]
				elseif l:testOutput[1] == "Stacktrace"
					echo "Matching [".l:testOutput[2].']' | sleep 2
					let l:testStack = matchlist(l:testOutput[2], '^.\{-}in \([a-zA-Z]\?:\?[^:]*\):line \(\d*\)')
					echo "Matched [".string(l:testStack).']' | sleep 2
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
		let l:testResult["text"] = l:testResult["test"].' '.l:testResult["result"]
		if (has_key(l:testResult, 'message'))
			let l:testResult["text"] = l:testResult["text"].': '.l:testResult["message"]
		endif
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
		let l:count = 0
		if l:found > 0
			while empty(l:result) && l:count < 10
				let l:line = getline(line('.')-l:count)."\n".l:line
				let l:result = matchstr(l:line, a:regex)
				let l:count = l:count + 1
			endwhile
		endif
		"redraw | echo "[" l:result "] [" l:line "]" | sleep 1
		return l:result

	finally
		call winrestview(l:oldview)
	endtry

endfunction
