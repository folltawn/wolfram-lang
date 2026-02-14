## Обработка ошибок компилятора

import strformat, strutils

type
  CompileError* = object of CatchableError
    line*: int
    column*: int
    filename*: string
    sourceLine*: string
  
  CompileWarning* = object
    message*: string
    line*: int
    column*: int
    filename*: string
    sourceLine*: string

  CompilerState* = object
    errors*: seq[CompileError]
    warnings*: seq[CompileWarning]
    source*: string
    filename*: string

proc initCompilerState*(source: string = "", filename: string = ""): CompilerState =
  CompilerState(
    errors: @[],
    warnings: @[],
    source: source,
    filename: filename
  )

proc getSourceLine(state: CompilerState, line: int): string =
  if state.source.len == 0 or line < 1:
    return ""
  
  let lines = state.source.splitLines()
  if line <= lines.len:
    return lines[line-1]
  return ""

proc prettyError*(state: CompilerState, err: CompileError): string =
  let 
    line = err.line
    col = err.column
    sourceLine = if err.sourceLine.len > 0: err.sourceLine else: state.getSourceLine(line)
    filename = if err.filename.len > 0: err.filename else: state.filename
  
  result = &"ERROR. {err.msg}\n"
  result.add &"    ├> {filename}:{line}:{col}\n"
  result.add &"    │\n"
  
  if sourceLine.len > 0:
    result.add &"    └>  {line} | {sourceLine}\n"
    if col > 0 and col <= sourceLine.len:
      result.add &"         {' '.repeat(col + len($line) + 2)}^\n"
      result.add &"         {' '.repeat(col + len($line) + 1)}Here\n"
  else:
    result.add &"    └>  {line} | <end of file>\n"

proc error*(state: var CompilerState, message: string, line = 0, column = 0) =
  let err = CompileError(
    msg: message,
    line: line,
    column: column,
    filename: state.filename,
    sourceLine: state.getSourceLine(line)
  )
  state.errors.add(err)

proc warning*(state: var CompilerState, message: string, line = 0, column = 0) =
  let warn = CompileWarning(
    message: message,
    line: line,
    column: column,
    filename: state.filename,
    sourceLine: state.getSourceLine(line)
  )
  state.warnings.add(warn)

proc hasErrors*(state: CompilerState): bool =
  state.errors.len > 0

proc showErrors*(state: CompilerState) =
  if state.errors.len == 0:
    return
  
  for err in state.errors:
    echo state.prettyError(err)
  
  if state.warnings.len > 0:
    echo "\nWarnings:"
    for warn in state.warnings:
      echo &"  ⚠ {warn.message} ({warn.filename}:{warn.line}:{warn.column})"