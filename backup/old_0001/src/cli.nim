# src/cli.nim
## CLI интерфейс для компилятора PD

import os, strutils, strformat, osproc, times, tables
import ./types, ./errors, ./parser, ./compiler, ./config

const
  Version = "1.0.0"
  SourceExtension = ".pd"
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
  run <файл> [арг...]  Скомпилировать и запустить файл с аргументами

Примеры:
  pd parse program.pd
  pd debug program.pd
  pd run program.pd
  pd run program.pd arg1 arg2
  pd build project.conf
"""

# Кэш для скомпилированных программ
var compileCache = initTable[string, (string, Time)]()

proc getProgramArgs(startIdx: int): seq[string] =
  ## Получить аргументы для запускаемой программы
  result = @[]
  for i in startIdx..paramCount():
    result.add(paramStr(i))

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
  ## Скомпилировать .pd файл в C код
  
  if not filename.toLowerAscii.endsWith(".pd"):
    echo &"Ошибка: Могу компилировать только .pd файлы"
    quit(1)
  
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

proc isValidPdFile(filename: string): bool =
  ## Проверяет, является ли файл исходным кодом Palladium (.pd)
  let ext = splitFile(filename).ext.toLowerAscii
  return ext == ".pd"

# В runFile:
proc runFile(filename: string, args: seq[string] = @[]) =
  ## Скомпилировать и запустить .pd файл
  
  if not fileExists(filename):
    echo &"Ошибка: Файл '{filename}' не найден"
    quit(1)
  
  if not filename.toLowerAscii.endsWith(".pd"):
    echo &"Ошибка: Файл должен иметь расширение .pd"
    echo &"Получено: {splitFile(filename).ext}"
    quit(1)
  
  let sourceTime = getLastModificationTime(filename)
  let baseName = splitFile(filename).name
  
  # Проверяем кэш
  var useCache = false
  var exeFile = ""
  
  if compileCache.hasKey(filename):
    let (cachedExe, cachedTime) = compileCache[filename]
    if sourceTime <= cachedTime and fileExists(cachedExe):
      useCache = true
      exeFile = cachedExe
      echo "Использую кэшированную версию..."
    else:
      # Устаревший кэш
      compileCache.del(filename)
  
  if not useCache:
    echo &"Компиляция {filename}..."
    
    # Генерируем C код
    let cCode = compileFile(filename)
    
    # Создаем временную директорию
    let tempDir = getTempDir() / "pd_run"
    if not dirExists(tempDir):
      createDir(tempDir)
    
    # Готовим имена файлов
    exeFile = tempDir / baseName & (when defined(windows): ".exe" else: "")
    let cFile = tempDir / baseName & ".c"
    
    # Сохраняем C код
    writeFile(cFile, cCode)
    
    # Компилируем в исполняемый файл
    echo "Компиляция в исполняемый файл..."
    let compileCmd = "gcc -o \"" & exeFile & "\" \"" & cFile & "\""
    let (compileOutput, exitCode) = execCmdEx(compileCmd)
    
    if exitCode != 0:
      echo "Ошибка компиляции C кода:"
      echo compileOutput
      
      echo "\nСгенерированный C код для отладки:"
      echo "=".repeat(60)
      echo cCode
      echo "=".repeat(60)
      
      # Очищаем временные файлы
      removeFile(cFile)
      if fileExists(exeFile):
        removeFile(exeFile)
      quit(1)
    
    # Сохраняем в кэш
    compileCache[filename] = (exeFile, getTime())
    
    # Удаляем C файл (EXE оставляем для кэша)
    removeFile(cFile)
  
  # Формируем команду запуска
  var runCmd = "\"" & exeFile & "\""
  if args.len > 0:
    runCmd.add(" " & args.join(" "))
  
  # Запускаем программу
  echo "\n" & "=".repeat(60)
  echo &"Запуск программы {filename}:"
  if args.len > 0:
    echo &"Аргументы: {args.join(\" \")}"
  echo "-".repeat(60)
  
  let (output, runExitCode) = execCmdEx(runCmd)
  echo output
  
  echo "-".repeat(60)
  echo &"Программа завершилась с кодом: {runExitCode}"
  echo "=".repeat(60)

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

proc cleanupCache() =
  ## Очистить кэш скомпилированных программ
  let tempDir = getTempDir() / "pd_run"
  if dirExists(tempDir):
    try:
      removeDir(tempDir)
      echo "Кэш очищен"
    except:
      echo "Не удалось очистить кэш"

proc showVersion() =
  ## Показать версию с дополнительной информацией
  echo &"Palladium Compiler v{Version}"
  echo "Nim Version: ", NimVersion
  echo "Platform: ", hostOS, " ", hostCPU
  echo "Build: ", CompileDate, " ", CompileTime

proc handleCommand*() =
  ## Обработать команду CLI
  if paramCount() == 0:
    echo HelpText
    return
  
  let cmd = paramStr(1)
  
  case cmd
  of "--version", "-v":
    showVersion()
  
  of "--help", "-h":
    echo HelpText
  
  of "--docs":
    echo "Palladium Docs:"
    echo "  > https://folltawn.github.io/ru/pdlang/docs"
    echo "  > Документация в разработке"
  
  of "--clean-cache":
    cleanupCache()
  
  of "parse":
    if paramCount() < 2:
      echo "Ошибка: Укажите файл для парсинга"
      echo "Пример: pd parse program.pd"
      quit(1)
    parseFile(paramStr(2))
  
  of "debug":
    if paramCount() < 2:
      echo "Ошибка: Укажите файл для проверки"
      echo "Пример: pd debug program.pd"
      quit(1)
    debugFile(paramStr(2))
  
  of "run":
    if paramCount() < 2:
      echo "Ошибка: Укажите файл для запуска"
      echo "Примеры:"
      echo "  pd run program.pd"
      echo "  pd run program.pd arg1 arg2"
      echo "  pd run program.pd --input data.txt --output result.txt"
      quit(1)
    
    let filename = paramStr(2)
    let programArgs = getProgramArgs(3)  # Аргументы начиная с 3-го
    
    runFile(filename, programArgs)
  
  of "build":
    if paramCount() < 2:
      echo "Ошибка: Укажите конфигурационный файл"
      echo "Пример: pd build project.conf"
      quit(1)
    buildProject(paramStr(2))
  
  else:
    # Пробуем интерпретировать как файл для запуска
    if fileExists(cmd) and cmd.endsWith(".pd"):
      let programArgs = getProgramArgs(2)  # Аргументы начиная со 2-го
      runFile(cmd, programArgs)
    else:
      echo &"Неизвестная команда: {cmd}"
      echo ""
      echo "Если вы хотели запустить файл, убедитесь что он имеет расширение .pd"
      echo "Или используйте: pd run <файл.pd>"
      echo ""
      echo HelpText
      quit(1)