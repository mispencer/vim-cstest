if !hasmapto('<Plug>CsTestTestMethod')
	map <buffer> <unique> <LocalLeader>tm <Plug>CsTestTestMethod
endif
if !hasmapto('<Plug>CsTestTestClass')
	map <buffer> <unique> <LocalLeader>tc <Plug>CsTestTestClass
endif
if !hasmapto('<Plug>CsTestTestAssembly')
	map <buffer> <unique> <LocalLeader>ta <Plug>CsTestTestAssembly
endif
if !hasmapto('<Plug>CsTestTestSolution')
	map <buffer> <unique> <LocalLeader>ts <Plug>CsTestTestSolution
endif
if !hasmapto('<Plug>CsTestSplitTestFile')
	map <buffer> <unique> <LocalLeader>tf <Plug>CsTestSplitTestFile
endif
if !hasmapto('<Plug>CsTestSplitInterfaceFile')
	map <buffer> <unique> <LocalLeader>ti <Plug>CsTestSplitInterfaceFile
endif
noremap <buffer> <Plug>CsTestTestMethod :CsTestTestMethod<CR>
noremap <buffer> <Plug>CsTestTestClass :CsTestTestClass<CR>
noremap <buffer> <Plug>CsTestTestAssembly :CsTestTestAssembly<CR>
noremap <buffer> <Plug>CsTestTestSolution :CsTestTestSolution<CR>
noremap <buffer> <Plug>CsTestSplitTestFile :CsTestSplitTestFile<CR>
noremap <buffer> <Plug>CsTestSplitInterfaceFile :CsTestSplitInterfaceFile<CR>

if !exists(":CsTestTestMethod")
	command -buffer CsTestTestMethod :call CsTestTestMethod()
endif
if !exists(":CsTestTestClass")
	command -buffer CsTestTestClass :call CsTestTestClass()
endif
if !exists(":CsTestTestAssembly")
	command -buffer CsTestTestAssembly :call CsTestTestAssembly()
endif
if !exists(":CsTestTestSolution")
	command -buffer CsTestTestSolution :call CsTestTestSolution()
endif
if !exists(":CsTestSplitTestFile")
	command -buffer CsTestSplitTestFile :exec 'below' 'new' fnameescape(s:GetTestFile())
endif
if !exists(":CsTestSplitInterfaceFile")
	command -buffer CsTestSplitInterfaceFile :exec 'above' 'new' fnameescape(s:GetInterfaceFile())
endif

if !exists("g:CsTestMstestCategoryFilter")
	let g:CsTestMstestCategoryFilter = ""
endif

if !exists("g:CsTestNunitCategoryFilter")
	let g:CsTestNunitCategoryFilter = ""
endif

if !exists("g:CsTestXunitCategoryFilter")
	let g:CsTestXunitCategoryFilter = ""
endif

if (exists('g:cstestRunning') && g:cstestRunning == 1)
	finish
endif
let g:cstestRunning = 0

if !exists("g:CsTest_ContainerCache")
	let g:CsTest_ContainerCache = {}
endif

if !exists("g:CsTest_DllCache")
	let g:CsTest_DllCache = {}
endif

if !exists("g:CsTest_CsProjValueCache")
	let g:CsTest_CsProjValueCache = {}
endif

function CsTestClearCache()
	let g:CsTest_DllCache = {}
	let g:CsTest_ContainerCache = {}
	let g:CsTest_DllCache = {}
	let g:CsTest_CsProjValueCache = {}
endfunction

let s:mstestXsltFile = expand("<sfile>:p:h:h")."/MsTest2Simple.xslt"
let s:nunitXsltFile = expand("<sfile>:p:h:h")."/NUnit2Simple.xslt"
let s:xunitXsltFile = expand("<sfile>:p:h:h")."/XUnit2Simple.xslt"
let s:xsltWindowScript = expand("<sfile>:p:h:h")."/xslt.ps1"
let s:mstestExe = "mstest.exe"
let s:nunitExe = "nunit3-console.exe"
let s:xunitExe = "Xunit-console.exe"
let s:namespaceRegex = 'namespace\s\+\zs[a-zA-Z0-9_.-]*'
let s:xunitTestRegex = '\_^\s*using\s*Xunit'
let s:nunitTestRegex = '\_^\s*using\s*NUnit'
let s:mstestTestRegex = '\_^\s*using\s*Microsoft.VisualStudio.TestTools.UnitTesting'

