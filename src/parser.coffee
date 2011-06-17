# TODO(max99x): Document high-level usage.

# The error thrown by the parser.
class ParseError extends Error
  constructor: (line, message) ->
    @message = "Line #{line}: #{message}."
  name: 'ParseError'

# Shortcut.
AST = window.LOLCoffee.AST

# TODO(max99x): Document.
class Parser
  constructor: (@tokens, @function_arities={}) ->
    # Used to disambiguate GTFO - break in loops and switches or empty return in
    # functions.
    @_scope_depth = 0
    @_in_function = false
  Error: ParseError

  # Program ::= (Statement | FunctionDefition)* |
  #             "HAI" [1.2] (Statement | FunctionDefition)* "KTHXBAI"
  parseProgram: ->
    started_with_hai = @tokens[0].is 'keyword', 'HAI'
    if started_with_hai
      if @tokens.length >= 2 and @tokens[1].is 'endline'
        @tokens = @tokens[2..]
      else if (@tokens.length >= 3 and @tokens[1].is('float', '1.2') and
               @tokens[2].is('endline'))
        @tokens = @tokens[3..]
      else
        @_error 'HAI must be followed by "1.2" or a new line'

    statements = []
    while @tokens.length
      if @tokens[0].is 'keyword', 'KTHXBYE'
        if not started_with_hai
          @_error 'KTHXBYE is not allowed when HAI is not used'
        if @tokens.length < 2
          @_error 'Unexpected end of input in program tail'
        @tokens = @tokens[1..]
        if not @tokens[0].is 'endline'
          @_error 'KTHXBYE must be followed by a new line'
        @tokens = @tokens[1..]
        break
      else if @tokens[0].is 'endline'
        if started_with_hai then @_error 'Expected KTHXBYE'
        @tokens = @tokens[1..]
        break
      else if @tokens[0].is 'keyword', 'HOW DUZ I'
        statements.push @parseFunctionDefinition()
      else
        statements.push @parseStatement()

    if @tokens.length isnt 0
      @_error 'Unexpected input after program end'

    return new AST.Program new AST.StatementList statements

  # FunctionDefinition ::= "HOW DUZ I" IDENTIFIER FunctionArgs ENDLINE
  #                          Statement*
  #                        "IF U SAY SO" ENDLINE
  parseFunctionDefinition: ->
    # Read declaration.
    if not @tokens[0].is 'keyword', 'HOW DUZ I'
      @_error 'Function definition must start with "HOW DUZ I"'
    @tokens = @tokens[1..]

    if not @tokens[0].is 'identifier'
      @_error 'Function definition must contain a name'
    name = @tokens[0].text
    @tokens = @tokens[1..]

    args = @parseFunctionArgs()

    if not @tokens[0].is 'endline'
      @_error 'Leftover tokens in function declaration'
    @tokens = @tokens[1..]

    # Rememeber the function arity as soon as the declaration is read, so we
    # can call the function recursively.
    @function_arities[name] = args.length

    # Read body.
    @_in_function = true
    statements = []
    while @tokens.length and not @tokens[0].is 'keyword', 'IF U SAY SO'
      statements.push @parseStatement()
    statements.push new AST.Return new AST.IdentifierExpression 'IT'
    body = new AST.StatementList statements
    @_in_function = false

    # Read tail.
    if @tokens.length < 2
      @_error 'Unexpected end of input'
    if not @tokens[0].is 'keyword', 'IF U SAY SO'
      @_error 'Function definition must end with "IF U SAY SO"'
    @tokens = @tokens[1..]
    if not @tokens[0].is 'endline'
      @_error 'Leftover tokens after function body'
    @tokens = @tokens[1..]

    return new AST.Function name, args, body

  # FunctionArgs ::= ["YR" IDENTIFIER ("AN" "YR" IDENTIFIER)*]
  parseFunctionArgs: ->
    args = []
    while @tokens.length >= 2 and @tokens[0].is 'keyword', 'YR'
      args.push @tokens[1].text
      @tokens = @tokens[2..]
      if @tokens.length >= 1 and @tokens[0].is 'keyword', 'AN'
        @tokens = @tokens[1..]
      else
        break
    return args

  # Statement ::= (LoopDefinition | ConditionalStatement | SwitchStatement |
  #                Declaration | Assignment | Expression | InputStatement |
  #                CastStatement | "GTFO" | "FOUND YR" Expression) ENDLINE
  parseStatement: ->
    if @tokens.length < 1 then @_error 'Unexpected end of input'

    if @tokens[0].is 'keyword', 'IM IN YR'
      statement = @parseLoopDefinition()
    else if @tokens[0].is 'keyword', 'O RLY?'
      statement = @parseConditionalStatement()
    else if @tokens[0].is 'keyword', 'WTF?'
      statement = @parseSwitchStatement()
    else if @tokens[0].is 'keyword', 'I HAS A'
      statement = @parseDeclaration()
    else if @tokens[0].is 'keyword', 'GIMMEH'
      statement = @parseInputStatement()
    else if @tokens[0].is 'keyword', 'VISIBLE'
      statement = @parseOutputStatement()
    else if @tokens[0].is 'keyword', 'GTFO'
      if @_scope_depth > 0
        statement = new AST.Break
      else if @_in_function
        statement = new AST.Return new AST.NullLiteral
      else
        @_error 'GTFO must be inside a loop, switch, or function'
      @tokens = @tokens[1..]
    else if @tokens[0].is 'keyword', 'FOUND YR'
      @tokens = @tokens[1..]
      if not @_in_function then @_error 'FOUND YR must be inside a function'
      statement = new AST.Return @parseExpression()
    else if (@tokens.length >= 2 and @tokens[0].is('identifier') and
        @tokens[1].is 'keyword', 'R')
      statement = @parseAssignment()
    else if (@tokens.length >= 2 and @tokens[0].is('identifier') and
        @tokens[1].is 'keyword', 'IS NOW A')
      statement = @parseCastStatement()
    else
      statement = new AST.Assignment 'IT', @parseExpression()

    if @tokens.length < 1 then @_error 'Unexpected end of input'
    if @tokens[0].is 'endline'
      @tokens = @tokens[1..]
    else
      @_error 'No new line at end of statement'

    return statement

  # InputStatement ::= "GIMMEH" IDENTIFIER
  parseInputStatement: ->
    if @tokens.length < 2
      @_error 'Unexpected end of input in an input statement'
    if not @tokens[0].is 'keyword', 'GIMMEH'
      @_error 'An input statement must start with GIMMEH'
    @tokens = @tokens[1..]

    if not @tokens[0].is 'identifier'
      @_error 'An identifier must follow GIMMEH'
    input = new AST.Input @tokens[0].text
    @tokens = @tokens[1..]

    return input

  # Declaration ::= "I HAS A" IDENTIFIER ["ITZ" (Expression | "A" Type)]
  parseDeclaration: ->
    if @tokens.length < 2
      @_error 'Unexpected end of input in declaration'
    if not @tokens[0].is 'keyword', 'I HAS A'
      @_error 'A declaration must start with I HAS A'
    @tokens = @tokens[1..]

    if not @tokens[0].is 'identifier'
      @_error 'An identifier must follow I HAS A'
    variable = @tokens[0].text
    declaration = new AST.Declaration variable
    @tokens = @tokens[1..]

    if @tokens.length >= 1 and @tokens[0].is 'keyword', 'ITZ'
      @tokens = @tokens[1..]
      if @tokens.length < 1 then @_error 'Unexpected end of input after ITZ'
      if @tokens[0].is 'keyword', 'A'
        @tokens = @tokens[1..]
        value = window.LOLCoffee.DEFAULT_VALUES[@parseType()]
        assignment = new AST.Assignment variable, value
      else 
        assignment = new AST.Assignment variable, @parseExpression()
      return new AST.StatementList [declaration, assignment]
    else
      return declaration

  # Assignment ::= IDENTIFIER "R" Expression
  parseAssignment: ->
    if @tokens.length < 2 then @_error 'Unexpected end of input in assignment'
    if not @tokens[0].is 'identifier'
      @_error 'An assignment must start with an identifier'
    variable = @tokens[0].text
    @tokens = @tokens[1..]

    if not @tokens[0].is 'keyword', 'R'
      @_error 'Missing assignment operator R'
    @tokens = @tokens[1..]

    return new AST.Assignment variable, @parseExpression()

  # LoopDefinition ::= "IM IN YR" IDENTIFIER
  #                    [IDENTIFIER "YR" IDENTIFIER
  #                     [("WILE" | "TIL") Expression]]
  #                    ENDLINE
  #                    Statement*
  #                    "IM OUTTA YR" IDENTIFIER
  parseLoopDefinition: ->
    # Minimal header.
    if @tokens.length < 3
      @_error 'Unexpected end of input in loop declaration'
    if not @tokens[0].is 'keyword', 'IM IN YR'
      @_error 'A loop must start with IM IN YR'
    @tokens = @tokens[1..]

    if not @tokens[0].is 'identifier'
      @_error 'A label must follow IM IN YR'
    label = @tokens[0].text
    @tokens = @tokens[1..]

    # Extended header.
    operation = variable = condition = null
    if not @tokens[0].is 'endline'
      # Step operation.
      if @tokens.length < 4
        @_error 'Unexpected end of input in loop declaration'

      if not (@tokens[0].is('keyword', 'UPPIN') or
              @tokens[0].is('keyword', 'NERFIN') or
              @tokens[0].is('identifier'))
        @_error 'A loop operation must follow the loop label'
      operation = @tokens[0].text
      @tokens = @tokens[1..]

      if not @tokens[0].is 'keyword', 'YR'
        @_error 'A loop operation must be followed by YR'
      @tokens = @tokens[1..]

      if not @tokens[0].is 'identifier'
        @_error 'A loop variable must follow YR in a loop'
      variable = @tokens[0].text
      @tokens = @tokens[1..]

      # TODO(max99x): Convert operation+variable into an Expression.
      #               Account for UPPIN, NERFIN.

      if not @tokens[0].is 'endline'
        # Condition.
        if @tokens.length < 1
          @_error 'Unexpected end of input in loop declaration'
        if @tokens[0].is 'keyword', 'WILE'
          inverted = false
        else if @tokens[0].is 'keyword', 'TIL'
          inverted = true
        else
          @_error 'A loop variable must be followed by WILE or TIL'
        @tokens = @tokens[1..]
        limit = @parseExpression()
        if inverted then limit = new AST.UnaryExpression 'NOT', limit

    if not @tokens[0].is 'endline'
      @_error 'Missing new line after loop declaration'
    @tokens = @tokens[1..]

    # Body.
    @_scope_depth++
    statements = []
    while true
      if @tokens.length < 2
        @_error 'Unexpected end of input in loop body'
      if @tokens[0].is 'keyword', 'IM OUTTA YR' then break
      statements.push @parseStatement()
    body = new AST.StatementList statements
    @_scope_depth--

    # Tail.
    if @tokens.length < 2
      @_error 'Unexpected end of input in loop tail'
    if not @tokens[0].is 'keyword', 'IM OUTTA YR'
      @_error 'Loops must end with IM OUTTA YR'
    @tokens = @tokens[1..]

    if not @tokens[0].is 'identifier'
      @_error 'Missing label after IM OUTTA YR'
    if @tokens[0].text != label
      @_error 'Mismatched loop label'
    @tokens = @tokens[1..]

    return new AST.Loop label, operation, variable, condition, body

  # ConditionalStatement ::= "O RLY?" ENDLINE
  #                          "YA RLY" Statement*
  #                          ("MEBBE" Expression ENDLINE Statement*)*
  #                          ["NO WAI" Statement*]
  #                          "OIC"
  parseConditionalStatement: ->
    # Header
    if @tokens.length < 3
      @_error 'Unexpected end of input in conditional header'
    if not @tokens[0].is 'keyword', 'O RLY?'
      @_error 'Conditionals must start with O RLY?'
    @tokens = @tokens[1..]
    if not @tokens[0].is 'endline'
      @_error 'Missing new line after O RLY?'
    @tokens = @tokens[1..]
    if not @tokens[0].is 'keyword', 'YA RLY'
      @_error 'A conditional must start with a YA RLY block'
    @tokens = @tokens[1..]
    if not @tokens[0].is 'endline'
      @_error 'Missing new line after YA RLY'
    @tokens = @tokens[1..]

    # Then body.
    then_statements = []
    while true
      if @tokens.length < 1
        @_error 'Unexpected end of input in conditional body'
      if (@tokens[0].is('keyword', 'MEBBE') or
          @tokens[0].is('keyword', 'NO WAI') or
          @tokens[0].is('keyword', 'OIC')) then break
      then_statements.push @parseStatement()
    then_body = new AST.StatementList then_statements

    # Optional elseif bodies.
    elseif_tuples = []
    while @tokens[0].is 'keyword', 'MEBBE'
      @tokens = @tokens[1..]
      expression = @parseExpression()
      if @tokens.length < 2
        @_error 'Unexpected end of input in conditional body'
      if not @tokens[0].is 'endline'
        @_error 'A new line must follow a MEBBE expression'
      @tokens = @tokens[1..]

      elseif_statements = []
      while not (@tokens[0].is('keyword', 'MEBBE') or
                 @tokens[0].is('keyword', 'NO WAI') or
                 @tokens[0].is('keyword', 'OIC'))
        elseif_statements.push @parseStatement()
      elseif_tuples.push [expression, new AST.StatementList elseif_statements]

    # Optional else body.
    else_statements = []
    else_body = null
    if not @tokens[0].is 'keyword', 'OIC'
      if not @tokens[0].is 'keyword', 'NO WAI'
        @_error 'Expected NO WAI block or OIC'
      @tokens = @tokens[1..]
      if not @tokens[0].is 'endline'
        @_error 'Missing new line after NO WAI'
      @tokens = @tokens[1..]
      while @tokens.length >= 1 and not @tokens[0].is 'keyword', 'OIC'
        else_statements.push @parseStatement()
      if else_statements then else_body = new AST.StatementList else_statements

    if not @tokens[0].is 'keyword', 'OIC'
      @_error 'Missing OIC at end of conditional'
    @tokens = @tokens[1..]

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
    if @tokens.length < 3
      @_error 'Unexpected end of input in select header'
    if not @tokens[0].is 'keyword', 'WTF?'
      @_error 'Select statements must start with WTF?'
    @tokens = @tokens[1..]
    if not @tokens[0].is 'endline'
      @_error 'Missing new line after WTF?'
    @tokens = @tokens[1..]

    # List of cases.
    cases = []
    default_case = null
    @_scope_depth++
    while @tokens.length >= 1
      if @tokens[0].is 'keyword', 'OMG'
        # Case statement.
        @tokens = @tokens[1..]
        case_literal_line = @tokens[0].line
        literal = @parseLiteral()
        if not (literal instanceof AST.Literal)
          @_error 'OMG value must be a literal', case_literal_line
        if @tokens.length < 2 or not @tokens[0].is 'endline'
          @_error 'Missing new line after OMG literal'
        @tokens = @tokens[1..]
        case_statements = []
        while not (@tokens[0].is('keyword', 'OMG') or
                   @tokens[0].is('keyword', 'OMGWTF') or
                   @tokens[0].is('keyword', 'OIC'))
          case_statements.push @parseStatement()
        cases.push [literal, new AST.StatementList case_statements]
      else if @tokens[0].is 'keyword', 'OMGWTF'
        @tokens = @tokens[1..]
        if @tokens.length < 1 or not @tokens[0].is 'endline'
          @_error 'Missing new line after OMGWTF'
        @tokens = @tokens[1..]
        # Default statement.
        default_statements = []
        while not @tokens[0].is 'keyword', 'OIC'
          default_statements.push @parseStatement()
        default_case = new AST.StatementList default_statements
      else
        # End.
        if @tokens.length < 1
          @_error 'Unexpected end of input in select tail'
        if not @tokens[0].is 'keyword', 'OIC'
          @_error 'Select statements must end with OIC'
        @tokens = @tokens[1..]
        break
    @_scope_depth--

    return new AST.Select cases, default_case

  # Expression ::= CastExpression | FunctionCall | IDENTIFIER | LITERAL
  parseExpression: ->
    if @tokens.length < 1
      @_error 'Unexpected end of input in expression'
    if @tokens[0].is 'keyword', 'MAEK'
      return @parseCastExpression()
    else if @tokens[0].is 'keyword'
      if @tokens[0].text in window.LOLCoffee.UNARY_OPERATORS
        return @parseUnaryExpression()
      else if @tokens[0].text in window.LOLCoffee.BINARY_OPERATORS
        return @parseBinaryExpression()
      else if @tokens[0].text in window.LOLCoffee.INFINITARY_OPERATORS
        return @parseInfinitaryExpression()
      else if @tokens[0].text in ['WIN', 'FAIL', 'NOOB']
        return @parseLiteral()
      else
        @_error 'Invalid keyword at start of expression'
    else if @tokens[0].is 'identifier'
      if @tokens[0].text of @function_arities
        return @parseFunctionCall()
      else
        identifier = new AST.IdentifierExpression @tokens[0].text
        @tokens = @tokens[1..]
        return identifier
    else
      return @parseLiteral()

  # CastExpression ::= MAEK IDENTIFIER ["A"] Type
  parseCastExpression: ->
    if @tokens.length < 3
      @_error 'Unexpected end of input in cast expression'
    if not @tokens[0].is 'keyword', 'MAEK'
      @_error 'Cast expressions must start with MAEK'
    @tokens = @tokens[1..]
    if not @tokens[0].is 'identifier'
      @_error 'An identifier must follow MAEK'
    identifier = @tokens[0].text
    @tokens = @tokens[1..]
    if @tokens[0].is 'keyword', 'A'
      @tokens = @tokens[1..]
    if @tokens.length < 1
      @_error 'Unexpected end of input in cast expression'
    return new AST.CastExpression identifier, @parseType()

  # CastStatement ::= IDENTIFIER "IS NOW A" Type
  parseCastStatement: ->
    if @tokens.length < 3
      @_error 'Unexpected end of input in cast statement'
    if not @tokens[0].is 'identifier'
      @_error 'Cast statements must start with an identifier'
    identifier = @tokens[0].text
    @tokens = @tokens[1..]
    if not @tokens[0].is 'keyword', 'IS NOW A'
      @_error 'A cast statement must use the operator IS NOW A'
    @tokens = @tokens[1..]
    expression = new AST.CastExpression identifier, @parseType()
    return new AST.Assignment identifier, expression

  # Type ::= "YARN" | "NUMBR" | "NUMBAR" | "TROOF" | "NOOB"
  parseType: ->
    if @tokens.length < 1
      @_error 'Unexpected end of input in type'
    if not @tokens[0].is 'keyword'
      @_error 'A type must be a keyword'
    type = @tokens[0].text
    if type not in ['YARN', 'NUMBR', 'NUMBAR', 'TROOF', 'NOOB']
      @_error 'Unkonwn type'
    @tokens = @tokens[1..]
    return type

  # Literal ::= STRING | INT | FLOAT | "WIN" | "FAIL" | "NOOB"
  parseLiteral: ->
    if @tokens.length < 1
      @_error 'Unexpected end of input in literal'
    token = @tokens[0]
    @tokens = @tokens[1..]
    if token.is 'string'
      return @_createStringLiteral token.text
    else if token.is 'int'
      return new AST.IntLiteral token.text
    else if token.is 'float'
      return new AST.FloatLiteral token.text
    else if token.is 'keyword'
      if token.text in ['WIN', 'FAIL']
        return new AST.BoolLiteral token.text
      else if token.text is 'NOOB'
        return new AST.NullLiteral
    else
      @_error 'Could not parse literal', token.line

  # FunctionCall ::= IDENTIFIER Expression{arity}
  parseFunctionCall: ->
    if @tokens.length < 1
      @_error 'Unexpected end of input in function call'
    if not @tokens[0].is 'identifier'
      @_error 'Expected a function name'
    func = @tokens[0].text
    @tokens = @tokens[1..]
    if func not of @function_arities
      @_error 'Undefined function: ' + func
    args = (@parseExpression() for _ in [1..@function_arities[func]])
    return new AST.CallExpression func, args

  # OutputStatement ::= "VISIBLE" Expression* ["!"] (?= ENDLINE)
  parseOutputStatement: ->
    if @tokens.length < 2
      @_error 'Unexpected end of input in output statement'
    if not @tokens[0].is 'keyword', 'VISIBLE'
      @_error 'An output statement must start with VISIBLE'
    @tokens = @tokens[1..]

    args = []
    while not (@tokens[0].is('keyword', '!') or @tokens[0].is('endline'))
      args.push @parseExpression()
      if @tokens.length < 1
        @_error 'Unexpected end of input in output statement'

    if @tokens[0].is 'keyword', '!'
      @tokens = @tokens[1..]
    else
      args.push new AST.StringLiteral '\n'

    return new AST.Output new AST.InfinitaryExpression 'SMOOSH', args

  # UnaryExpression ::= UNARY_OPERATOR Expression
  parseUnaryExpression: ->
    if @tokens.length < 1
      @_error 'Unexpected end of input in unary expression'
    if not @tokens[0].is 'keyword'
      @_error 'A unary expression must start with a keyword'
    operator = @tokens[0].text
    if operator not in window.LOLCoffee.UNARY_OPERATORS
      @_error 'Unknown unary operator'
    @tokens = @tokens[1..]
    return new AST.UnaryExpression operator, @parseExpression()

  # BinaryExpression ::= BINARY_OPERATOR Expression ["AN"] Expression
  parseBinaryExpression: ->
    if @tokens.length < 1
      @_error 'Unexpected end of input in binary expression'
    if not @tokens[0].is 'keyword'
      @_error 'A binary expression must start with a keyword'
    operator = @tokens[0].text
    if operator not in window.LOLCoffee.BINARY_OPERATORS
      @_error 'Unknown binary operator'
    @tokens = @tokens[1..]

    left = @parseExpression()

    if @tokens.length < 1
      @_error 'Unexpected end of input in binary expression'
    if @tokens[0].is 'keyword', 'AN'
      @tokens = @tokens[1..]

    right = @parseExpression()

    return new AST.BinaryExpression operator, left, right

  # InfinitaryExpression ::= INFINITARY_OPERATOR Expression (["AN"] Expression)*
  #                          ("MKAY" | (?= ENDLINE))
  parseInfinitaryExpression: ->
    if @tokens.length < 1
      @_error 'Unexpected end of input in infinitary expression'
    if not @tokens[0].is 'keyword'
      @_error 'An infinitary expression must start with a keyword'
    operator = @tokens[0].text
    if operator not in window.LOLCoffee.INFINITARY_OPERATORS
      @_error 'Unknown infinitary operator'
    @tokens = @tokens[1..]

    args = [@parseExpression()]
    while not (@tokens[0].is('keyword', 'MKAY') or @tokens[0].is('endline'))
      if @tokens[0].is 'keyword', 'AN'
        @tokens = @tokens[1..]
      args.push @parseExpression()

    if @tokens[0].is 'keyword', 'MKAY'
      @tokens = @tokens[1..]

    return new AST.InfinitaryExpression operator, args

  _createStringLiteral: (str) ->
    if not /^".*"$/.test str
      @_error 'Invalid string literal: ' + str, 0
    str = str[1...-1]

    parts = []
    buffer = []
    for char, index in str
      if char is ':'
        char = str[++index]
        switch char
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
            # var
          when '['
            @_error 'Unicode name embedding not implemented yet: ' + str, 0
      else
       buffer.push char

    if parts.length
      if buffer.length then parts.push new AST.StringLiteral buffer.join ''
      return new AST.InfinitaryExpression 'SMOOSH', parts
    else
      return new AST.StringLiteral buffer.join ''

  _error: (message, line) ->
    if not line?
      line = if @tokens.length then @tokens[0].line else line = -1

    if line == -1
      line = '(last)'
    else if line == 0
      line = if @tokens.length then @tokens[0].line else '(last)'
    else
      message += ", near #{@tokens[0].type}:'#{@tokens[0].text}'"
    throw new ParseError line, message

# Exports.
window.LOLCoffee.Parser = Parser
