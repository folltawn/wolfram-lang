## Компилятор Wolfram -> C (промежуточный этап)

import strformat, strutils, math, tables
import ./types, ./errors

type
  CodeGenerator* = object
    output*: string
    indentLevel*: int
    state*: CompilerState
    typeMap*: Table[string, string]
    tempCounter*: int

proc getTempVar(g: var CodeGenerator): string =
  g.tempCounter += 1
  result = &"__temp_{g.tempCounter}"

proc indent(g: var CodeGenerator) =
  g.indentLevel += 1

proc unindent(g: var CodeGenerator) =
  g.indentLevel -= 1

proc write(g: var CodeGenerator, text: string) =
  g.output.add(text)

proc writeln(g: var CodeGenerator, text: string = "") =
  if text.len > 0:
    g.output.add("  ".repeat(g.indentLevel) & text & "\n")
  else:
    g.output.add("\n")

proc typeToCType(t: WolframType): string =
  case t
  of wtInt: "int"
  of wtFloat: "double"
  of wtBool: "bool"
  of wtString: "char*"
  of wtVoid: "void"
  else: "void*"

proc escapeString(s: string): string =
  result = newStringOfCap(s.len * 2)
  for ch in s:
    case ch
    of '\\': result.add("\\\\")
    of '\"': result.add("\\\"")
    of '\n': result.add("\\n")
    of '\t': result.add("\\t")
    of '\r': result.add("\\r")
    else: result.add(ch)

proc generateIdentifier(g: var CodeGenerator, identName: string): string =
  ## Генерирует имя переменной с учетом преобразований типов
  if identName in g.typeMap:
    return g.typeMap[identName]
  else:
    return identName

proc generateLiteral(g: var CodeGenerator, node: Node): string =
  case node.litType
  of wtInt: node.litValue
  of wtFloat: node.litValue
  of wtBool: node.litValue
  of wtString: 
    &"\"{escapeString(node.litValue)}\""
  else: "NULL"

proc generateStringInterpolationPart(g: var CodeGenerator, part: Node): string =
  case part.kind
  of nkLiteral:
    if part.litType == wtString:
      &"\"{escapeString(part.litValue)}\""
    else:
      # Для нестроковых литералов используем прямое значение
      case part.litType
      of wtInt: &"__to_str({part.litValue})"       # __to_str(42)
      of wtFloat: &"__to_str({part.litValue})"     # __to_str(3.14)
      of wtBool: &"__to_str({part.litValue})"      # __to_str(true)
      else: "\"\""
  
  of nkIdentifier:
    let varName = g.generateIdentifier(part.identName)
    &"__to_str({varName})"
  
  else:
    g.state.error(&"Неподдерживаемый элемент интерполяции: {part.kind}", 
                  part.line, part.column)
    "\"\""

proc generateStringInterpolation(g: var CodeGenerator, node: Node): string =
  if node.interpParts.len == 0:
    return "\"\""  # Пустая строка
  
  let bufVar = g.getTempVar()
  
  g.writeln(&"char {bufVar}[1024];")
  g.writeln(&"{bufVar}[0] = '\\0';")
  
  for i, part in node.interpParts:
    let partCode = g.generateStringInterpolationPart(part)
    
    if i == 0:
      g.writeln(&"strcpy({bufVar}, {partCode});")
    else:
      g.writeln(&"strcat({bufVar}, {partCode});")
  
  return bufVar

proc generateExpression(g: var CodeGenerator, node: Node): string =
  case node.kind
  of nkLiteral:
    g.generateLiteral(node)
  of nkIdentifier:
    g.generateIdentifier(node.identName)
  of nkStringInterpolation:
    g.generateStringInterpolation(node)
  else:
    g.state.error(&"Неподдерживаемое выражение: {node.kind}", node.line, node.column)
    ""

proc generateSendln(g: var CodeGenerator, node: Node) =
  let arg = g.generateExpression(node.sendlnArg)
  g.writeln(&"printf(\"%s\\n\", {arg});")

proc generateVarDecl(g: var CodeGenerator, node: Node) =
  let ctype = typeToCType(node.declType)
  let value = g.generateExpression(node.declValue)
  
  if node.kind == nkConstDecl:
    g.writeln(&"const {ctype} {node.declName} = {value};")
  else:
    g.writeln(&"{ctype} {node.declName} = {value};")

proc generateAssignment(g: var CodeGenerator, node: Node) =
  let target = g.generateIdentifier(node.assignName)
  let value = g.generateExpression(node.assignValue)
  g.writeln(&"{target} = {value};")