let s:mstestClassRegex = '\_^\s*\[TestClass\]\s*\n\(\s\|\w\)*\s\+class\s*\zs[a-zA-Z0-9_]*'
let s:mstestMethodRegex = '\_^\s*\[TestMethod\]\s*\n\(\s*\/*\[TestCategory\(([^)]*)\)\?\]\s*\n\)\?\(\s\|\w\|[<>]\)*\s\+\zs[a-zA-Z0-9_]*\ze('

let s:nunitClassRegex = '\_^\s*\[TestFixture\]\s*\n\(\s\|\w\)*\s\+class\s*\zs[a-zA-Z0-9_]*'
let s:nunitMethodRegex = '\_^\s*\[\%(Test\|Theory\)\]\s*\n\%(\s*\/*\[Explicit\]\s*\n\)\?\(\s\|\w\|[<>]\)*\s\+\zs[a-zA-Z0-9_]*\ze('

let s:xunitClassRegex = '\_^\(\s\|\w\)*\s\+class\s*\zs[a-zA-Z0-9_]*'
let s:xunitMethodRegex = '\_^\s*\[\%(Fact\|Theory\)\]\s*\n\(\s\|\w\|[<>]\)*\s\+\zs[a-zA-Z0-9_]*\ze('

function! CsTestTestClass() range
	let [l:namespace, l:class, l:method] = s:GetTest()
	let l:test = l:namespace.'.'.l:class
	return CsTestRunTest(expand('%'), l:test)
endfunction

function! CsTestTestMethod() range
	let [l:namespace, l:class, l:method] = s:GetTest()
	let l:test = l:namespace.'.'.l:class.'.'.l:method
	return CsTestRunTest(expand('%'), l:test)
endfunction

function! CsTestTestAssembly() range
	let l:namespaces = s:GetCsProjValues(expand('%'), "RootNamespace")
	return call('CsTestRunTest', [expand('%')] + l:namespaces)
endfunction

function! CsTestTestSolution() range
	let l:namespaces = s:GetCsProjValues("", "RootNamespace")
	return call('CsTestRunTest', [""] + l:namespaces)
endfunction

function! CsTestGetTestFile()
	return s:GetTestFile()
endfunction

function! CsTestGetInterfaceFile()
	return s:GetInterfaceFile()
endfunction

function! s:PreTestMake(file)
	let l:oldview = winsaveview()
	let l:projectPaths = s:GetContainerProjectPaths(a:file)
	if (len(l:projectPaths) == 1) 
		execute("make ".join(map(l:projectPaths, "fnameescape(v:val)"), " "))
	else
		make
	endif
	if !empty(getqflist())
		let l:continueAnyway = confirm("Make failed, continue anyway?", "&Yes\n&No", 2, "Question")
		if l:continueAnyway != 1
			return -1
		endif
	endif
	call winrestview(l:oldview)
	return 0
endfunction

function! s:GetTestClass(line, classRegex, existingIndent)
	let l:oldview = winsaveview()
	try
		let l:currentLine = a:line
		let l:loopCount = 0
		while l:loopCount < 100
			call cursor(l:currentLine, 0)
			let l:parentFound = search(a:classRegex, "Wbcn")
			"redraw | echo "CurrentLine: [" l:currentLine "], ParentFound: [" l:parentFound "]" | sleep 1
			if l:parentFound > 0
				let l:matchLineCount = s:FindMatchLineCount(a:classRegex)
				"redraw | echo "MatchLineCount: [" l:matchLineCount "]" | sleep 1
				let l:newIndent = indent(l:parentFound)
				"redraw | echo "Line: [" a:line "][" l:parentFound "]" | sleep 1
				"redraw | echo "Indent: [" a:existingIndent "][" l:newIndent "]" | sleep 1
				if (l:newIndent < a:existingIndent)
					let l:class = s:FindMatch(a:classRegex)
					let l:grandparentTestClass = s:GetTestClass(l:parentFound-l:matchLineCount, a:classRegex, l:newIndent)
					"redraw | echo "GrandparentTestClass: [" l:grandparentTestClass "]" | sleep 1
					if !empty(l:grandparentTestClass)
						let l:class = l:grandparentTestClass."+".l:class
					endif
					"redraw | echo "Class: [" l:class "]" | sleep 1
					return l:class
				else
					let l:currentLine = l:parentFound-l:matchLineCount
				endif
			else
				return ""
			endif
			let l:loopCount = l:loopCount + 1
		endwhile
		throw "LoopCountExceeded"
	finally
		call winrestview(l:oldview)
	endtry
