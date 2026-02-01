## Лексер и парсер для языка Wolfram

import strformat, tables
import ./types, ./errors

type
  Lexer* = object
    input*: string
    position*: int      # текущая позиция в input
    readPosition*: int  # следующая позиция для чтения
    ch*: char          # текущий символ
    line*: int         # текущая строка
    column*: int       # текущая колонка
  
  Parser* = object
    lexer*: Lexer
    curToken*: Token
    peekToken*: Token
    state*: CompilerState

# Ключевые слова
const Keywords = {
  "int": tkLet, "float": tkLet, "bool": tkLet, "str": tkLet,
  "const": tkConst, "true": tkBool, "false": tkBool,
  "if": tkIf, "else": tkElse, "while": tkWhile,
  "sendln": tkSendln, "refactor": tkRefactor
}.toTable

# Вспомогательные процедуры
proc isLetter(ch: char): bool = ch in {'a'..'z', 'A'..'Z', '_'}
proc isDigit(ch: char): bool = ch in {'0'..'9'}
proc isWhitespace(ch: char): bool = ch in {' ', '\t', '\r', '\n'}

# Лексер
proc readChar(l: var Lexer) =
  if l.readPosition >= l.input.len:
    l.ch = '\0'
  else:
    l.ch = l.input[l.readPosition]
  
  l.position = l.readPosition
  l.readPosition += 1
  l.column += 1
  
  if l.ch == '\n':
    l.line += 1
    l.column = 0

proc initLexer*(input: string): Lexer =
  result.input = input
  result.line = 1
  result.column = 0
  result.readChar()

proc peekChar(l: Lexer): char =
  if l.readPosition >= l.input.len:
    return '\0'
  return l.input[l.readPosition]

proc skipWhitespace(l: var Lexer) =
  while isWhitespace(l.ch):
    if l.ch == '\n':
      l.line += 1
      l.column = 0
    l.readChar()

proc readIdentifier(l: var Lexer): string =
  let start = l.position
  while isLetter(l.ch) or isDigit(l.ch):
    l.readChar()
  l.input[start..<l.position]

proc readNumber(l: var Lexer): (string, TokenKind) =
  let start = l.position
  var isFloat = false
  
  while isDigit(l.ch) or l.ch == '.':
    if l.ch == '.':
      if isFloat:
        break
      isFloat = true
    l.readChar()
  
  let num = l.input[start..<l.position]
  if isFloat:
    return (num, tkFloat)
  else:
    return (num, tkInt)

proc readString(l: var Lexer): string =
  l.readChar() # пропускаем открывающую кавычку
  let start = l.position
  
  while l.ch != '"' and l.ch != '\0':
    if l.ch == '\\':
      l.readChar() # пропускаем escape-символ
    l.readChar()
  
  let str = l.input[start..<l.position]
  l.readChar() # пропускаем закрывающую кавычку
  return str

proc nextToken*(l: var Lexer): Token =
  l.skipWhitespace()
  
  var token: Token
  token.line = l.line
  token.column = l.column
  
  case l.ch
  of '=':
    if l.peekChar() == '=':
      l.readChar()
      token.kind = tkEqEq
      token.literal = "=="
    else:
      token.kind = tkEq
      token.literal = "="
  of '+':
    token.kind = tkPlus
    token.literal = "+"
  of '-':
    if l.peekChar() == '>':
      l.readChar()
      token.kind = tkArrow
      token.literal = "->"
    else:
      token.kind = tkMinus
      token.literal = "-"
  of '*':
    token.kind = tkStar
    token.literal = "*"
  of '/':
    if l.peekChar() == '/':
      # Пропускаем комментарии
      while l.ch != '\n' and l.ch != '\0':
        l.readChar()
      return l.nextToken()
    else:
      token.kind = tkSlash
      token.literal = "/"
  of '%':
    token.kind = tkPercent
    token.literal = "%"
  of '<':
    if l.peekChar() == '=':
      l.readChar()
      token.kind = tkLtEq
      token.literal = "<="
    else:
      token.kind = tkLt
      token.literal = "<"
  of '>':
    if l.peekChar() == '=':
      l.readChar()
      token.kind = tkGtEq
      token.literal = ">="
    else:
      token.kind = tkGt
      token.literal = ">"
  of '!':
    if l.peekChar() == '=':
      l.readChar()
      token.kind = tkNotEq
      token.literal = "!="
    else:
      token.kind = tkIllegal
      token.literal = "!"
  of '(':
    token.kind = tkLParen
    token.literal = "("
  of ')':
    token.kind = tkRParen
    token.literal = ")"
  of '{':
    token.kind = tkLBrace
    token.literal = "{"
  of '}':
    token.kind = tkRBrace
    token.literal = "}"
  of ':':
    if l.peekChar() == ':':
      l.readChar()
      token.kind = tkColonColon
      token.literal = "::"
    else:
      token.kind = tkColon
      token.literal = ":"
  of ';':
    token.kind = tkSemi
    token.literal = ";"
  of ',':
    token.kind = tkComma
    token.literal = ","
  of '"':
    token.kind = tkString
    token.literal = l.readString()
    return token
  of '\0':
    token.kind = tkEOF
    token.literal = ""
  else:
    if isLetter(l.ch):
      let ident = l.readIdentifier()
      if Keywords.hasKey(ident):
        token.kind = Keywords[ident]
      else:
        token.kind = tkIdent
      token.literal = ident
      return token
    elif isDigit(l.ch):
      let (num, kind) = l.readNumber()
      token.kind = kind
      token.literal = num
      return token
    else:
      token.kind = tkIllegal
      token.literal = $l.ch
  
  l.readChar()
  return token

