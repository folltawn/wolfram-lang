## Работа с конфигурацией проекта

import strutils, os
import ./types

proc loadConfig*(filename: string): ProjectConfig =
  ## Загрузить конфигурацию проекта
  try:
    let content = readFile(filename)
    let configDir = absolutePath(filename).splitFile.dir
    result.projectDir = configDir
    
    for line in content.splitLines():
      let trimmed = line.strip()
      
      if trimmed.startsWith("name:"):
        let parts = trimmed.split(':', 1)
        if parts.len > 1:
          result.name = parts[1].strip().strip(chars={'"', ' '})
      
      elif trimmed.startsWith("version:"):
        let parts = trimmed.split(':', 1)
        if parts.len > 1:
          result.version = parts[1].strip().strip(chars={'"', ' '})
      
      elif trimmed.startsWith("author:"):
        let parts = trimmed.split(':', 1)
        if parts.len > 1:
          let authorStr = parts[1].strip().strip(chars={'[', ']'})
          if authorStr.len > 0:
            for author in authorStr.split(','):
              result.author.add(author.strip().strip(chars={'"', ' '}))
      
      elif trimmed.startsWith("files:"):
        let parts = trimmed.split(':', 1)
        if parts.len > 1:
          let filesStr = parts[1].strip().strip(chars={'[', ']'})
          if filesStr.len > 0:
            for file in filesStr.split(','):
              let filePath = file.strip().strip(chars={'"', ' '})
              # Проверяем расширение
              if not filePath.endsWith(".pd"):
                echo "Предупреждение: файл '", filePath, "' не имеет расширения .pd"
                # Либо игнорируем, либо добавляем с предупреждением
                # result.files.add(...) - если хотите все равно добавить
              else:
                # Преобразуем путь
                let absPath = if isAbsolute(filePath): filePath else: configDir / filePath
                result.files.add(absPath)
    
    # Проверяем, что есть хотя бы один .pd файл
    if result.files.len == 0:
      echo "Ошибка: В конфигурации нет файлов с расширением .pd"
      quit(1)
  
  except IOError:
    echo "Ошибка: Не удалось прочитать файл ", filename
    quit(1)