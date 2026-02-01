## Обработка ошибок компилятора

import strformat

type
  CompileError* = object of CatchableError
    line*: int
    column*: int
  
  CompileWarning* = object
    message*: string
    line*: int
    column*: int

  # Состояние компилятора для обработки ошибок
  CompilerState* = object
    errors*: seq[string]
    warnings*: seq[string]

proc error*(state: var CompilerState, message: string, line = 0, column = 0) =
  ## Добавить ошибку в состояние компилятора
  let location = if line > 0: &"({line}:{column}) " else: ""
  state.errors.add(&"{location}{message}")

proc warning*(state: var CompilerState, message: string, line = 0, column = 0) =
  ## Добавить предупреждение в состояние компилятора
  let location = if line > 0: &"({line}:{column}) " else: ""
  state.warnings.add(&"{location}{message}")

proc hasErrors*(state: CompilerState): bool =
  ## Проверить наличие ошибок
  state.errors.len > 0

proc showErrors*(state: CompilerState) =
  ## Вывести все ошибки
  if state.errors.len == 0:
    return
  
  echo "Ошибки компиляции:"
  for i, err in state.errors:
    echo &"  {i+1}. {err}"
  
  if state.warnings.len > 0:
    echo "\nПредупреждения:"
    for i, warn in state.warnings:
      echo &"  {i+1}. {warn}"

proc newCompileError*(message: string, line = 0, column = 0): ref CompileError =
  ## Создать новую ошибку компиляции
  new(result)
  result.msg = message
  result.line = line
  result.column = column