## CLI интерфейс для компилятора PD

import os, strutils, strformat, osproc
import ./types, ./errors, ./parser, ./compiler, ./config

const
  Version = "1.0.0"
  HelpText = """

████████████████████████████████████████████

              ▄              ▄   
            ▄█▀ █████▄ ▄▄▄▄  ▀█▄ 
            ██  ██▄▄█▀ ██▀██  ██ 
            ▀█▄ ██     ████▀ ▄█▀ 
              ▀              ▀   

████████████████████████████████████████████

Компилятор Palladium v""" & Version & """

Использование:
  pd <команда> [аргументы]

Команды:
  --version             Показать версию компилятора
  --help                Показать эту справку
  --docs                Показать документацию (в разработке)
  parse <файл>         Парсить файл и показать AST
  build <конфиг>       Собрать проект по конфигурационному файлу
  debug <файл>         Проверить файл на ошибки
  run <файл>           Скомпилировать и запустить файл
"""

# Убрали loadConfig из этого файла, теперь она в config.nim

proc parseFile(filename: string) =
  ## Парсить файл и вывести AST
  try:
    let source = readFile(filename)
    var parser = newParser(source)
    let ast = parser.parseProgram()
    
    if parser.state.hasErrors():
      parser.state.showErrors()
      quit(1)
    
    echo "AST дерево:"
    echo "==========="
    
    proc printNode(node: Node, depth: int = 0) =
      let indent = "  ".repeat(depth)
      case node.kind
      of nkProgram:
        echo &"{indent}Program:"
        for stmt in node.statements:
          printNode(stmt, depth + 1)
      
      of nkVarDecl:
        echo &"{indent}VarDecl: {node.declName} : {node.declType}"
        if node.declValue != nil:
          printNode(node.declValue, depth + 1)
      
      of nkConstDecl:
        echo &"{indent}ConstDecl: {node.declName} : {node.declType}"
        if node.declValue != nil:
          printNode(node.declValue, depth + 1)
      
      of nkAssignment:
        echo &"{indent}Assignment: {node.assignName}"
        if node.assignValue != nil:
          printNode(node.assignValue, depth + 1)
      
      of nkSendln:
        echo &"{indent}Sendln:"
        if node.sendlnArg != nil:
          printNode(node.sendlnArg, depth + 1)
      
      of nkRefactor:
        echo &"{indent}Refactor: -> {node.refactorToType}"
        if node.refactorTarget != nil:
          printNode(node.refactorTarget, depth + 1)
      
      of nkLiteral:
        echo &"{indent}Literal[{node.litType}]: {node.litValue}"
      
      of nkIdentifier:
        echo &"{indent}Identifier: {node.identName}"
      
      else:
        echo &"{indent}{node.kind}"
    
    printNode(ast)
    
  except IOError:
    echo &"Ошибка: Не удалось прочитать файл {filename}"
    quit(1)

proc debugFile(filename: string) =
  ## Проверить файл на ошибки
  try:
    let source = readFile(filename)
    var parser = newParser(source)
    discard parser.parseProgram()
    
    if parser.state.hasErrors():
      echo "Найдены ошибки:"
      parser.state.showErrors()
      quit(1)
    else:
      echo "Ошибок не найдено."
      if parser.state.warnings.len > 0:
        echo "\nПредупреждения:"
        for warn in parser.state.warnings:
          echo &"  {warn}"
    
  except IOError:
    echo &"Ошибка: Не удалось прочитать файл {filename}"
    quit(1)

proc compileFile(filename: string): string =
  ## Скомпилировать файл в C код
  try:
    let source = readFile(filename)
    var parser = newParser(source)
    let ast = parser.parseProgram()
    
    if parser.state.hasErrors():
      parser.state.showErrors()
      quit(1)
    
    var generator = initCodeGenerator()
    result = generator.generateCode(ast)
    
    if generator.state.hasErrors():
      generator.state.showErrors()
      quit(1)
    
  except IOError:
    echo &"Ошибка: Не удалось прочитать файл {filename}"
    quit(1)

proc runFile(filename: string) =
  ## Скомпилировать и запустить файл
  let cCode = compileFile(filename)
  
  # Сохраняем временный C файл
  let tempDir = getTempDir()
  let cFile = tempDir / "pd_temp.c"
  let exeFile = tempDir / "pd_temp.exe"
  
  writeFile(cFile, cCode)
  
  # Компилируем C код
  echo "Компиляция в C..."
  
  # Упрощенный вариант для Windows
  let compileCmd = "gcc -o \"" & exeFile & "\" \"" & cFile & "\""
  echo "Выполняется: ", compileCmd
  
  let (output, exitCode) = execCmdEx(compileCmd)
  
  if exitCode != 0:
    echo "Ошибка компиляции C кода (код: ", exitCode, ")"
    # Покажем содержимое сгенерированного C файла для отладки
    echo "\nСгенерированный C код:"
    echo "====================="
    echo cCode
    echo "====================="
    quit(1)
  
  # Запускаем исполняемый файл
  echo "\nЗапуск программы:"
  echo "================="
  discard execShellCmd(exeFile)
  
  # Удаляем временные файлы
  removeFile(cFile)
  removeFile(exeFile)

proc buildProject(configFile: string) =
  ## Собрать проект по конфигурации
  let config = loadConfig(configFile)
  
  echo &"Сборка проекта: {config.name} v{config.version}"
  if config.author.len > 0:
    echo &"Автор(ы): {config.author.join(\", \")}"
  echo ""
  
  for file in config.files:
    if fileExists(file):
      echo &"Компиляция {file}..."
      let cCode = compileFile(file)
      
      # Сохраняем скомпилированный C файл
      let cFile = changeFileExt(file, ".c")
      writeFile(cFile, cCode)
      echo &"  -> Сгенерирован: {cFile}"
      
      # Компилируем в исполняемый файл
      let exeFile = changeFileExt(file, "")
      let compileCmd = "gcc -o \"" & exeFile & "\" \"" & cFile & "\""
      let (compileOutput, exitCode) = execCmdEx(compileCmd)
      
      if exitCode != 0:
        echo "  Ошибка компиляции:"
        echo compileOutput
      else:
        echo &"  -> Исполняемый файл: {exeFile}"
      
    else:
      echo &"Ошибка: Файл не найден: {file}"

proc handleCommand*() =
  ## Обработать команду CLI
  if paramCount() == 0:
    echo HelpText
    return
  
  let cmd = paramStr(1)
  
  case cmd
  of "--version":
    echo &"Palladium Compiler v{Version}"
  
  of "--help":
    echo HelpText
  
  of "--docs":
    echo "Palladium Docs:"
    echo "  > https://folltawn.github.io/ru/pdlang/docs"
  
  of "parse":
    if paramCount() < 2:
      echo "Ошибка: Укажите файл для парсинга"
      quit(1)
    parseFile(paramStr(2))
  
  of "debug":
    if paramCount() < 2:
      echo "Ошибка: Укажите файл для проверки"
      quit(1)
    debugFile(paramStr(2))
  
  of "run":
    if paramCount() < 2:
      echo "Ошибка: Укажите файл для запуска"
      quit(1)
    runFile(paramStr(2))
  
  of "build":
    if paramCount() < 2:
      echo "Ошибка: Укажите конфигурационный файл"
      quit(1)
    buildProject(paramStr(2))
  
  else:
    echo &"Неизвестная команда: {cmd}"
    echo HelpText
    quit(1)