endfunction

function! CsTestGetTest()
	return s:GetTest()
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
		elseif l:testStyle == "xunit"
			let l:classRegex = s:xunitClassRegex
			let l:methodRegex = s:xunitMethodRegex
		else
			throw "Unknown test style"
		endif

		let l:found = search(l:classRegex, "Wbcn")
		if l:found <= 0
			let l:found = search(l:classRegex, "wc")
			call cursor(l:found, 0)
		endif

		let l:namespace = s:FindMatch(s:namespaceRegex)
		let l:class = s:GetTestClass(l:found+1, l:classRegex, 99999)
		let l:method = s:FindMatch(l:methodRegex)

		return [l:namespace, l:class, l:method]
	finally
		call winrestview(l:oldview)
	endtry
endfunction

function! s:FindTestStyle()
	let l:found = search(s:nunitTestRegex, "wcn")
	let l:result = ""
	if l:found > 0
		let l:result = "nunit"
	else
		let l:found = search(s:xunitTestRegex, "wcn")
		if l:found > 0
			let l:result =  "xunit"
		else
			let l:found = search(s:mstestTestRegex, "wcn")
			if l:found > 0
				let l:result =  "mstest"
			else
				let l:testFile = s:GetTestFile()
				try
					exec "new" fnameescape(l:testFile)
					try
						return s:FindTestStyle()
					finally
						hide
					endtry
				endtry
			endif
		endif
	endif
	return l:result
endfunction

function! s:GetContainerNames(file)
	let l:csprojs = s:GetAllContainerNames()
	if strlen(a:file) > 0
		for l:csproj in sort(copy(l:csprojs), "s:SortDesc")
			if (stridx(a:file, l:csproj) == 0)
				return [s:FileName("", l:csproj)]
			endif
		endfor
	endif

	return map(l:csprojs, function("s:FileName"))
endfunction

function! s:FileName(key, file)
	return substitute(a:file, "[^/]*/", "", "")
endfunction


function! s:SortDesc(a, b)
	return a:a == a:b ? 0 : a:a < a:b ? 1 : -1
endfunction

function! s:GetAllContainerNames()
	let l:cwd = getcwd()
	if has_key(g:CsTest_ContainerCache, l:cwd) == 1
		return g:CsTest_ContainerCache[l:cwd]
	else
		let l:container = glob("*.Tests*", 0, 1)
		if (empty(l:container))
			let l:container = glob("*.Test*", 0, 1)
		endif
		if (empty(l:container))
			let l:container = glob("*/*.Test*", 0, 1)
		endif
		if (empty(l:container))
			let l:container = glob("*/*.Tests*", 0, 1)
		endif
		if (empty(l:container))
			let l:container = glob("*.UnitTests", 0, 1)
		endif
		if (empty(l:container))
			let l:container = glob("*.UnitTest", 0, 1)
		endif
		if (empty(l:container))
			let l:container = glob("*/*.UnitTest", 0, 1)
		endif
		if (empty(l:container))
			let l:container = glob("*/*.UnitTests", 0, 1)
		endif
		return l:container
	endif
endfunction

