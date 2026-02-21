## Обработка ошибок компилятора

import strformat, strutils, math

const
  Gray = "\e[90m"
  Reset = "\e[0m"

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
  
  # Длина номера строки определяет отступ
  let lineNumLen = len($line)
  
  # База: 4 пробела + длина номера + 1 пробел
  let indent = " ".repeat(4 + lineNumLen + 1)
  
  result = &"ERROR. {err.msg}\n"
  
  # Первая линия с │  │ (серым)
  result.add &"{Gray}{indent}│  │{Reset}\n"
  
  # Вторая линия с └── filename:line:column (серым)
  result.add &"{Gray}{indent}│  └── {filename}:{line}:{col}{Reset}\n"
  
  # Пустая линия с │ (серым)
  result.add &"{Gray}{indent}│{Reset}\n"
  
  if sourceLine.len > 0:
    # Строка с номером и кодом (нормальным цветом)
    result.add &"    {line} │ {sourceLine}\n"
    
    # Строка с указателем (серым)
    result.add &"{Gray}{indent}│{Reset} "
    
    # Отступ до позиции ошибки (серым)
    for i in 0..<col-1:
      if i < sourceLine.len and sourceLine[i] == ' ':
        result.add &"{Gray}·{Reset}"
      else:
        result.add " "
    
    result.add &"{Gray}^{Reset} {err.msg}\n"
  else:
    # Строка не найдена (файл короче)
    result.add &"    {line} │\n"
    result.add &"{Gray}{indent}│{Reset} ^{Gray} {err.msg} (строка {line} отсутствует в файле){Reset}\n"
  
  # Пустая строка внизу (серым)
  result.add &"{Gray}{indent}│{Reset}\n"



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