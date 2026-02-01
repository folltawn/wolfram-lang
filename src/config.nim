## Работа с конфигурацией проекта

import strutils
import ./types

proc loadConfig*(filename: string): ProjectConfig =
  ## Загрузить конфигурацию проекта
  try:
    let content = readFile(filename)
    
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
              result.files.add(file.strip().strip(chars={'"', ' '}))
  
  except IOError:
    echo "Ошибка: Не удалось прочитать файл ", filename
    quit(1)