function! s:GetContainerDllPaths(file)
	let l:containerNames = s:GetContainerNames(a:file)
	let l:containerDllsResult = []
	for l:containerName in l:containerNames
		if has_key(g:CsTest_DllCache, l:containerName) == 1
			let l:containerDll = g:CsTest_DllCache[l:containerName]
		else
			"redraw | echo "[" l:containerName "]" | sleep 1
			let l:containerDlls = glob(l:containerName."/**/".l:containerName.".dll", 0, 1)
			if empty(l:containerDlls)
				let l:containerDlls = glob('*/'.l:containerName."/**/".l:containerName.".dll", 0, 1)
			endif
			if empty(l:containerDlls)
				let l:assemblyNames  = s:GetCsProjValues(a:file, "AssemblyName")
				for l:assemblyName in l:assemblyNames
				"redraw | echo "[" l:assemblyName "]" | sleep 1
					let l:containerDlls = glob(l:containerName."/**/".l:assemblyName."*.dll", 0, 1)
					if !empty(l:containerDlls)
						break
					endif
				endfor
			endif
			"redraw | echo "[" l:containerDlls "]" | sleep 5
			let l:containerDll = (sort(l:containerDlls, "s:SortFileByMod"))[0]
			let g:CsTest_DllCache[l:containerName] = l:containerDll
		endif
		call insert(l:containerDllsResult, l:containerDll)
	endfor

	return l:containerDllsResult
endfunction

function! s:GetCsProjValues(file, key)
	let l:csprojs = s:GetContainerProjectPaths(a:file)
	let l:values = []
	for l:csproj in l:csprojs
		if has_key(g:CsTest_CsProjValueCache, l:csproj) == 0
			let g:CsTest_CsProjValueCache[l:csproj] = {}
		endif
		let l:cache = g:CsTest_CsProjValueCache[l:csproj]
		if has_key(l:cache, a:key) == 1
			let l:value = l:cache[a:key]
		else
			"redraw | echom "Csproj: [" l:csproj "][" a:key "]" | sleep 2
			if has('win32')
				let l:sysval = system("powershell cat ".shellescape(l:csproj).' "|" Select-String -Pattern ' .shellescape(a:key))
			else
				let l:sysval = system("grep ".shellescape(a:key)." ".shellescape(l:csproj))
			endif
			"redraw | echom "Out: [" l:sysval "]" | sleep 2
			let l:value = substitute(l:sysval, "[ \\t\\n\\r]*<[^>]*>[ \\t\\n\\r]*", "", "g")
			"redraw | echom "Value: [" l:value "]" | sleep 2
			let l:cache[a:key] = l:value 
		endif
		call insert(l:values, l:value)
	endfor
	"redraw | echo "Values: [" string(l:values) "]" | sleep 5
	return l:values
endfunction

function! s:GetContainerMap(file)
	let l:list = s:GetContainerNames(a:file)
	let l:dict = {}
	for l:item in l:list
		let l:baseName = substitute(l:item, "[.]Tests\\?$", "", "")
		let l:dict[l:baseName] = l:item
	endfor
	return l:dict
endfunction

function! s:GetTestFile()
	let l:folder = expand("%:h")
	let l:fileRoot = expand("%:t:r")
	let l:mappings = s:GetContainerMap(l:folder)
	for l:key in keys(l:mappings)
		if match(l:folder, l:key) >= 0
			let l:testFolder = substitute(l:folder, l:key, l:mappings[l:key], "")
			if isdirectory(l:testFolder)
				for l:testFile in glob(l:testFolder."/".l:fileRoot."*", 1, 1)
					return l:testFile
				endfor
			endif
			return l:testFolder."/".l:fileRoot."Tests.".expand("%:e")
		endif
	endfor
	echoerr "Could not find a test file"
endfunction

function! s:GetInterfaceFile()
	return expand("%:h")."/I".expand("%:t")
endfunction