proc newParser*(input: string): Parser =
  var p: Parser
  p.lexer = initLexer(input)
  p.curToken = p.lexer.nextToken()
  p.peekToken = p.lexer.nextToken()
  p.state = CompilerState(errors: @[], warnings: @[])  # Явная инициализация
  return p

proc nextToken(p: var Parser) =
  p.curToken = p.peekToken
  p.peekToken = p.lexer.nextToken()

proc expectPeek(p: var Parser, kind: TokenKind): bool =
  if p.peekToken.kind == kind:
    p.nextToken()
    return true
  else:
    p.state.error(&"Ожидался токен {kind}, получен {p.peekToken.kind}", 
                  p.peekToken.line, p.peekToken.column)
    return false

proc parseType(p: var Parser): (WolframType, bool) =
  var typ: WolframType
  var isConst = false
  
  # Явно определяем тип
  case p.curToken.literal
  of "int": typ = wtInt
  of "float": typ = wtFloat  
  of "bool": typ = wtBool
  of "str": typ = wtString
  else:
    p.state.error(&"Неизвестный тип: {p.curToken.literal}", 
                  p.curToken.line, p.curToken.column)
    return (wtUnknown, false)  # ЯВНЫЙ RETURN
  
  # Проверяем, есть ли модификатор ::const
  if p.peekToken.kind == tkColonColon:
    p.nextToken() # Пропускаем ::
    if p.expectPeek(tkConst):
      isConst = true
    else:
      p.state.error("Ожидался 'const' после '::'", 
                    p.curToken.line, p.curToken.column)
      return (typ, false)  # ЯВНЫЙ RETURN
  
  return (typ, isConst)

proc parseLiteral(p: var Parser): Node =
  let node = Node(kind: nkLiteral, line: p.curToken.line, column: p.curToken.column)
  
  case p.curToken.kind
  of tkInt:
    node.litType = wtInt
    node.litValue = p.curToken.literal
  of tkFloat:
    node.litType = wtFloat
    node.litValue = p.curToken.literal
  of tkBool:
    node.litType = wtBool
    node.litValue = p.curToken.literal
  of tkString:
    node.litType = wtString
    node.litValue = p.curToken.literal
  else:
    p.state.error(&"Недопустимый литерал: {p.curToken.literal}", 
                  p.curToken.line, p.curToken.column)
    return nil
  
  return node

proc parseIdentifier(p: Parser): Node =
  Node(
    kind: nkIdentifier,
    line: p.curToken.line,
    column: p.curToken.column,
    identName: p.curToken.literal
  )

proc parseExpression(p: var Parser): Node =
  case p.curToken.kind
  of tkInt, tkFloat, tkBool, tkString:
    return p.parseLiteral()
  of tkIdent:
    return p.parseIdentifier()
  else:
    p.state.error(&"Недопустимое выражение: {p.curToken.literal}", 
                  p.curToken.line, p.curToken.column)
    return nil

