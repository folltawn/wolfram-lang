# Package

version       = "1.0.0"
author        = "I Am Towvee"
description   = "Компилятор для языка Palladium (pd)"
license       = "Apache-2.0"

# Dependencies

requires "nim >= 2.0.0"

# Пути

srcDir = "src"
bin = @["pd"]

# Команды

task build, "Собрать компилятор":
  exec "nim c -d:release --path:. -o:bin/pdlang src/main.nim"

task dev, "Собрать в режиме разработки":
  exec "nim c -d:debug --path:. -o:pdlang src/main.nim"

task test, "Запустить тесты":
  exec "echo 'Тесты пока не реализованы'"

task clean, "Очистить сгенерированные файлы":
  exec "del pdlang.exe 2>nul || true"
  exec "rm -f pdlang 2>/dev/null || true"
  exec "rm -rf nimcache 2>/dev/null || true"
  exec "del *.c 2>nul || true"