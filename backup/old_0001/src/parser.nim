## Лексер и парсер для языка PD

import strformat, tables, strutils
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

# Forward declarations
proc parseFunctionCall(p: var Parser): Node
proc parseReturnStatement(p: var Parser): Node
proc parseFunctionDecl(p: var Parser): Node
proc parseStatement(p: var Parser): Node
proc parseExpression(p: var Parser): Node
proc parsePrimaryExpr(p: var Parser): Node
proc parseBinaryExpr(p: var Parser, minPrec: int): Node
proc parseBlock(p: var Parser): Node
proc parseIfStatement(p: var Parser): Node

# Ключевые слова
const Keywords = {
  "int": tkTypeInt, "float": tkTypeFloat, "bool": tkTypeBool, "str": tkTypeStr,
  "const": tkConst, "true": tkBool, "false": tkBool,
  "if": tkIf, "else": tkElse, "while": tkWhile,
  "sendln": tkSendln, "refactor": tkRefactor,
  "func": tkFunc,
  "return": tkReturn,
  "static": tkStatic
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
    if l.peekChar() == '>':
      l.readChar()
      token.kind = tkFatArrow
      token.literal = "=>"
    elif l.peekChar() == '=':
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
      # Пропускаем однострочные комментарии
      while l.ch != '\n' and l.ch != '\0':
        l.readChar()
      return l.nextToken()  # Возвращаем следующий токен после комментария
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

# Парсер
proc newParser*(input: string): Parser =
  var p: Parser
  p.lexer = initLexer(input)
  p.curToken = p.lexer.nextToken()
  p.peekToken = p.lexer.nextToken()
  p.state = CompilerState(errors: @[], warnings: @[])
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
  
  # Определяем тип по TokenKind
  case p.curToken.kind
  of tkTypeInt: typ = wtInt
  of tkTypeFloat: typ = wtFloat
  of tkTypeBool: typ = wtBool
  of tkTypeStr: typ = wtString
  else:
    p.state.error(&"Неизвестный тип: {p.curToken.literal}", 
                  p.curToken.line, p.curToken.column)
    return (wtUnknown, false)
  
  # Проверяем, есть ли модификатор ::const
  if p.peekToken.kind == tkColonColon:
    p.nextToken() # Пропускаем ::
    if p.expectPeek(tkConst):
      isConst = true
    else:
      p.state.error("Ожидался 'const' после '::'", 
                    p.curToken.line, p.curToken.column)
      return (typ, false)
  
  return (typ, isConst)

proc parseStringInterpolation(p: var Parser, strValue: string): Node =
  ## Парсит строку с интерполяцией типа "{{x}}!"
  let line = p.curToken.line
  let column = p.curToken.column
  
  var parts: seq[Node]
  var i = 0
  
  while i < strValue.len:
    if i + 1 < strValue.len and strValue[i] == '{' and strValue[i+1] == '{':
      # Нашли начало интерполяции {{ 
      i += 2  # Пропускаем {{
      
      # Ищем закрывающие }}
      var varStart = i
      while i < strValue.len and not (strValue[i] == '}' and i+1 < strValue.len and strValue[i+1] == '}'):
        i += 1
      
      if i >= strValue.len or not (strValue[i] == '}' and strValue[i+1] == '}'):
        p.state.error("Незакрытая интерполяция строки", line, column)
        return nil
      
      let varName = strValue[varStart..<i].strip()
      
      # Создаем узел для переменной
      let varNode = Node(
        kind: nkIdentifier,
        line: line,
        column: column,
        identName: varName
      )
      parts.add(varNode)
      
      i += 2  # Пропускаем }}
    else:
      # Обычный текст
      var textStart = i
      while i < strValue.len and not (i+1 < strValue.len and strValue[i] == '{' and strValue[i+1] == '{'):
        i += 1
      
      if textStart < i:
        let text = strValue[textStart..<i]
        if text.len > 0:
          let textNode = Node(
            kind: nkLiteral,
            line: line,
            column: column,
            litType: wtString,
            litValue: text
          )
          parts.add(textNode)
  
  # Создаем узел интерполяции
  if parts.len == 1 and parts[0].kind == nkLiteral:
    # Если только текст без интерполяции, возвращаем просто литерал
    return parts[0]
  else:
    return Node(
      kind: nkStringInterpolation,
      line: line,
      column: column,
      interpParts: parts
    )

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
    # Проверяем на интерполяцию
    if "{{" in p.curToken.literal:
      return p.parseStringInterpolation(p.curToken.literal)
    else:
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
  ## Парсит выражение с учетом приоритетов операторов
  return p.parseBinaryExpr(1)

proc parsePrimaryExpr(p: var Parser): Node =
  ## Парсит первичное выражение (литерал, идентификатор, выражение в скобках)
  case p.curToken.kind
  of tkInt, tkFloat, tkBool, tkString:
    return p.parseLiteral()
  of tkIdent:
    if p.peekToken.kind == tkLParen:
      return p.parseFunctionCall()
    else:
      return p.parseIdentifier()
  of tkLParen:
    # Выражение в скобках: (x + y)
    p.nextToken()  # пропускаем (
    let expr = p.parseExpression()
    if not p.expectPeek(tkRParen):
      return nil
    return expr
  else:
    p.state.error(&"Недопустимое выражение: {p.curToken.literal}", 
                  p.curToken.line, p.curToken.column)
    return nil

proc getPrecedence(kind: TokenKind): int =
  ## Возвращает приоритет оператора
  case kind
  of tkEqEq, tkNotEq: 2
  of tkLt, tkGt, tkLtEq, tkGtEq: 3
  of tkPlus, tkMinus: 4
  of tkStar, tkSlash, tkPercent: 5
  else: 1

proc parseBinaryExpr(p: var Parser, minPrec: int): Node =
  ## Парсит бинарное выражение с учетом приоритетов (алгоритм Пратта)
  var left = p.parsePrimaryExpr()
  if left == nil:
    return nil
  
  while true:
    let op = p.peekToken.kind
    let prec = getPrecedence(op)
    
    if prec < minPrec:
      break
    
    p.nextToken()  # переходим на оператор
    let opToken = p.curToken.kind
    p.nextToken()  # переходим на правый операнд
    
    var right = p.parseBinaryExpr(prec + 1)
    if right == nil:
      return nil
    
    left = Node(
      kind: nkBinaryExpr,
      line: left.line,
      column: left.column,
      left: left,
      right: right,
      op: opToken
    )
  
  return left

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
  
  # Аргументом может быть что угодно: переменная, строка, число, интерполяция
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
  
  # Просто получаем следующий токен и проверяем, что это тип
  p.nextToken()
  if p.curToken.kind notin {tkTypeInt, tkTypeFloat, tkTypeBool, tkTypeStr}:
    p.state.error("Ожидался тип (int, float, bool, str)", p.curToken.line, p.curToken.column)
    return nil
  
  # Определяем тип
  var toType = wtUnknown
  case p.curToken.kind
  of tkTypeInt: toType = wtInt
  of tkTypeFloat: toType = wtFloat
  of tkTypeBool: toType = wtBool
  of tkTypeStr: toType = wtString
  else: discard
  
  # Проверяем, есть ли значение в скобках
  var refactorValue: Node = nil
  
  if p.peekToken.kind == tkLParen:
    p.nextToken() # Пропускаем (
    p.nextToken() # Переходим к значению
    refactorValue = p.parseExpression()
    
    if refactorValue == nil:
      return nil
    
    if not p.expectPeek(tkRParen):
      return nil
  
  if not p.expectPeek(tkSemi):
    return nil
  
  # Создаем узел
  let node = Node(
    kind: nkRefactor,
    line: line,
    column: column,
    refactorTarget: target,
    refactorToType: toType,
    refactorValue: refactorValue
  )
  
  return node

proc parseBlock(p: var Parser): Node =
  ## Парсит блок кода в фигурных скобках
  let line = p.curToken.line
  let column = p.curToken.column
  
  if not p.expectPeek(tkLBrace):
    return nil
  
  p.nextToken()  # переходим к первому токену в блоке
  
  var statements: seq[Node] = @[]
  
  while p.curToken.kind != tkRBrace and p.curToken.kind != tkEOF:
    let stmt = p.parseStatement()
    if stmt != nil:
      statements.add(stmt)
    p.nextToken()
  
  result = Node(
    kind: nkBlock,
    line: line,
    column: column,
    blockStmts: statements
  )

proc parseIfStatement(p: var Parser): Node =
  echo "parseIfStatement возвращает, токен: ", p.curToken.kind, " '", p.curToken.literal, "'"
  ## Парсит if (cond) { ... } elsif (cond) { ... } else { ... }
  let line = p.curToken.line
  let column = p.curToken.column
  
  # if (cond)
  if not p.expectPeek(tkLParen):
    return nil
  
  p.nextToken()  # переходим к условию
  let cond = p.parseExpression()
  if cond == nil:
    return nil
  
  if not p.expectPeek(tkRParen):
    return nil
  
  # then-блок
  p.nextToken()  # переходим к {
  let thenBlock = p.parseBlock()
  if thenBlock == nil:
    return nil
  
  # Парсим elsif ветки
  var elsifs: seq[Node] = @[]
  var elseBlock: Node = nil
  
  p.nextToken()  # переходим к следующему токену после блока
  
  while p.curToken.kind == tkElse:
    p.nextToken()  # пропускаем else
    
    if p.curToken.kind == tkIf:  # elsif
      p.nextToken()  # пропускаем if
      
      if not p.expectPeek(tkLParen):
        return nil
      
      p.nextToken()  # переходим к условию
      let elsifCond = p.parseExpression()
      if elsifCond == nil:
        return nil
      
      if not p.expectPeek(tkRParen):
        return nil
      
      p.nextToken()  # переходим к блоку
      let elsifBlock = p.parseBlock()
      if elsifBlock == nil:
        return nil
      
      let elsifNode = Node(
        kind: nkElsif,
        line: line,
        column: column,
        elsifCond: elsifCond,
        elsifBody: elsifBlock
      )
      elsifs.add(elsifNode)
      
      p.nextToken()  # переходим к следующему токену
      
    else:  # просто else
      elseBlock = p.parseBlock()
      if elseBlock == nil:
        return nil
      break
  
  # Создаем if-узел
  result = Node(
    kind: nkIf,
    line: line,
    column: column,
    ifCond: cond,
    ifThen: thenBlock,
    ifElsifs: elsifs,
    ifElse: elseBlock
  )

proc parseFunctionCall(p: var Parser): Node =
  ## Парсит вызов функции: name();
  let line = p.curToken.line
  let column = p.curToken.column
  let name = p.curToken.literal
  
  # Проверяем скобки
  if not p.expectPeek(tkLParen):
    return nil
  
  if not p.expectPeek(tkRParen):
    return nil
  
  # Проверяем точку с запятой
  if not p.expectPeek(tkSemi):
    return nil
  
  result = Node(
    kind: nkFunctionCall,
    line: line,
    column: column,
    callName: name
  )

proc parseReturnStatement(p: var Parser): Node =
  ## Парсит return выражение: return 0;
  let line = p.curToken.line
  let column = p.curToken.column
  
  p.nextToken() # Переходим к возвращаемому значению
  
  # Парсим возвращаемое выражение
  let returnValue = p.parseExpression()
  if returnValue == nil:
    return nil
  
  # Проверяем точку с запятой
  if not p.expectPeek(tkSemi):
    return nil
  
  result = Node(
    kind: nkReturn,
    line: line,
    column: column,
    returnValue: returnValue
  )

proc parseFunctionDecl(p: var Parser): Node =
  ## Парсит объявление функции: func::name() { ... }
  let line = p.curToken.line
  let column = p.curToken.column
  
  echo "parseFunctionDecl: начинаем парсинг функции"
  
  # p.curToken сейчас указывает на tkFunc
  p.nextToken()  # ПРОПУСКАЕМ tkFunc - переходим к ::
  
  # Проверяем, что после func идет ::
  if p.curToken.kind != tkColonColon:
    p.state.error("Ожидался '::' после 'func'", p.curToken.line, p.curToken.column)
    return nil
  
  p.nextToken()  # Пропускаем :: - переходим к имени функции
  
  # Имя функции
  if p.curToken.kind != tkIdent:
    p.state.error("Ожидалось имя функции", p.curToken.line, p.curToken.column)
    return nil
  
  let name = p.curToken.literal
  echo "  имя функции: ", name
  
  p.nextToken()  # Переходим к (
  
  # Параметры (пока только пустые скобки)
  if p.curToken.kind != tkLParen:
    p.state.error("Ожидалась (", p.curToken.line, p.curToken.column)
    return nil
  
  p.nextToken()  # Пропускаем (
  
  if p.curToken.kind != tkRParen:
    p.state.error("Ожидалась )", p.curToken.line, p.curToken.column)
    return nil
  
  p.nextToken()  # Пропускаем ) - переходим к возможному : или {
  
  # Проверяем, есть ли модификатор static
  var funcKind = fkNormal
  
  if p.curToken.kind == tkColon:
    p.nextToken() # Пропускаем :
    
    if p.curToken.kind == tkStatic:
      funcKind = fkStatic
      echo "  модификатор: static"
      p.nextToken() # Пропускаем static - переходим к {
    else:
      p.state.error("Ожидался 'static' после ':'", 
                    p.curToken.line, p.curToken.column)
      return nil
  
  # Теперь p.curToken должен указывать на {
  if p.curToken.kind != tkLBrace:
    p.state.error("Ожидалась { для тела функции", p.curToken.line, p.curToken.column)
    return nil
  
  p.nextToken() # Переходим к первому токену в теле
  echo "  начинаем парсинг тела функции"
  
  var body: seq[Node] = @[]
  
  # Парсим тело функции до закрывающей скобки
  while p.curToken.kind != tkRBrace and p.curToken.kind != tkEOF:
    echo "    токен в теле: ", p.curToken.kind, " '", p.curToken.literal, "'"
    
    # Внутри функции могут быть те же конструкции, что и раньше
    case p.curToken.kind
    of tkTypeInt, tkTypeFloat, tkTypeBool, tkTypeStr:
      let stmt = p.parseVarDecl()
      if stmt != nil:
        body.add(stmt)
    
    of tkIdent:
      if p.peekToken.kind == tkLParen:
        let stmt = p.parseFunctionCall()
        if stmt != nil:
          body.add(stmt)
      elif p.peekToken.kind == tkEq:
        let stmt = p.parseAssignment()
        if stmt != nil:
          body.add(stmt)
      else:
        p.nextToken()  # пропускаем
    
    of tkSendln:
      let stmt = p.parseSendln()
      if stmt != nil:
        body.add(stmt)
    
    of tkRefactor:
      let stmt = p.parseRefactor()
      if stmt != nil:
        body.add(stmt)
    
    of tkReturn:
      let stmt = p.parseReturnStatement()
      if stmt != nil:
        body.add(stmt)
    
    of tkIf:
      let stmt = p.parseIfStatement()
      if stmt != nil:
        body.add(stmt)
    
    else:
      # Пропускаем служебные токены внутри функции
      p.nextToken()
  
  echo "  закончили парсинг тела функции"
  
  # Проверяем, что закрывающая скобка есть
  if p.curToken.kind == tkRBrace:
    p.nextToken()  # Переходим к следующему токену после }
  else:
    p.state.error("Ожидалась закрывающая скобка }", line, column)
    return nil
  
  # Создаем узел функции
  result = Node(
    kind: nkFunctionDecl,
    line: line,
    column: column,
    funcName: name,
    funcKind: funcKind,
    funcBody: body
  )
  
  echo "parseFunctionDecl: завершили парсинг функции ", name, ", следующий токен: ", p.curToken.kind, " '", p.curToken.literal, "'"

proc parseStatement(p: var Parser): Node =
  echo "parseStatement: ", p.curToken.kind, " '", p.curToken.literal, "'"
  
  # Пропускаем служебные токены
  if p.curToken.kind in {tkColonColon, tkLBrace, tkRBrace, tkLParen, tkRParen, tkSemi, tkComma}:
    echo "  пропускаем служебный токен"
    p.nextToken()
    return nil  # возвращаем nil, но токен уже продвинут
  
  # Запоминаем начальный токен для проверки
  let startToken = p.curToken
  
  case p.curToken.kind
  of tkTypeInt, tkTypeFloat, tkTypeBool, tkTypeStr:
    result = p.parseVarDecl()
  of tkIdent:
    if p.peekToken.kind == tkLParen:
      result = p.parseFunctionCall()
    elif p.peekToken.kind == tkEq:
      result = p.parseAssignment()
    else:
      p.state.error(&"Нераспознанная конструкция: {p.curToken.literal}", 
                    p.curToken.line, p.curToken.column)
      p.nextToken()
      return nil
  of tkSendln:
    result = p.parseSendln()
  of tkRefactor:
    result = p.parseRefactor()
  of tkFunc:
    result = p.parseFunctionDecl()
  of tkReturn:
    result = p.parseReturnStatement()
  of tkIf:
    result = p.parseIfStatement()
  else:
    p.state.error(&"Недопустимое выражение: {p.curToken.kind} '{p.curToken.literal}'", 
                  p.curToken.line, p.curToken.column)
    p.nextToken()
    return nil
  
  # Проверяем, продвинулся ли токен
  if p.curToken == startToken:
    echo "ВНИМАНИЕ: parseStatement не продвинул токен для ", startToken.kind
    p.nextToken()
  
  return result

proc parseProgram*(p: var Parser): Node =
  let program = Node(kind: nkProgram, line: 1, column: 1)
  
  while p.curToken.kind != tkEOF:
    echo "\n--- Итерация ---"
    echo "Текущий токен: ", p.curToken.kind, " '", p.curToken.literal, "'"
    
    case p.curToken.kind
    of tkFunc:
      let stmt = p.parseFunctionDecl()
      if stmt != nil:
        program.statements.add(stmt)
    
    of tkTypeInt, tkTypeFloat, tkTypeBool, tkTypeStr:
      let stmt = p.parseVarDecl()
      if stmt != nil:
        program.statements.add(stmt)
      # parseVarDecl сам обрабатывает точку с запятой
    
    of tkIdent:
      # На глобальном уровне может быть вызов функции или присваивание
      if p.peekToken.kind == tkLParen:
        let stmt = p.parseFunctionCall()
        if stmt != nil:
          program.statements.add(stmt)
          # parseFunctionCall должен обработать точку с запятой
      elif p.peekToken.kind == tkEq:
        let stmt = p.parseAssignment()
        if stmt != nil:
          program.statements.add(stmt)
          # parseAssignment должен обработать точку с запятой
      else:
        p.state.error(&"Нераспознанная глобальная конструкция: {p.curToken.literal}", 
                      p.curToken.line, p.curToken.column)
        p.nextToken()
    
    of tkSendln:
      let stmt = p.parseSendln()
      if stmt != nil:
        program.statements.add(stmt)
        # parseSendln должен обработать точку с запятой
    
    of tkRefactor:
      let stmt = p.parseRefactor()
      if stmt != nil:
        program.statements.add(stmt)
        # parseRefactor должен обработать точку с запятой
    
    else:
      # Пропускаем служебные токены
      echo "  пропускаем служебный токен: ", p.curToken.kind
      p.nextToken()
  
  return program