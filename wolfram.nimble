# Package

version       = "1.0.0"
author        = "I Am Towvee"
description   = "Компилятор для языка Wolfram"
license       = "Apache-2.0"

# Dependencies

requires "nim >= 2.0.0"
requires "yaml >= 2.0.0"

# Команды

bin = @["wfm"]

task docs, "Сгенерировать документацию":
  exec "nim doc --project src/main.nim"