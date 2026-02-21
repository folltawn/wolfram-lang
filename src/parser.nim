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




proc parseIfStatement(p: var Parser): Node




proc parseExpression(p: var Parser): Node

# Ключевые слова
const Keywords = {
  "int": tkTypeInt, "float": tkTypeFloat, "bool": tkTypeBool, "str": tkTypeStr,
  "const": tkConst, "true": tkBool, "false": tkBool,
  "if": tkIf, "elsif": tkElsif, "else": tkElse, "while": tkWhile,
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
  
  if l.ch == '\n':
    l.line += 1
    l.column = 0
  else:
    l.column += 1





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




proc newParser*(input: string, filename: string = ""): Parser =
  var p: Parser
  p.lexer = initLexer(input)
  p.curToken = p.lexer.nextToken()
  p.peekToken = p.lexer.nextToken()
  p.state = initCompilerState(input, filename)
  return p





proc nextToken(p: var Parser) =
  echo "nextToken: from ", p.curToken.kind, " to ", p.peekToken.kind
  p.curToken = p.peekToken
  p.peekToken = p.lexer.nextToken()





proc expectPeek(p: var Parser, kind: TokenKind): bool =
  if p.peekToken.kind == kind:
    p.nextToken()
    return true
  else:
    let expected = case kind
      of tkSemi: "';'"
      of tkRParen: "')'"
      of tkLParen: "'('"
      of tkLBrace: "'{'"
      of tkRBrace: "'}'"
      of tkEq: "'='"
      of tkEqEq: "'=='"
      else: $kind
    
    p.state.error(&"Missing {expected}", p.peekToken.line, p.peekToken.column)
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
    result = parts[0]
    p.nextToken()
    return result
  else:
    result = Node(
      kind: nkStringInterpolation,
      line: line,
      column: column,
      interpParts: parts
    )
    p.nextToken()
    return result





proc parseLiteral(p: var Parser): Node =
  echo "parseLiteral: ", p.curToken.kind, " ", p.curToken.literal
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
  
  p.nextToken()
  return node





proc parseIdentifier(p: var Parser): Node =
  result = Node(
    kind: nkIdentifier,
    line: p.curToken.line,
    column: p.curToken.column,
    identName: p.curToken.literal
  )
  p.nextToken()





proc parseBinaryExpr(p: var Parser, left: Node, precedence: int): Node =
  var left = left
  while true:
    let op = p.curToken.kind
    if op notin {tkEqEq, tkNotEq, tkLt, tkGt, tkLtEq, tkGtEq, tkPlus, tkMinus, tkStar, tkSlash, tkPercent}:
      break
    
    p.nextToken()  # переходим к правой части
    var right = p.parseExpression()
    if right == nil:
      return nil
    
    left = Node(
      kind: nkBinaryExpr,
      line: left.line,
      column: left.column,
      left: left,
      right: right,
      op: op
    )
  
  return left





proc parseExpression(p: var Parser): Node =
  echo "parseExpression start: ", p.curToken.kind, " ", p.curToken.literal
  var left: Node
  
  case p.curToken.kind
  of tkInt, tkFloat, tkBool, tkString:
    left = p.parseLiteral()
  of tkIdent:
    if p.peekToken.kind == tkLParen:
      left = p.parseFunctionCall()
    else:
      left = p.parseIdentifier()
  else:
    p.state.error(&"Недопустимое выражение: {p.curToken.literal}", 
                  p.curToken.line, p.curToken.column)
    return nil
  
  echo "After left, curToken: ", p.curToken.kind, " ", p.curToken.literal
  if p.curToken.kind in {tkEqEq, tkNotEq, tkLt, tkGt, tkLtEq, tkGtEq, tkPlus, tkMinus, tkStar, tkSlash, tkPercent}:
    echo "Found binary op: ", p.curToken.kind
    return p.parseBinaryExpr(left, 0)
  
  echo "No binary op, returning left"
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
  if p.peekToken.kind == tkSemi:
    p.nextToken()
  else:
    discard
  
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
  
  if not p.expectPeek(tkLParen):  # переходим на (
    return nil
  
  p.nextToken()  # переходим на аргумент
  
  let arg = p.parseExpression()  # парсим аргумент
  
  if arg == nil:
    return nil
  
  if p.curToken.kind != tkRParen:
    p.state.error("Ожидался токен )", p.curToken.line, p.curToken.column)
    return nil
  
  if not p.expectPeek(tkSemi):  # ждем ;
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





proc parseIfStatement(p: var Parser): Node =
  let line = p.curToken.line
  let column = p.curToken.column
  
  echo "parseIfStatement: current token before expectPeek: ", p.curToken.kind
  if not p.expectPeek(tkLParen):
    return nil
  echo "parseIfStatement: current token after expectPeek: ", p.curToken.kind
  
  p.nextToken()

  # Парсим условие
  let condition = p.parseExpression()
  echo "After parseExpression, token: ", p.curToken.kind, " literal: ", p.curToken.literal
  if condition == nil:
    return nil
  
  # Проверяем открывающую фигурную скобку
  if not p.expectPeek(tkLBrace):
    return nil
  
  p.nextToken()  # переходим к телу if
  
  # Парсим тело if
  var thenBody: seq[Node] = @[]
  while p.curToken.kind != tkRBrace and p.curToken.kind != tkEOF:
    let stmt = p.parseStatement()
    if stmt != nil:
      thenBody.add(stmt)
    p.nextToken()
  
  # Проверяем закрывающую скобку if
  if p.curToken.kind != tkRBrace:
    p.state.error("Ожидалась '}'", p.curToken.line, p.curToken.column)
    return nil
  
  # Создаем блок для then
  let thenBlock = Node(
    kind: nkBlock,
    line: line,
    column: column,
    blockStmts: thenBody
  )
  
  # Проверяем, есть ли elsif или else
  var elseBlock: Node = nil
  var currentLine = line
  var currentColumn = column
  
  p.nextToken()  # переходим к следующему токену после }
  
  # Обрабатываем цепочку elsif
  while p.curToken.kind == tkElsif:
    currentLine = p.curToken.line
    currentColumn = p.curToken.column
    
    # Парсим условие elsif
    if not p.expectPeek(tkLParen):
      return nil
    
    p.nextToken()
    let elsifCond = p.parseExpression()
    if elsifCond == nil:
      return nil
    
    # if not p.expectPeek(tkRParen):
    #   return nil
    
    if not p.expectPeek(tkLBrace):
      return nil
    
    p.nextToken()
    
    # Парсим тело elsif
    var elsifBody: seq[Node] = @[]
    while p.curToken.kind != tkRBrace and p.curToken.kind != tkEOF:
      let stmt = p.parseStatement()
      if stmt != nil:
        elsifBody.add(stmt)
      p.nextToken()
    
    echo "After then body, curToken: ", p.curToken.kind

    if p.curToken.kind != tkRBrace:
      p.state.error("Ожидалась '}'", p.curToken.line, p.curToken.column)
      return nil
    
    let elsifBlock = Node(
      kind: nkBlock,
      line: currentLine,
      column: currentColumn,
      blockStmts: elsifBody
    )
    
    # Создаем вложенный if для elsif
    elseBlock = Node(
      kind: nkIfStatement,
      line: currentLine,
      column: currentColumn,
      ifCond: elsifCond,
      ifThen: elsifBlock,
      ifElse: elseBlock  # предыдущий else становится else для этого elsif
    )
    
    p.nextToken()
  
  # Обрабатываем else
  if p.curToken.kind == tkElse:
    if not p.expectPeek(tkLBrace):
      return nil
    
    p.nextToken()
    
    # Парсим тело else
    var elseBody: seq[Node] = @[]
    while p.curToken.kind != tkRBrace and p.curToken.kind != tkEOF:
      let stmt = p.parseStatement()
      if stmt != nil:
        elseBody.add(stmt)
      p.nextToken()
    
    if p.curToken.kind != tkRBrace:
      p.state.error("Ожидалась '}'", p.curToken.line, p.curToken.column)
      return nil
    
    elseBlock = Node(
      kind: nkBlock,
      line: p.curToken.line,
      column: p.curToken.column,
      blockStmts: elseBody
    )
    
    p.nextToken()  # переходим после else
  
  # Создаем корневой if
  result = Node(
    kind: nkIfStatement,
    line: line,
    column: column,
    ifCond: condition,
    ifThen: thenBlock,
    ifElse: elseBlock  # если есть elsif/else, иначе nil
  )





proc parseFunctionCall(p: var Parser): Node =
  ## Парсит вызов функции: name()
  let line = p.curToken.line
  let column = p.curToken.column
  let name = p.curToken.literal
  
  # Проверяем скобки
  if not p.expectPeek(tkLParen):
    return nil
  
  if not p.expectPeek(tkRParen):
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
  ## Парсит объявление функции: func::name() или func::name(): static
  let line = p.curToken.line
  let column = p.curToken.column
  
  # Проверяем, что после func идет ::
  if not p.expectPeek(tkColonColon):
    return nil
  
  # Имя функции
  if not p.expectPeek(tkIdent):
    return nil
  
  let name = p.curToken.literal
  
  # Параметры (пока только пустые скобки)
  if not p.expectPeek(tkLParen):
    return nil
  
  if not p.expectPeek(tkRParen):
    return nil
  
  # Проверяем, есть ли модификатор static
  var funcKind = fkNormal
  
  if p.peekToken.kind == tkColon:
    p.nextToken() # Пропускаем :
    
    if p.peekToken.kind == tkStatic:
      p.nextToken() # Пропускаем static
      funcKind = fkStatic
    else:
      p.state.error("Ожидался 'static' после ':'", 
                    p.curToken.line, p.curToken.column)
      return nil
  
  # Тело функции в фигурных скобках
  if not p.expectPeek(tkLBrace):
    return nil
  
  p.nextToken() # Переходим к первому токену в теле
  
  var body: seq[Node] = @[]
  
  # Парсим тело функции до закрывающей скобки
  while p.curToken.kind != tkRBrace and p.curToken.kind != tkEOF:
    if p.curToken.kind == tkReturn:
      let returnNode = parseReturnStatement(p)
      if returnNode != nil:
        body.add(returnNode)
    else:
      # Парсим другие выражения
      let stmt = p.parseStatement()
      if stmt != nil:
        body.add(stmt)
    p.nextToken()
  
  # Создаем узел функции
  result = Node(
    kind: nkFunctionDecl,
    line: line,
    column: column,
    funcName: name,
    funcKind: funcKind,
    funcBody: body
  )





proc parseStatement(p: var Parser): Node =
  echo "parseStatement: ", p.curToken.kind, " ", p.curToken.literal
  case p.curToken.kind
  of tkTypeInt, tkTypeFloat, tkTypeBool, tkTypeStr:
    return p.parseVarDecl()
  of tkIdent:
    # Это может быть присваивание или вызов функции
    if p.peekToken.kind == tkLParen:
      return p.parseFunctionCall()
    elif p.peekToken.kind == tkEq:
      return p.parseAssignment()
    else:
      p.state.error(&"Нераспознанная конструкция: {p.curToken.literal}", 
                    p.curToken.line, p.curToken.column)
      return nil
  of tkSendln:
    return p.parseSendln()
  of tkRefactor:
    return p.parseRefactor()
  of tkFunc:
    return p.parseFunctionDecl()
  of tkIf:
    return p.parseIfStatement()
  of tkReturn:
    return p.parseReturnStatement()
  else:
    p.state.error(&"Недопустимое выражение: {p.curToken.kind}", 
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