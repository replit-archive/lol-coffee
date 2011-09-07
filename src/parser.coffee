###
A parser for LOLCODE. Takes a list of LOLCODE tokens and produces a parse tree.
Since LOLCODE funciton calls are ambiguous until the function being called is
defined, the Parser keeps track of the arities of all functions defined so far.
This means every time you want to parse a new program that uses previously
defined functions, you will need to provide the last parser's function_arities
to the new one.

In general, you should only need to use parseProgram(). However, similar parse
methods for all other grammar rules are also provided.

Example usage:
  tokenized_program_1 = ...
  tokenized_program_2 = ...
  tokenized_expression = ...
  try
    parser1 = new LOLCoffee.Parser tokenized_program_1
    program_1_ast = parser1.parseProgram()

    parser2 = new LOLCoffee.Parser tokenized_program_2, parser1
    program_2_ast = parser2.parseProgram()

    parser3 = new LOLCoffee.Parser tokenized_expression, parser2
    expression_ast = parser3.parseExpression()
  catch error
    console.assert error instanceof LOLCoffee.ParserError
    console.log error

Provides:
  LOLCoffee.Parser
  LOLCoffee.ParserError

Requires:
  LOLCoffee.AST
  LOLCoffee.DEFAULT_VALUES
  LOLCoffee.UNARY_OPERATORS
  LOLCoffee.BINARY_OPERATORS
  LOLCoffee.INFINITARY_OPERATORS
###

# Imports.
AST = @LOLCoffee.AST
DEFAULT_VALUES = @LOLCoffee.DEFAULT_VALUES
UNARY_OPERATORS = @LOLCoffee.UNARY_OPERATORS
BINARY_OPERATORS = @LOLCoffee.BINARY_OPERATORS
INFINITARY_OPERATORS = @LOLCoffee.INFINITARY_OPERATORS

# The type of error thrown by the parser.
class ParserError extends Error
  constructor: (line, message) ->
    @message = "Line #{line}: #{message}."
  name: 'ParserError'