proc generateRefactor(g: var CodeGenerator, node: Node) =
  let target = node.refactorTarget.identName
  
  case node.refactorToType
  of wtString:
    let strVar = target & "_str"
    
    if node.refactorValue != nil:
      let value = g.generateExpression(node.refactorValue)
      g.writeln(&"char* {strVar} = {value};")
    else:
      g.writeln(&"char {strVar}_buf[256];")
      g.writeln(&"sprintf({strVar}_buf, \"%s\", {target});")
      g.writeln(&"char* {strVar} = {strVar}_buf;")
    
    # Запоминаем преобразование
    g.typeMap[target] = strVar
    
  of wtInt:
    let varName = g.generateIdentifier(target)
    g.writeln(&"{varName} = (int){varName};")
  of wtFloat:
    let varName = g.generateIdentifier(target)
    g.writeln(&"{varName} = (double){varName};")
  of wtBool:
    let varName = g.generateIdentifier(target)
    g.writeln(&"{varName} = (bool){varName};")
  else:
    g.state.error(&"Неподдерживаемое преобразование типа: {node.refactorToType}", 
                  node.line, node.column)

proc generateNode(g: var CodeGenerator, node: Node) =
  case node.kind
  of nkVarDecl, nkConstDecl:
    g.generateVarDecl(node)
  of nkAssignment:
    g.generateAssignment(node)
  of nkSendln:
    g.generateSendln(node)
  of nkRefactor:
    g.generateRefactor(node)
  else:
    g.state.error(&"Неподдерживаемый узел AST: {node.kind}", node.line, node.column)

proc generateCode*(g: var CodeGenerator, ast: Node): string =
  ## Генерирует C-код из AST
  
  # Заголовок
  g.writeln("// Сгенерировано компилятором Wolfram")
  g.writeln("#include <stdio.h>")
  g.writeln("#include <stdbool.h>")
  g.writeln("#include <string.h>")
  g.writeln("#include <stdlib.h>")
  g.writeln("#include <math.h>")
  
  # Вспомогательные функции
  g.writeln("")
  g.writeln("char* __nice_float_to_str(double value) {")
  g.indent()
  g.writeln("char* buf = malloc(32);")
  g.writeln("if (fmod(value, 1.0) == 0.0) {")
  g.writeln("  sprintf(buf, \"%.0f\", value);")
  g.writeln("} else if (fmod(value * 10, 1.0) == 0.0) {")
  g.writeln("  sprintf(buf, \"%.1f\", value);")
  g.writeln("} else if (fmod(value * 100, 1.0) == 0.0) {")
  g.writeln("  sprintf(buf, \"%.2f\", value);")
  g.writeln("} else {")
  g.writeln("  sprintf(buf, \"%.2f\", value);")
  g.writeln("}")
  g.writeln("return buf;")
  g.unindent()
  g.writeln("}")
  g.writeln("")
  
  g.writeln("char* __int_to_str(int value) {")
  g.indent()
  g.writeln("char* buf = malloc(32);")
  g.writeln("sprintf(buf, \"%d\", value);")
  g.writeln("return buf;")
  g.unindent()
  g.writeln("}")
  g.writeln("")
  
  g.writeln("char* __float_to_str(double value) {")
  g.indent()
  g.writeln("return __nice_float_to_str(value);")
  g.unindent()
  g.writeln("}")
  g.writeln("")
  
  g.writeln("char* __bool_to_str(bool value) {")
  g.indent()
  g.writeln("return value ? \"true\" : \"false\";")
  g.unindent()
  g.writeln("}")
  g.writeln("")
  
  g.writeln("char* __str_to_str(char* value) {")
  g.indent()
  g.writeln("return value;")
  g.unindent()
  g.writeln("}")
  g.writeln("")
  
  g.writeln("#define __to_str(x) _Generic((x), \\")
  g.writeln("  int: __int_to_str, \\")
  g.writeln("  double: __float_to_str, \\")
  g.writeln("  bool: __bool_to_str, \\")
  g.writeln("  char*: __str_to_str \\")
  g.writeln(")(x)")
  g.writeln("")
  
  g.writeln("int main() {")
  g.indent()
  
  for stmt in ast.statements:
    g.generateNode(stmt)
  
  g.unindent()
  g.writeln("  return 0;")
  g.writeln("}")
  
  return g.output

proc initCodeGenerator*(): CodeGenerator =
  CodeGenerator(
    output: "", 
    indentLevel: 0,
    state: CompilerState(),
    typeMap: initTable[string, string](),
    tempCounter: 0
  )