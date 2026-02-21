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
proc nextToken(p: var Parser)

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
    if l.ch == '\n':
      l.line += 1
      l.column = 0
    l.readChar()

proc readIdentifier(l: var Lexer): string =
  let start = l.position
  while isLetter(l.ch) or isDigit(l.ch):
    l.readChar()
  result = l.input[start..<l.position]

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
  
  result = l.input[start..<l.position]
  l.readChar() # пропускаем закрывающую кавычку

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

# Парсер
proc newParser*(input: string, filename: string = ""): Parser =
  var p: Parser
  p.lexer = initLexer(input)
  p.curToken = p.lexer.nextToken()
  p.peekToken = p.lexer.nextToken()
  p.state = initCompilerState(input, filename)
  return p

proc nextToken(p: var Parser) =
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
    
    p.state.addErrorExpected(expected, p.peekToken.literal, 
                             p.peekToken.line, p.peekToken.column)
    return false

proc expectSemicolon(p: var Parser, line: int, column: int) =
  if p.curToken.kind == tkSemi:
    p.nextToken()
  else:
    p.state.addError(errMissingSemicolon, line, column, found = p.curToken.literal)

proc parseType(p: var Parser): (PalladiumType, bool) =
  var typ: PalladiumType
  var isConst = false
  
  case p.curToken.kind
  of tkTypeInt: typ = wtInt
  of tkTypeFloat: typ = wtFloat
  of tkTypeBool: typ = wtBool
  of tkTypeStr: typ = wtString
  else:
    p.state.addError(errUnknownType, p.curToken.line, p.curToken.column, 
                     found = p.curToken.literal)
    return (wtUnknown, false)
  
  if p.peekToken.kind == tkColonColon:
    p.nextToken()
    if p.peekToken.kind == tkConst:
      p.nextToken()
      isConst = true
    else:
      p.state.addError(errMissingConst, p.curToken.line, p.curToken.column,
                       found = p.peekToken.literal)
      return (typ, false)
  
  return (typ, isConst)