function! s:GetContainerProjectPaths(file)
	let l:containerNames = s:GetContainerNames(a:file)
	let l:csprojFilesResult = []
	for l:containerName in l:containerNames
		"redraw | echo "[" l:containerName "]" | sleep 1
		let l:csprojFiles = glob(l:containerName."/**".l:containerName.".csproj", 0, 1)
		if empty(l:csprojFiles)
			let l:csprojFiles = glob('*/'.l:containerName."/**".l:containerName.".csproj", 0, 1)
		endif
		if empty(l:csprojFiles)
			let l:csprojFiles = glob(l:containerName."/**.csproj", 0, 1)
		endif
		"redraw | echo "[" l:csprojFiles "]" | sleep 5
		let l:csproj = (sort(l:csprojFiles, "s:SortFileByMod"))[0]
		call insert(l:csprojFilesResult, l:csproj)
	endfor

	return l:csprojFilesResult
endfunction

function! s:SortFileByMod(a, b)
	let l:aT = getftime(a:a)
	let l:bT = getftime(a:b)
	return l:aT == l:bT ? 0 : l:aT < l:bT ? 1 : -1
endfunction

function! CsTestRunTest(file, ...)
	try
		let g:cstestRunning = 1
		if empty(a:000)
			throw "No tests supplied"
		endif

		let l:testStyle = s:FindTestStyle()

		let l:pretestResult = s:PreTestMake(a:file)
		if l:pretestResult != 0
			return 0
		endif

		let l:containerPaths = s:GetContainerDllPaths(a:file)
		let l:containerNamespaces = s:GetCsProjValues(a:file, "RootNamespace")
		call map(l:containerPaths, '"../".v:val')

		echo "Testing [" join(a:000, " - ") "][" join(l:containerPaths, " - ") "]"
		"echom "[" join(l:containerNamespaces) "]"
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
			if l:testStyle == "xunit"
				let l:testFiles = glob(fnamemodify(l:testResultFile, ':r').'*', 0, 1)
				for file in l:testFiles
					call delete(file)
				endfor
			endif

			let l:shellcommand = "false"
			let l:xsltfile = ""

			if l:testStyle == "mstest"
				let l:shellcommand = s:mstestExe." /resultsfile:".shellescape(l:testResultFile)
				for containerPath in l:containerPaths
					let l:shellcommand = l:shellcommand." /testcontainer:".shellescape(containerPath)
				endfor
				for test in a:000
					let l:shellcommand = l:shellcommand." /test:".shellescape(test)
				endfor
				if !empty(g:CsTestMstestCategoryFilter)
					let l:shellcommand = l:shellcommand." /category:".shellescape(g:CsTestMstestCategoryFilter)
				endif
				let l:xsltfile = s:mstestXsltFile
			elseif l:testStyle == "nunit"
				let l:shellcommand = 'TMP= TEMP= '.shellescape(s:nunitExe)." ".join(map(l:containerPaths, 'shellescape(v:val)'))." -out TestOut.txt -err TestErr.txt -result ".l:testResultFile." -test ".join(a:000, ',')
				if !empty(g:CsTestNunitCategoryFilter)
					let l:shellcommand = l:shellcommand." -where \"cat != ".shellescape(g:CsTestNunitCategoryFilter) ."\""
				endif
				let l:xsltfile = s:nunitXsltFile
			elseif l:testStyle == "xunit"
				let l:shellcommand = "dotnet vstest --Platform:x64 --ResultsDirectory:. --logger:trx;LogFileName=".l:testResultFile." ".join(map(l:containerPaths, 'shellescape(v:val)'))
				"redraw | echom "Tests: " a:000 | sleep 1
				let l:realTests = filter(copy(a:000), {idx, val -> strlen(copy(val))})
				"redraw | echom "Tests: " l:realTests | sleep 1
				if (len(l:realTests))
					let l:shellcommand = l:shellcommand.' '.shellescape("--testcasefilter:(FullyQualifiedName~".join(l:realTests, '|FullyQualifiedName~').')') 
				endif
				"if !empty(g:CsTestXunitCategoryFilter)
				"	let l:shellcommand = l:shellcommand." -where \"cat != ".shellescape(g:CsTestXunitCategoryFilter) ."\""
				"endif
				let l:xsltfile = s:xunitXsltFile
			else
				throw "Unknown test style"
			endif

			"redraw | echom "Command: " l:shellcommand | sleep 1
			let g:CsTest_LastCommand = l:shellcommand

			let l:testout = system(l:shellcommand)

			let g:CsTest_LastOut = l:testout
			"redraw | echom "Out: " l:testout | sleep 1

			if l:testStyle == "xunit"
				let l:testFiles = glob(fnamemodify(l:testResultFile, ':r').'*', 0, 1)
				let l:testResultFile = (sort(l:testFiles, "s:SortFileByMod"))[0]
			endif

			if !filereadable(l:testResultFile)
				echo "Error[".v:shell_error."] [".l:testout.']'
				return -2
			endif

			if l:testStyle == "mstest"
				call system("rm -r $USER'_'$COMPUTERNAME''*")
			endif

			"let l:traces = matchlist(l:result, "in \\(.*\\):line \\(\\d\\+\\)")
			"echo "[" l:traces "]"
			"echo "[" l:file "][" l:line "]"

			if has('win32')
				let l:testResultText = system("powershell ".s:xsltWindowScript." ".l:xsltfile." ".l:testResultFile)
			else
				let l:testResultText = system("xsltproc.exe -o - ".l:xsltfile." ".l:testResultFile)
			endif
			let l:testResults = s:ParseTestResult(l:testResultText, l:containerNamespaces)
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
	finally
		let g:cstestRunning = 0
	endtry
