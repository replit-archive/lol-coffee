###
A tokenizer for LOLCODE. Splits a LOLCODE source code string into a list of
tokens. Comments are automatically stripped. Line continuation using ellipses
and soft statement terminators using commas are also taken into account.
Multi-word keywords are captured is separated by any inline whitespace. The
produced tokens are tagged with their physical line numbers for error reporting.

The resulting tokens can be of the following types:
  keyword: "HAI", "YA RLY", ...
  identifier: "X3", "First_Counter", ...
  int literals: 123, -456, 0, ..
  float literals: 1.2, 3., .4, -6.2, ...
  string literals: "a::b:(3F)c:{counter}d:[foo]efg", ...

Example usage:
  tokenizer = new LOLCoffee.Tokenizer source_text
  try
    tokens = tokenizer.tokenize()
  catch error
    console.assert error instanceof LOLCoffee.TokenizerError
    console.log error

Provides:
  LOLCoffee.Tokenizer
  LOLCoffee.TokenizerError

Requires:
  LOLCoffee.KEYWORDS
###

KEYWORDS = @LOLCoffee.KEYWORDS

# Regular expressions for various token types.
INT_REGEX = /^-?\d+/
FLOAT_REGEX = /^-?(\d+\.\d*|\.\d+)/
IDENTIFIER_REGEX = /^[a-zA-Z]\w*/
MULTILINE_COMMENT_REGEX = /^OBTW\b[^]*?\bTLDR\b/
COMMENT_REGEX = /^BTW\b.*/
LINE_CONTINUATION_REGEX = /^(\u2026|\.\.\.)[ \t\v]*(\r\n|\r|\n)/
STATEMENT_END_REGEX = /^(\r\n|\r|\n|,)/
INLINE_SPACE_REGEX = /^[ \t\v]+/
STRING_REGEX = ///
  ^"                 # Starting string quote.
  (?:                # Either...
    :(?:               # An escape sequence, which may be one of:
      [)>o":]            # A single-character escape code.
    |
      \([\dA-Fa-f]+\)    # A hexadecimal escape sequence.
    |
      \{[A-Za-z]\w*\}    # An embedded variable.
    |
      \[[^\[\]]+\]       # A unicode normative name.
    )
  |                  # Or...
    [^":]              # Any non-quote non-escape character.
  )*                 # Repeated any number of times.
  "                  # Ending string quote.
///
# Expand spaces to any non-newline whitespace and escape question marks.
KEYWORDS = for word in KEYWORDS
  word.replace(/\?/g, '\\?').replace /\s/g, '[ \\t\\v]+'
KEYWORD_REGEX = new RegExp "^(#{KEYWORDS.join '|'})(?=$|\\b|\\W)"

# The type of error thrown by the tokenizer.
class TokenizerError extends Error
  constructor: (line, message) ->
    @message = "Line #{line}: #{message}."
  name: 'TokenizerError'

# A single LOLCODE token, containing its type, text content and original line.
class Token
  constructor: (@line, @type, @text = '') ->
    if type not in Token::TYPES
      throw new TokenizerError line, 'Invalid token type: ' + type

  is: (type, text) ->
    return @type == type and (text is undefined or @text == text)

  TYPES: ['endline', 'keyword', 'identifier', 'int', 'float', 'string']

# A tokenizer that splits LOLCODE source into a stream of tokens.
class Tokenizer
  constructor: (@text) ->
    @tokens = []
    @line = []
    @line_index = 1

  # Runs the tokenization pass, returning a list of tokens.
  tokenize: ->
    while @text
      if match = @text.match INLINE_SPACE_REGEX
        # Skip inline spaces.
      else if match = @text.match LINE_CONTINUATION_REGEX
        if STATEMENT_END_REGEX.test @text[match[0].length..]
          @_error 'Cannot have an empty line after line continuation'
        # Skip continue lines.
      else if match = @text.match STATEMENT_END_REGEX
        # Consider the rest of the physical line a new logical line.
        @_flushLine()
      else if match = @text.match COMMENT_REGEX
        # Skip single-line comment.
      else if match = @text.match MULTILINE_COMMENT_REGEX
        # Skip multi-line comment, making sure it starts on an empty line.
        if @line.length
          @_error 'Multiline comments must start on a new line'
      else if match = @text.match KEYWORD_REGEX
        # Capture the keyword, collapsing extra whitespace.
        @_emit 'keyword', match[0].replace /\s+/g, ' '
      else if match = @text.match IDENTIFIER_REGEX
        @_emit 'identifier', match[0]
      else if match = @text.match FLOAT_REGEX
        @_emit 'float', match[0]
      else if match = @text.match INT_REGEX
        @_emit 'int', match[0]
      else if match = @text.match STRING_REGEX
        @_emit 'string', match[0]
      else
        # No token pattern matched.
        snippet = @text.match(/^.*/)[0]
        @_error 'Unrecognized sequence at: ' + snippet

      line_breaks = match[0].match /\r\n|\r|\n/g
      if line_breaks then @line_index += line_breaks.length
      @text = @text[match[0].length..]

    @_flushLine()

    return @tokens

  # Flushes the current line to the tokens list.
  _flushLine: ->
    if @line.length
      @tokens = @tokens.concat @line
      @tokens.push new Token @line_index, 'endline'
    @line = []

  # Adds a new token of the given type and value to the current line.
  _emit: (type, value) ->
    @line.push new Token @line_index, type, value

  _error: (message) ->
    throw new TokenizerError @line_index, message

# Exports.
@LOLCoffee.Tokenizer = Tokenizer
@LOLCoffee.TokenizerError = TokenizerError