proc parseStringInterpolation(p: var Parser, strValue: string): Node =
  let line = p.curToken.line
  let column = p.curToken.column
  
  var parts: seq[Node]
  var i = 0
  
  while i < strValue.len:
    if i + 1 < strValue.len and strValue[i] == '{' and strValue[i+1] == '{':
      i += 2
      
      var varStart = i
      while i < strValue.len and not (strValue[i] == '}' and i+1 < strValue.len and strValue[i+1] == '}'):
        i += 1
      
      if i >= strValue.len or not (strValue[i] == '}' and strValue[i+1] == '}'):
        p.state.addError(errUnclosedInterpolation, line, column)
        return nil
      
      let varName = strValue[varStart..<i].strip()
      
      let varNode = Node(
        kind: nkIdentifier,
        line: line,
        column: column,
        identName: varName
      )
      parts.add(varNode)
      
      i += 2
    else:
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
  
  if parts.len == 1 and parts[0].kind == nkLiteral:
    result = parts[0]
  else:
    result = Node(
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
    p.nextToken()
  of tkFloat:
    node.litType = wtFloat
    node.litValue = p.curToken.literal
    p.nextToken()
  of tkBool:
    node.litType = wtBool
    node.litValue = p.curToken.literal
    p.nextToken()
  of tkString:
    if "{{" in p.curToken.literal:
      result = p.parseStringInterpolation(p.curToken.literal)
      p.nextToken()
      return result
    else:
      node.litType = wtString
      node.litValue = p.curToken.literal
      p.nextToken()
  else:
    p.state.addError(errInvalidLiteral, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    p.nextToken()
    return nil
  
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
    
    p.nextToken()
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
    p.state.addError(errExpectedExpression, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    p.nextToken()
    return nil
  
  if p.curToken.kind in {tkEqEq, tkNotEq, tkLt, tkGt, tkLtEq, tkGtEq, tkPlus, tkMinus, tkStar, tkSlash, tkPercent}:
    return p.parseBinaryExpr(left, 0)
  
  return left

proc parseVarDecl(p: var Parser): Node =
  let line = p.curToken.line
  let column = p.curToken.column
  
  let (typ, isConst) = p.parseType()
  if typ == wtUnknown:
    return nil
  
  p.nextToken()  # переходим после типа
  if p.curToken.kind != tkIdent:
    p.state.addError(errExpectedIdentifier, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    return nil
  
  let name = p.curToken.literal
  p.nextToken()  # переходим после имени
  
  if p.curToken.kind != tkEq:
    p.state.addError(errExpectedEq, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    return nil
  
  p.nextToken()  # переходим к значению
  let value = p.parseExpression()
  if value == nil:
    return nil
  
  let valueLine = if value != nil: value.line else: line
  let valueColumn = if value != nil: value.column else: column
  p.expectSemicolon(valueLine, valueColumn)
  
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
  
  p.nextToken()  # переходим после имени
  
  if p.curToken.kind != tkEq:
    p.state.addError(errExpectedEq, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    return nil
  
  p.nextToken()  # переходим к значению
  let value = p.parseExpression()
  if value == nil:
    return nil
  
  p.expectSemicolon(value.line, value.column)
  
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
  
  p.nextToken()  # sendln
  
  if p.curToken.kind != tkLParen:
    p.state.addError(errExpectedLParen, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    return nil
  
  p.nextToken()  # (
  
  let exprLine = p.curToken.line
  let exprColumn = p.curToken.column
  
  let arg = p.parseExpression()
  if arg == nil:
    return nil
  
  if p.curToken.kind != tkRParen:
    p.state.addError(errExpectedRParen, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    return nil
  
  p.nextToken()  # )
  
  p.expectSemicolon(exprLine, exprColumn)  # ← передаем позицию выражения
  
  Node(
    kind: nkSendln,
    line: line,
    column: column,
    sendlnArg: arg
  )

proc parseRefactor(p: var Parser): Node =
  let line = p.curToken.line
  let column = p.curToken.column
  
  p.nextToken()  # переходим после refactor
  
  if p.curToken.kind != tkLParen:
    p.state.addError(errExpectedLParen, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    return nil
  
  p.nextToken()  # переходим к цели
  let target = p.parseExpression()
  if target == nil:
    return nil
  
  if p.curToken.kind != tkRParen:
    p.state.addError(errExpectedRParen, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    return nil
  
  p.nextToken()  # переходим после )
  
  if p.curToken.kind != tkFatArrow:
    p.state.addError(errExpectedFatArrow, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    return nil
  
  p.nextToken()  # переходим после =>
  
  if p.curToken.kind notin {tkTypeInt, tkTypeFloat, tkTypeBool, tkTypeStr}:
    p.state.addError(errExpectedType, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    return nil
  
  var toType = wtUnknown
  case p.curToken.kind
  of tkTypeInt: toType = wtInt
  of tkTypeFloat: toType = wtFloat
  of tkTypeBool: toType = wtBool
  of tkTypeStr: toType = wtString
  else: discard
  
  p.nextToken()  # переходим после типа
  
  var refactorValue: Node = nil
  var valueLine = line
  var valueColumn = column
  
  if p.curToken.kind == tkLParen:
    p.nextToken()  # переходим к значению
    refactorValue = p.parseExpression()
    if refactorValue == nil:
      return nil
    
    if p.curToken.kind != tkRParen:
      p.state.addError(errExpectedRParen, p.curToken.line, p.curToken.column,
                       found = p.curToken.literal)
      return nil
    
    p.nextToken()  # переходим после )
    valueLine = refactorValue.line
    valueColumn = refactorValue.column
  
  if refactorValue != nil:
    p.expectSemicolon(valueLine, valueColumn)
  else:
    p.expectSemicolon(target.line, target.column)
  
  Node(
    kind: nkRefactor,
    line: line,
    column: column,
    refactorTarget: target,
    refactorToType: toType,
    refactorValue: refactorValue
  )

proc parseIfStatement(p: var Parser): Node =
  let line = p.curToken.line
  let column = p.curToken.column
  
  p.nextToken()  # переходим после if
  
  if p.curToken.kind != tkLParen:
    p.state.addError(errExpectedLParen, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    return nil
  
  p.nextToken()  # переходим к условию
  let condition = p.parseExpression()
  if condition == nil:
    return nil
  
  if p.curToken.kind != tkRParen:
    p.state.addError(errExpectedRParen, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    return nil
  
  p.nextToken()  # переходим после )
  
  if p.curToken.kind != tkLBrace:
    p.state.addError(errExpectedLBrace, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    return nil
  
  p.nextToken()  # переходим к телу if
  
  var thenBody: seq[Node] = @[]
  while p.curToken.kind != tkRBrace and p.curToken.kind != tkEOF:
    let stmt = p.parseStatement()
    if stmt != nil:
      thenBody.add(stmt)
  
  if p.curToken.kind != tkRBrace:
    p.state.addError(errExpectedRBrace, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    return nil
  
  # Берем реальную строку первого выражения в блоке
  let thenBodyLine = if thenBody.len > 0: thenBody[0].line else: line
  let thenBodyColumn = if thenBody.len > 0: thenBody[0].column else: column
  
  let thenBlock = Node(
    kind: nkBlock,
    line: line,
    column: column,
    blockStmts: thenBody
  )
  
  p.nextToken()  # переходим после }
  
  var elseBlock: Node = nil
  
  # Обрабатываем elsif
  while p.curToken.kind == tkElsif:
    let elsifLine = p.curToken.line
    let elsifColumn = p.curToken.column
    
    p.nextToken()  # переходим после elsif
    
    if p.curToken.kind != tkLParen:
      p.state.addError(errExpectedLParen, p.curToken.line, p.curToken.column,
                       found = p.curToken.literal)
      return nil
    
    p.nextToken()  # переходим к условию
    let elsifCond = p.parseExpression()
    if elsifCond == nil:
      return nil
    
    if p.curToken.kind != tkRParen:
      p.state.addError(errExpectedRParen, p.curToken.line, p.curToken.column,
                       found = p.curToken.literal)
      return nil
    
    p.nextToken()  # переходим после )
    
    if p.curToken.kind != tkLBrace:
      p.state.addError(errExpectedLBrace, p.curToken.line, p.curToken.column,
                       found = p.curToken.literal)
      return nil
    
    p.nextToken()  # переходим к телу elsif
    
    var elsifBody: seq[Node] = @[]
    while p.curToken.kind != tkRBrace and p.curToken.kind != tkEOF:
      let stmt = p.parseStatement()
      if stmt != nil:
        elsifBody.add(stmt)
    
    if p.curToken.kind != tkRBrace:
      p.state.addError(errExpectedRBrace, p.curToken.line, p.curToken.column,
                       found = p.curToken.literal)
      return nil
    
    let elsifBodyLine = if elsifBody.len > 0: elsifBody[0].line else: elsifLine
    let elsifBodyColumn = if elsifBody.len > 0: elsifBody[0].column else: elsifColumn
    
    let elsifBlock = Node(
      kind: nkBlock,
      line: elsifBodyLine,
      column: elsifBodyColumn,
      blockStmts: elsifBody
    )
    
    elseBlock = Node(
      kind: nkIfStatement,
      line: elsifLine,
      column: elsifColumn,
      ifCond: elsifCond,
      ifThen: elsifBlock,
      ifElse: elseBlock
    )
    
    p.nextToken()  # переходим после }
  
  # Обрабатываем else
  if p.curToken.kind == tkElse:
    let elseLine = p.curToken.line
    let elseColumn = p.curToken.column
    
    p.nextToken()  # переходим после else
    
    if p.curToken.kind != tkLBrace:
      p.state.addError(errExpectedLBrace, p.curToken.line, p.curToken.column,
                       found = p.curToken.literal)
      return nil
    
    p.nextToken()  # переходим к телу else
    
    var elseBody: seq[Node] = @[]
    while p.curToken.kind != tkRBrace and p.curToken.kind != tkEOF:
      let stmt = p.parseStatement()
      if stmt != nil:
        elseBody.add(stmt)
    
    if p.curToken.kind != tkRBrace:
      p.state.addError(errExpectedRBrace, p.curToken.line, p.curToken.column,
                       found = p.curToken.literal)
      return nil
    
    let elseBodyLine = if elseBody.len > 0: elseBody[0].line else: elseLine
    let elseBodyColumn = if elseBody.len > 0: elseBody[0].column else: elseColumn
    
    elseBlock = Node(
      kind: nkBlock,
      line: elseBodyLine,
      column: elseBodyColumn,
      blockStmts: elseBody
    )
    
    p.nextToken()  # переходим после }
  
  result = Node(
    kind: nkIfStatement,
    line: line,
    column: column,
    ifCond: condition,
    ifThen: thenBlock,
    ifElse: elseBlock
  )

proc parseFunctionCall(p: var Parser): Node =
  let line = p.curToken.line
  let column = p.curToken.column
  let name = p.curToken.literal
  
  p.nextToken()  # переходим после имени
  
  if p.curToken.kind != tkLParen:
    p.state.addError(errExpectedLParen, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    return nil
  
  p.nextToken()  # переходим после (
  
  if p.curToken.kind != tkRParen:
    p.state.addError(errExpectedRParen, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    return nil
  
  p.nextToken()  # переходим после )
  p.expectSemicolon(line, column)
  
  result = Node(
    kind: nkFunctionCall,
    line: line,
    column: column,
    callName: name
  )

proc parseReturnStatement(p: var Parser): Node =
  let line = p.curToken.line
  let column = p.curToken.column
  
  p.nextToken()  # переходим после return
  
  let returnValue = p.parseExpression()
  if returnValue == nil:
    return nil
  
  p.expectSemicolon(returnValue.line, returnValue.column)
  
  result = Node(
    kind: nkReturn,
    line: line,
    column: column,
    returnValue: returnValue
  )

proc parseFunctionDecl(p: var Parser): Node =
  let line = p.curToken.line
  let column = p.curToken.column
  
  p.nextToken()  # переходим после func
  
  if p.curToken.kind != tkColonColon:
    p.state.addError(errUnexpectedToken, p.curToken.line, p.curToken.column,
                     expected = "'::'", found = p.curToken.literal)
    return nil
  
  p.nextToken()  # переходим после ::
  
  if p.curToken.kind != tkIdent:
    p.state.addError(errExpectedIdentifier, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    return nil
  
  let name = p.curToken.literal
  p.nextToken()  # переходим после имени
  
  if p.curToken.kind != tkLParen:
    p.state.addError(errExpectedLParen, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    return nil
  
  p.nextToken()  # переходим после (
  
  if p.curToken.kind != tkRParen:
    p.state.addError(errExpectedRParen, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    return nil
  
  p.nextToken()  # переходим после )
  
  var funcKind = fkNormal
  
  if p.curToken.kind == tkColon:
    p.nextToken()  # переходим после :
    
    if p.curToken.kind == tkStatic:
      funcKind = fkStatic
      p.nextToken()  # переходим после static
    else:
      p.state.addError(errUnexpectedToken, p.curToken.line, p.curToken.column,
                       expected = "'static'", found = p.curToken.literal)
      return nil
  
  if p.curToken.kind != tkLBrace:
    p.state.addError(errExpectedLBrace, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    return nil
  
  p.nextToken()  # переходим к телу функции
  
  var body: seq[Node] = @[]
  
  while p.curToken.kind != tkRBrace and p.curToken.kind != tkEOF:
    let stmt = p.parseStatement()
    if stmt != nil:
      body.add(stmt)
  
  if p.curToken.kind != tkRBrace:
    p.state.addError(errExpectedRBrace, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    return nil
  
  p.nextToken()  # переходим после }
  
  result = Node(
    kind: nkFunctionDecl,
    line: line,
    column: column,
    funcName: name,
    funcKind: funcKind,
    funcBody: body
  )

proc parseStatement(p: var Parser): Node =
  if p.curToken.kind == tkEOF:
    return nil
    
  case p.curToken.kind
  of tkTypeInt, tkTypeFloat, tkTypeBool, tkTypeStr:
    return p.parseVarDecl()
  of tkIdent:
    if p.peekToken.kind == tkLParen:
      return p.parseFunctionCall()
    elif p.peekToken.kind == tkEq:
      return p.parseAssignment()
    else:
      p.state.addError(errUnknownConstruct, p.curToken.line, p.curToken.column,
                       found = p.curToken.literal)
      p.nextToken()
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
    p.state.addError(errUnsupportedExpression, p.curToken.line, p.curToken.column,
                     found = p.curToken.literal)
    p.nextToken()
    return nil

proc parseProgram*(p: var Parser): Node =
  let program = Node(kind: nkProgram, line: 1, column: 1)
  
  while p.curToken.kind != tkEOF:
    let stmt = p.parseStatement()
    if stmt != nil:
      program.statements.add(stmt)
  
  return program