endfunction

function! s:ParseTestResult(testResultText, containerNames)
	let l:testResultLines = split(a:testResultText, "\n")
	let l:testResults = []
	let l:testResult = {}
	"echomsg "Lines ".string(l:testResultLines)
	for l:line in l:testResultLines
		if match(l:line, '^\(Total\|Failed\|Passed\):') >= 0
			"echomsg "Skipping ".l:line
		elseif match(l:line, '^T:') >= 0
			if (!empty(l:testResult))
				let l:testResult["text"] = l:testResult["test"].' '.l:testResult["result"]
				if (has_key(l:testResult, 'message'))
					let l:testResult["text"] = l:testResult["text"].': '.l:testResult["message"]
				endif
				call insert(l:testResults, l:testResult)
			endif
			let l:testResult = {}
			let l:testName = matchlist(l:line, '^T: \([A-Za-z0-9_.+-]\+\%(([^)]*)\)\?\)\s\(\w\+\)$')
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
					let l:stacktraces = split(l:testOutput[2], "at ")
					"echomsg "Matching [".string(l:stacktraces).']'
					let l:stacktraceMatch = join(map(copy(a:containerNames), "'^'.v:val.'\\%([.A-Za-z_-]\\%(TestInfrastructure\\|Assert\\|Setup\\)\\@!\\)*\\%([^.A-Za-z_-]\\|$\\)'"), '\|')
					"echomsg "Match [".string(l:stacktraceMatch).']'
					let l:stacktraceIndex = match(l:stacktraces, l:stacktraceMatch)
					"echomsg "Matching [".l:stacktraceIndex.'] for '.string(a:containerNames)
					if l:stacktraceIndex == -1
						let l:stacktraceIndex = match(l:stacktraces, "in ")
					endif
					let l:stacktrace = l:stacktraces[l:stacktraceIndex]
					"echomsg "Matching [".l:stacktrace.']' | sleep 5
					let l:testStack = matchlist(l:stacktrace, '^.\{-}in \([a-zA-Z]\?:\?[^:]*\):line \(\d*\)')
					"echomsg "Matched [".string(l:testStack).']' | sleep 20
					if !empty(l:testStack)
						let l:testResult["filename"] = l:testStack[1]
						let l:testResult["lnum"] = l:testStack[2]
						let l:testResult["message"] = l:testResult["message"] . "\n" . l:testOutput[2]
					else
						throw 'Could not parse ['.l:stacktrace.'] for file/line'
					endif
				else
					throw "Matched ".l:testOutput[1]."!?!"
				endif
			else
				"echomsg "Couldn't match ".l:line
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

function! s:FindMatchLineCount(regex)
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
		return l:count

	finally
		call winrestview(l:oldview)
	endtry

endfunction

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
