## Компилятор Wolfram -> C (промежуточный этап)

import strformat, strutils
import ./types, ./errors

type
  CodeGenerator* = object
    output*: string
    indentLevel*: int
    state*: CompilerState

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

proc generateLiteral(g: var CodeGenerator, node: Node): string =
  case node.litType
  of wtInt: node.litValue
  of wtFloat: node.litValue
  of wtBool: node.litValue
  of wtString: &"\"{node.litValue}\""
  else: "NULL"

proc generateExpression(g: var CodeGenerator, node: Node): string =
  case node.kind
  of nkLiteral:
    g.generateLiteral(node)
  of nkIdentifier:
    node.identName
  else:
    g.state.error(&"Неподдерживаемое выражение: {node.kind}", node.line, node.column)
    ""

proc generateVarDecl(g: var CodeGenerator, node: Node) =
  let ctype = typeToCType(node.declType)
  let value = g.generateExpression(node.declValue)
  
  if node.kind == nkConstDecl:
    g.writeln(&"const {ctype} {node.declName} = {value};")
  else:
    g.writeln(&"{ctype} {node.declName} = {value};")

proc generateAssignment(g: var CodeGenerator, node: Node) =
  let value = g.generateExpression(node.assignValue)
  g.writeln(&"{node.assignName} = {value};")

proc generateSendln(g: var CodeGenerator, node: Node) =
  let arg = g.generateExpression(node.sendlnArg)
  # Временная реализация - просто printf
  g.writeln(&"printf(\"%s\\n\", {arg});")

proc generateRefactor(g: var CodeGenerator, node: Node) =
  let target = g.generateExpression(node.refactorTarget)
  let toType = typeToCType(node.refactorToType)
  
  # Преобразование типов в C
  case node.refactorToType
  of wtString:
    g.writeln(&"char __refactor_buf[256];")
    g.writeln(&"sprintf(__refactor_buf, \"%s\", (char*){target});")
    g.writeln(&"{target} = __refactor_buf;")
  of wtInt:
    g.writeln(&"{target} = (int){target};")
  of wtFloat:
    g.writeln(&"{target} = (double){target};")
  of wtBool:
    g.writeln(&"{target} = (bool){target};")
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
  g.writeln()
  g.writeln("int main() {")
  g.indent()
  
  # Генерация кода
  for stmt in ast.statements:
    g.generateNode(stmt)
  
  g.unindent()
  g.writeln("  return 0;")
  g.writeln("}")
  
  return g.output

proc initCodeGenerator*(): CodeGenerator =
  CodeGenerator(output: "", indentLevel: 0)