## Обработка ошибок компилятора

import strformat, strutils, tables

type
  ErrorKind* = enum
    errNone
    errMissingSemicolon
    errUnexpectedToken
    errUnknownType
    errExpectedExpression
    errExpectedIdentifier
    errExpectedLParen
    errExpectedRParen
    errExpectedLBrace
    errExpectedRBrace
    errExpectedEq
    errExpectedFatArrow
    errExpectedType
    errUnclosedInterpolation
    errUnknownFunction
    errUnsupportedOperator
    errUnsupportedExpression
    errUnsupportedNode
    errUnknownConstruct
    errInvalidLiteral
    errInvalidRefactorType
    errMissingConst

  CompileError* = object
    kind*: ErrorKind
    message*: string
    line*: int
    column*: int
    filename*: string
    sourceLine*: string
    expected*: string
    found*: string
  
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

proc errorMessage(kind: ErrorKind, expected: string = "", found: string = ""): string =
  case kind
  of errMissingSemicolon: "Missing ';'"
  of errUnexpectedToken: &"Unexpected token '{found}'"
  of errUnknownType: &"Unknown type '{found}'"
  of errExpectedExpression: "Expected expression"
  of errExpectedIdentifier: &"Expected identifier, got '{found}'"
  of errExpectedLParen: "Expected '('"
  of errExpectedRParen: "Expected ')'"
  of errExpectedLBrace: "Expected '{{'"
  of errExpectedRBrace: "Expected '}}'"
  of errExpectedEq: "Expected '='"
  of errExpectedFatArrow: "Expected '=>'"
  of errExpectedType: "Expected type (int, float, bool, str)"
  of errUnclosedInterpolation: "Unclosed string interpolation"
  of errUnknownFunction: &"Unknown function '{found}'"
  of errUnsupportedOperator: &"Unsupported operator '{found}'"
  of errUnsupportedExpression: "Unsupported expression"
  of errUnsupportedNode: "Unsupported AST node"
  of errUnknownConstruct: &"Unrecognized construct '{found}'"
  of errInvalidLiteral: &"Invalid literal '{found}'"
  of errInvalidRefactorType: &"Invalid refactor type '{found}'"
  of errMissingConst: "Expected 'const' after '::'"
  else: "Unknown error"

proc addError*(state: var CompilerState, kind: ErrorKind, line: int, column: int, 
               expected: string = "", found: string = "") =
  let err = CompileError(
    kind: kind,
    message: errorMessage(kind, expected, found),
    line: line,
    column: column,
    filename: state.filename,
    sourceLine: state.getSourceLine(line),
    expected: expected,
    found: found
  )
  state.errors.add(err)

proc addErrorExpected*(state: var CompilerState, expected: string, found: string, 
                       line: int, column: int) =
  state.addError(errUnexpectedToken, line, column, expected, found)

proc addWarning*(state: var CompilerState, message: string, line = 0, column = 0) =
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

proc prettyError*(state: CompilerState, err: CompileError): string =
  let 
    line = err.line
    col = err.column
    sourceLine = if err.sourceLine.len > 0: err.sourceLine else: state.getSourceLine(line)
    filename = if err.filename.len > 0: err.filename else: state.filename
  
  result = &"ERROR. {err.message}\n"
  result.add &"       │  │\n"
  result.add &"       │  └── {filename}:{line}:{col}\n"
  result.add &"       │\n"
  
  if sourceLine.len > 0:
    result.add &"    {line} │ {sourceLine}\n"
    result.add &"       │ "
    
    for i in 0..<col-1:
      if i < sourceLine.len and sourceLine[i] == ' ':
        result.add "·"
      else:
        result.add " "
    
    result.add "^ {err.message}\n"
  else:
    result.add &"    {line} │\n"
    result.add &"       │ ^ {err.message}\n"
  
  result.add &"       │\n"

proc showErrors*(state: CompilerState) =
  if state.errors.len == 0:
    return
  
  for err in state.errors:
    echo state.prettyError(err)
  
  if state.warnings.len > 0:
    echo "\nWarnings:"
    for warn in state.warnings:
      echo &"  ⚠ {warn.message} ({warn.filename}:{warn.line}:{warn.column})"