# The parser class. Created each time a LOLCODE program or program fragment
# needs to be parsed. Keeps track of function arities for diambiguation.
class Parser
  constructor: (@tokens, @function_arities={}) ->
    # Used to disambiguate GTFO: break in loops/switches or return in functions.
    @_scope_depth = 0
    @_in_function = false

  # Program ::= Statement* | "HAI" [1.2] Statement* "KTHXBAI"
  parseProgram: ->
    unless @tokens.length
      return new AST.Program new AST.StatementList []

    started_with_hai = @_nextIs 'keyword', 'HAI'
    if started_with_hai
      @_consume()
      unless @_nextIs 'endline' then @_consume 'float', '1.2'
      @_consume()

    statements = while @tokens.length and not @_nextIs 'keyword', 'KTHXBYE'
      @parseStatement()

    if @_nextIs 'keyword', 'KTHXBYE'
      unless started_with_hai
        @_error 'KTHXBYE is not allowed when HAI is not used'
      @_consume 'keyword', 'KTHXBYE'
      @_consume 'endline'

    if @tokens.length isnt 0 then @_error 'Unexpected input after program end'

    return new AST.Program new AST.StatementList statements

  # FunctionDefinition ::= "HOW DUZ I" IDENTIFIER FunctionArgs ENDLINE
  #                          Statement*
  #                        "IF U SAY SO"
  parseFunctionDefinition: ->
    # Declaration.
    @_consume 'keyword', 'HOW DUZ I'
    name = @_consume 'identifier'
    args = @parseFunctionArgs()
    @_consume 'endline'

    # Rememeber the function arity as soon as the declaration is read, so we
    # can call the function recursively.
    @function_arities[name] = args.length

    # Body.
    @_in_function = true
    statements = until @_nextIs 'keyword', 'IF U SAY SO' then @parseStatement()
    statements.push new AST.Return new AST.IdentifierExpression 'IT'
    body = new AST.StatementList statements
    @_in_function = false

    # Tail.
    @_consume 'keyword', 'IF U SAY SO'

    return new AST.FunctionDefinition name, args, body

  # FunctionArgs ::= ["YR" IDENTIFIER ("AN" "YR" IDENTIFIER)*]
  parseFunctionArgs: ->
    args = []
    while @_nextIs 'keyword', 'YR'
      @_consume()
      args.push @_consume 'identifier'
      if @_nextIs 'keyword', 'AN' then @_consume() else break
    return args

  # Statement ::= (LoopStatement | ConditionalStatement | SwitchStatement |
  #                Declaration | Assignment | Expression | InputStatement |
  #                CastStatement | "GTFO" | "FOUND YR" Expression |
  #                FunctionDefinition) ENDLINE
  parseStatement: ->
    if @_nextIs 'keyword', 'IM IN YR'
      statement = @parseLoopStatement()
    else if@_nextIs 'keyword', 'O RLY?'
      statement = @parseConditionalStatement()
    else if @_nextIs 'keyword', 'WTF?'
      statement = @parseSwitchStatement()
    else if @_nextIs 'keyword', 'I HAS A'
      statement = @parseDeclaration()
    else if @_nextIs 'keyword', 'GIMMEH'
      statement = @parseInputStatement()
    else if @_nextIs 'keyword', 'VISIBLE'
      statement = @parseOutputStatement()
    else if @_nextIs 'keyword', 'PUTZ'
      statement = @parseIndexedAssignment()
    else if @_nextIs 'keyword', 'HOW DUZ I'
      if @_in_function then @_error 'Cannot define nested functions'
      statement = @parseFunctionDefinition()
    else if @_nextIs 'keyword', 'GTFO'
      if @_scope_depth > 0
        statement = new AST.Break
      else if @_in_function
        statement = new AST.Return new AST.NullLiteral
      else
        @_error 'GTFO must be inside a loop, switch, or function'
      @_consume()
    else if @_nextIs 'keyword', 'FOUND YR'
      @_consume()
      unless @_in_function then @_error 'FOUND YR must be inside a function'
      statement = new AST.Return @parseExpression()
    else if (@tokens.length >= 2 and
             @_nextIs('identifier') and
             @tokens[1].is('keyword', 'R'))
      statement = @parseAssignment()
    else if (@tokens.length >= 2 and
             @_nextIs('identifier') and
             @tokens[1].is 'keyword', 'IS NOW A')
      statement = @parseCastStatement()
    else
      statement = new AST.Assignment 'IT', @parseExpression()

    @_consume 'endline'

    return statement

  # InputStatement ::= "GIMMEH" IDENTIFIER
  parseInputStatement: ->
    @_consume 'keyword', 'GIMMEH'
    return new AST.Input @_consume 'identifier'

  # Declaration ::= "I HAS A" IDENTIFIER ["ITZ" (Expression | "A" Type)]
  parseDeclaration: ->
    @_consume 'keyword', 'I HAS A'
    variable = @_consume 'identifier'
    declaration = new AST.Declaration variable

    if @_nextIs 'keyword', 'ITZ'
      @_consume()
      if @_nextIs 'keyword', 'A'
        @_consume()
        value = DEFAULT_VALUES[@parseType()]
        assignment = new AST.Assignment variable, value
      else 
        assignment = new AST.Assignment variable, @parseExpression()
      return new AST.StatementList [declaration, assignment]
    else
      return declaration

  # Assignment ::= IDENTIFIER "R" Expression
  parseAssignment: ->
    variable = @_consume 'identifier'
    @_consume 'keyword', 'R'
    return new AST.Assignment variable, @parseExpression()

  # IndexedAssignment ::= "PUTZ" Expression "INTA" IDENTIFIER "AT" Expression
  parseIndexedAssignment: ->
    @_consume 'keyword', 'PUTZ'
    value = @parseExpression()
    @_consume 'keyword', 'INTA'
    identifier = @_consume 'identifier'
    @_consume 'keyword', 'AT'
    index = @parseExpression()
    return new AST.IndexedAssignment identifier, index, value

  # LoopStatement ::= "IM IN YR" IDENTIFIER
  #                   [IDENTIFIER "YR" IDENTIFIER [("WILE" | "TIL") Expression]]
  #                   ENDLINE
  #                   Statement*
  #                   "IM OUTTA YR" IDENTIFIER
  parseLoopStatement: ->
    # Minimal header.
    @_consume 'keyword', 'IM IN YR'
    label = @_consume 'identifier'

    # Extended header.
    operation = variable = condition = null
    unless @_nextIs 'endline'
      # Step operation.
      unless (@_nextIs('keyword', 'UPPIN') or
              @_nextIs('keyword', 'NERFIN') or
              @_nextIs('identifier'))
        @_error 'A loop operation must follow the loop label'
      operation = @_consume()
      @_consume 'keyword', 'YR'
      variable = @_consume 'identifier'
      variable_exp = new AST.IdentifierExpression variable
      expression = switch operation
        when 'UPPIN'
          new AST.BinaryExpression 'SUM OF', variable_exp, new AST.IntLiteral 1
        when 'NERFIN'
          new AST.BinaryExpression 'DIFF OF', variable_exp, new AST.IntLiteral 1
        else
          unless @function_arities[operation] is 1
            @_error 'Loop operation must be UPPIN, NERFIN or a unary function'
          new AST.CallExpression operation, [variable_exp]
      operation = new AST.Assignment variable, expression

      unless @_nextIs 'endline'
        # Condition.
        if @_nextIs 'keyword', 'WILE'
          inverted = false
        else if @_nextIs 'keyword', 'TIL'
          inverted = true
        else
          @_error 'A loop variable must be followed by WILE or TIL'
        @_consume()
        limit = @parseExpression()
        if inverted then limit = new AST.UnaryExpression 'NOT', limit
    @_consume 'endline'

    # Body.
    @_scope_depth++
    statements = until @_nextIs 'keyword', 'IM OUTTA YR' then @parseStatement()
    body = new AST.StatementList statements
    @_scope_depth--

    # Tail.
    @_consume 'keyword', 'IM OUTTA YR'
    if label != @_consume 'identifier' then @_error 'Mismatched loop label'

    return new AST.Loop operation, limit, body

  # ConditionalStatement ::= "O RLY?" ENDLINE
  #                          "YA RLY" Statement*
  #                          ("MEBBE" Expression ENDLINE Statement*)*
  #                          ["NO WAI" Statement*]
  #                          "OIC"
  parseConditionalStatement: ->
    # Header
    @_consume 'keyword', 'O RLY?'
    @_consume 'endline'
    @_consume 'keyword', 'YA RLY'
    @_consume 'endline'

    isNextBlock = => return (@_nextIs('keyword', 'MEBBE') or
                             @_nextIs('keyword', 'NO WAI') or
                             @_nextIs('keyword', 'OIC'))

    # Then body.
    then_statements = until isNextBlock() then @parseStatement()
    then_body = new AST.StatementList then_statements

    # Optional elseif bodies.
    elseif_tuples = []
    while @_nextIs 'keyword', 'MEBBE'
      @_consume()
      expression = @parseExpression()
      @_consume 'endline'
      elseif_statements = until isNextBlock() then @parseStatement()
      elseif_tuples.push [expression, new AST.StatementList elseif_statements]

    # Optional else body.
    else_statements = []
    else_body = null
    unless @_nextIs 'keyword', 'OIC'
      @_consume 'keyword', 'NO WAI'
      @_consume 'endline'
      else_statements = until @_nextIs 'keyword', 'OIC' then @parseStatement()
      if else_statements then else_body = new AST.StatementList else_statements

    @_consume 'keyword', 'OIC'

    # Chain elseifs.
    while elseif_tuples.length
      [expression, elseif_body] = elseif_tuples.pop()
      expression = new AST.Assignment 'IT', expression
      conditional = new AST.Conditional elseif_body, else_body
      else_body = new AST.StatementList [expression, conditional]

    return new AST.Conditional then_body, else_body

  # SwitchStatement ::= "WTF?" ENDLINE
  #                     ("OMG" Literal ENDLINE Statement*)*
  #                     ("OMGWTF" ENDLINE Statement*)?
  #                     "OIC"
  parseSwitchStatement: ->
    @_consume 'keyword', 'WTF?'
    @_consume 'endline'

    # List of cases.
    cases = []
    default_case = null
    @_scope_depth++
    until @_nextIs 'keyword', 'OIC'
      if @_nextIs 'keyword', 'OMG'
        # Case statement.
        @_consume()
        case_literal_line = @tokens[0].line
        literal = @parseLiteral()
        unless literal instanceof AST.Literal
          @_error 'OMG value must be a literal', case_literal_line
        @_consume 'endline'
        statements = until (@_nextIs('keyword', 'OMG') or
                            @_nextIs('keyword', 'OMGWTF') or
                            @_nextIs('keyword', 'OIC')) then @parseStatement()
        cases.push [literal, new AST.StatementList statements]
      else if @_nextIs 'keyword', 'OMGWTF'
        # Default statement.
        @_consume()
        @_consume 'endline'
        statements = until @_nextIs 'keyword', 'OIC' then @parseStatement()
        default_case = new AST.StatementList statements
      else
        @_error 'Expected OMG, OMGWTF or OIC'
    @_consume()
    @_scope_depth--

    return new AST.Switch cases, default_case

  # Expression ::= CastExpression | FunctionCall | IDENTIFIER |
  #                IDENTIFIER "AT" Expression | LITERAL
  parseExpression: ->
    if @_nextIs 'keyword'
      keyword = @tokens[0].text
      if keyword is 'MAEK'
        return @parseCastExpression()
      else if keyword in UNARY_OPERATORS
        return @parseUnaryExpression()
      else if keyword in BINARY_OPERATORS
        return @parseBinaryExpression()
      else if keyword in INFINITARY_OPERATORS
        return @parseInfinitaryExpression()
      else if keyword in ['WIN', 'FAIL', 'NOOB']
        return @parseLiteral()
      else
        @_error 'Invalid keyword at start of expression'
    else if @_nextIs 'identifier'
      base = if @tokens[0].text of @function_arities
        @parseFunctionCall()
      else
        new AST.IdentifierExpression @_consume()
      if @_nextIs 'keyword', 'AT'
        @_consume()
        return new AST.IndexingExpression base, @parseExpression()
      else
        return base
    else
      return @parseLiteral()

  # CastExpression ::= "MAEK" IDENTIFIER ["A"] Type
  parseCastExpression: ->
    @_consume 'keyword', 'MAEK'
    expression = @parseExpression()
    if @_nextIs 'keyword', 'A' then @_consume()
    return new AST.CastExpression expression, @parseType()

  # CastStatement ::= IDENTIFIER "IS NOW A" Type
  parseCastStatement: ->
    identifier = @_consume 'identifier'
    identifier_expr = new AST.IdentifierExpression identifier
    @_consume 'keyword', 'IS NOW A'
    expression = new AST.CastExpression identifier_expr, @parseType()
    return new AST.Assignment identifier, expression

  # Type ::= "YARN" | "NUMBR" | "NUMBAR" | "TROOF" | "NOOB"
  parseType: ->
    type = @_consume 'keyword'
    if type not of DEFAULT_VALUES then @_error 'Unknown type'
    return type

  # Literal ::= STRING | INT | FLOAT | "WIN" | "FAIL" | "NOOB"
  parseLiteral: ->
    if @_nextIs 'string'
      return @_createStringLiteral @_consume()
    else if @_nextIs 'int'
      return new AST.IntLiteral parseInt @_consume(), 10
    else if @_nextIs 'float'
      return new AST.FloatLiteral parseFloat @_consume()
    else if @_nextIs 'keyword'
      token = @_consume()
      if token in ['WIN', 'FAIL']
        return new AST.BoolLiteral token == 'WIN'
      else if token is 'NOOB'
        return new AST.NullLiteral
      else
        @_error 'Unexpected keyword while parsing literal', token.line
    else
      @_error 'Could not parse literal'

  # FunctionCall ::= IDENTIFIER Expression{arity}
  parseFunctionCall: ->
    func = @_consume 'identifier'
    if func not of @function_arities then @_error 'Undefined function: ' + func
    args = (@parseExpression() for _ in [0...@function_arities[func]])
    return new AST.CallExpression func, args

  # OutputStatement ::= "VISIBLE" Expression* ["!"] (?= ENDLINE)
  parseOutputStatement: ->
    @_consume 'keyword', 'VISIBLE'

    args = until @_nextIs('keyword', '!') or @_nextIs('endline')
      @parseExpression()

    if @_nextIs 'keyword', '!'
      @_consume()
    else
      args.push new AST.StringLiteral '\n'

    return new AST.Output new AST.InfinitaryExpression 'SMOOSH', args

  # UnaryExpression ::= UNARY_OPERATOR Expression
  parseUnaryExpression: ->
    operator = @_consume 'keyword'
    if operator not in UNARY_OPERATORS
      @_error 'Unknown unary operator: ' + operator
    return new AST.UnaryExpression operator, @parseExpression()

  # BinaryExpression ::= BINARY_OPERATOR Expression ["AN"] Expression
  parseBinaryExpression: ->
    operator = @_consume 'keyword'
    if operator not in BINARY_OPERATORS
      @_error 'Unknown binary operator: ' + operator

    left = @parseExpression()
    if @_nextIs 'keyword', 'AN' then @_consume()
    right = @parseExpression()

    return new AST.BinaryExpression operator, left, right

  # InfinitaryExpression ::= INFINITARY_OPERATOR Expression (["AN"] Expression)*
  #                          ("MKAY" | (?= ENDLINE))
  parseInfinitaryExpression: ->
    operator = @_consume 'keyword'
    if operator not in INFINITARY_OPERATORS
      @_error 'Unknown infinitary operator: ' + operator

    args = until @_nextIs('keyword', 'MKAY') or @_nextIs('endline')
      if @_nextIs 'keyword', 'AN' then @_consume()
      @parseExpression()

    if @_nextIs 'keyword', 'MKAY' then @_consume()

    return new AST.InfinitaryExpression operator, args

  # Parses a string literal resolving escape codes. If the string contains no
  # embedded variables, an AST.StringLiteral is returned. Otherwise a SMOOSH
  # (concatenation) AST.InfinitaryExpression with the embedded variables as
  # AST.IdentifierExpression operands.
  _createStringLiteral: (str) ->
    unless /^".*"$/.test str then @_error 'Invalid string literal: ' + str
    str = str[1...-1]

    parts = []
    buffer = []
    for chr, index in str
      if chr is ':'
        chr = str[++index]
        switch chr
          when ')' then buffer.push '\n'
          when '>' then buffer.push '\t'
          when 'o' then buffer.push '\g'
          when '"' then buffer.push '"'
          when ':' then buffer.push ':'
          when '('
            hex = str[index..].match /\(([\da-fA-F]+)\)/
            index += hex[0].length - 1
            buffer.push String.fromCharCode parseInt hex[1], 16
          when '{'
            variable = str[index..].match /\{([a-zA-Z]\w*)\}/
            index += variable[0].length - 1
            if buffer.length
              parts.push new AST.StringLiteral buffer.join ''
            parts.push new AST.IdentifierExpression variable[1]
            buffer = []
          when '['
            @_error 'Unicode name embedding not implemented yet: ' + str
      else
       buffer.push chr

    if parts.length
      if buffer.length then parts.push new AST.StringLiteral buffer.join ''
      return new AST.InfinitaryExpression 'SMOOSH', parts
    else
      return new AST.StringLiteral buffer.join ''

  # Consumes the next token, returning its text.
  # If type is provided, verifies that the token is of the specified type.
  # If text is provided, verifies that the token contains the specified text.
  # If either of the verifications fails, a ParserError is thrown.
  _consume: (type, text) ->
    unless type? or text?
      return @tokens.shift().text
    if @_nextIs type, text
      return @_consume()
    else
      expected = if text? then "#{type}('#{text or ''}')" else type
      if @tokens.length is 0
        line = '(last)'
        got = '(end of input)'
      else
        line = @tokens[0].line
        got = "#{@tokens[0].type}(#{@tokens[0].text})"
      message = "Expected: #{expected}; Got: #{got}"
      throw new ParserError line, message

  # Returns whether the next token exists and is of the specified type. If text
  # is provided, also checks whether it matches the token's text content.
  _nextIs: (type, text) ->
    return @tokens.length and @tokens[0].is type, text

  # Throws a ParserError with a given message. If line is not defined, the line
  # of the next token is used, or "(last line)" if no tokens remain.
  _error: (message, line) ->
    if line
      message += ", near #{@tokens[0].type}:'#{@tokens[0].text}'"
    else
      line = if @tokens.length then @tokens[0].line else line = '(last)'
    throw new ParserError line, message

# Exports.
@LOLCoffee.Parser = Parser
@LOLCoffee.ParserError = ParserError
