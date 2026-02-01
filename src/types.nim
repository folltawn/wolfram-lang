## Основные типы данных для компилятора Wolfram

type
  # Типы данных Wolfram
  WolframType* = enum
    wtInt = "int"
    wtFloat = "float"
    wtBool = "bool"
    wtString = "str"
    wtVoid = "void"
    wtUnknown = "unknown"
  
  # Лексемы
  TokenKind* = enum
    tkInt, tkFloat, tkString, tkBool, tkIdent
    tkPlus, tkMinus, tkStar, tkSlash, tkPercent
    tkEq, tkEqEq, tkNotEq, tkLt, tkGt, tkLtEq, tkGtEq
    tkLParen, tkRParen, tkLBrace, tkRBrace
    tkColon, tkColonColon, tkSemi, tkComma, tkArrow, tkFatArrow
    tkTypeInt, tkTypeFloat, tkTypeBool, tkTypeStr  # ДОБАВИМ ОТДЕЛЬНЫЕ ТОКЕНЫ ДЛЯ ТИПОВ!
    tkConst, tkIf, tkElse, tkWhile, tkReturn
    tkSendln, tkRefactor
    tkEOF, tkIllegal
  
  Token* = object
    kind*: TokenKind
    literal*: string
    line*: int
    column*: int
  
  # AST узлы
  NodeKind* = enum
    nkProgram
    nkVarDecl
    nkConstDecl
    nkAssignment
    nkBinaryExpr
    nkUnaryExpr
    nkLiteral
    nkIdentifier
    nkSendln
    nkRefactor
    nkBlock
    nkIf
    nkWhile
  
  Node* = ref object
    line*, column*: int
    case kind*: NodeKind
    of nkProgram:
      statements*: seq[Node]
    
    of nkVarDecl, nkConstDecl:
      declName*: string
      declType*: WolframType
      declValue*: Node
    
    of nkAssignment:
      assignName*: string
      assignValue*: Node
    
    of nkBinaryExpr:
      left*, right*: Node
      op*: TokenKind
    
    of nkUnaryExpr:
      unaryOp*: TokenKind
      unaryExpr*: Node
    
    of nkLiteral:
      litType*: WolframType
      litValue*: string
    
    of nkIdentifier:
      identName*: string
    
    of nkSendln:
      sendlnArg*: Node
    
    of nkRefactor:
      refactorTarget*: Node
      refactorToType*: WolframType
      refactorValue*: Node
    
    of nkBlock:
      blockStmts*: seq[Node]
    
    of nkIf:
      ifCond*: Node
      ifThen*: Node
      ifElse*: Node
    
    of nkWhile:
      whileCond*: Node
      whileBody*: Node
  
  # Конфигурация проекта
  ProjectConfig* = object
    name*: string
    version*: string
    author*: seq[string]
    files*: seq[string]