proc parseVarDecl(p: var Parser): Node =
  let line = p.curToken.line
  let column = p.curToken.column
  
  # Парсим тип и модификаторы (например, "str::const")
  let (typ, isConst) = p.parseType()
  
  if typ == wtUnknown:
    return nil
  
  # Имя переменной
  if not p.expectPeek(tkIdent):
    return nil
  
  let name = p.curToken.literal
  
  # Знак равно
  if not p.expectPeek(tkEq):
    return nil
  
  # Значение
  p.nextToken() # переходим к значению
  let value = p.parseExpression()
  
  if value == nil:
    return nil
  
  # Точка с запятой
  if not p.expectPeek(tkSemi):
    return nil
  
  # Создаем узел
  let node = if isConst:
    Node(kind: nkConstDecl, line: line, column: column)
  else:
    Node(kind: nkVarDecl, line: line, column: column)
  
  node.declName = name
  node.declType = typ
  node.declValue = value
  
  return node

proc parseAssignment(p: var Parser): Node =
  let line = p.curToken.line
  let column = p.curToken.column
  let name = p.curToken.literal
  
  if not p.expectPeek(tkEq):
    return nil
  
  p.nextToken() # переходим к значению
  let value = p.parseExpression()
  
  if value == nil:
    return nil
  
  if not p.expectPeek(tkSemi):
    return nil
  
  Node(
    kind: nkAssignment,
    line: line,
    column: column,
    assignName: name,
    assignValue: value
  )

proc parseSendln(p: var Parser): Node =
  let line = p.curToken.line
  let column = p.curToken.column
  
  if not p.expectPeek(tkLParen):
    return nil
  
  p.nextToken() # переходим к аргументу
  let arg = p.parseExpression()
  
  if arg == nil:
    return nil
  
  if not p.expectPeek(tkRParen):
    return nil
  
  if not p.expectPeek(tkSemi):
    return nil
  
  Node(
    kind: nkSendln,
    line: line,
    column: column,
    sendlnArg: arg
  )

proc parseRefactor(p: var Parser): Node =
  let line = p.curToken.line
  let column = p.curToken.column
  
  if not p.expectPeek(tkLParen):
    return nil
  
  p.nextToken() # переходим к целевой переменной
  let target = p.parseExpression()
  
  if target == nil:
    return nil
  
  if not p.expectPeek(tkRParen):
    return nil
  
  if not p.expectPeek(tkFatArrow):
    return nil
  
  if not p.expectPeek(tkIdent):
    return nil
  
  # Парсим тип для refactor (без модификаторов)
  let toTypeStr = p.curToken.literal
  var toType = wtUnknown
  
  case toTypeStr
  of "int": toType = wtInt
  of "float": toType = wtFloat
  of "bool": toType = wtBool
  of "str": toType = wtString
  else:
    p.state.error(&"Неизвестный тип: {toTypeStr}", 
                  p.curToken.line, p.curToken.column)
    return nil
  
  # Проверяем, есть ли значение для refactor
  if p.peekToken.kind == tkLParen:
    p.nextToken() # Пропускаем (
    if not p.expectPeek(tkString):
      p.state.error("Ожидалась строка в refactor", 
                    p.curToken.line, p.curToken.column)
      return nil
    
    # TODO: обработать значение для refactor
    let refactorValue = p.curToken.literal
    
    if not p.expectPeek(tkRParen):
      return nil
  
  if not p.expectPeek(tkSemi):
    return nil
  
  Node(
    kind: nkRefactor,
    line: line,
    column: column,
    refactorTarget: target,
    refactorToType: toType
  )

proc parseStatement(p: var Parser): Node =
  # Проверяем, является ли токен типом (int, float, bool, str)
  case p.curToken.literal
  of "int", "float", "bool", "str":
    # Это объявление переменной или константы
    return p.parseVarDecl()
  else:
    case p.curToken.kind
    of tkIdent:
      # Это может быть присваивание или вызов функции
      # Простая проверка: если следующий токен =, то это присваивание
      if p.peekToken.kind == tkEq:
        return p.parseAssignment()
      else:
        # TODO: добавить обработку вызовов функций
        p.state.error(&"Нераспознанная конструкция: {p.curToken.literal}", 
                      p.curToken.line, p.curToken.column)
        return nil
    of tkSendln:
      return p.parseSendln()
    of tkRefactor:
      return p.parseRefactor()
    else:
      p.state.error(&"Недопустимое выражение: {p.curToken.literal}", 
                    p.curToken.line, p.curToken.column)
      return nil

proc parseProgram*(p: var Parser): Node =
  let program = Node(kind: nkProgram, line: 1, column: 1)
  
  while p.curToken.kind != tkEOF:
    let stmt = p.parseStatement()
    if stmt != nil:
      program.statements.add(stmt)
    p.nextToken()
  
  return program