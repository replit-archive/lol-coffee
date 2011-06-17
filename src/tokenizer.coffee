# TODO(max99x): Document high-level usage.

# Expand spaces to any non-newline whitespace and escape question marks.
KEYWORDS = for word in window.LOLCoffee.KEYWORDS
  word.replace(/\?/g, '\\?').replace /\s/g, '[ \\t\\v]+'
KEYWORD_REGEX = new RegExp "^(#{KEYWORDS.join '|'})(?=$|\\b|\\W)"
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

# The error thrown by the tokenizer.
class TokenizeError extends Error
  constructor: (line, message) ->
    @message = "Line #{line}: #{message}."
  name: 'TokenizeError'

# A single LOLCODE token, containing its type, text content and original line.
class Token
  constructor: (@line, @type, @text = '') ->
    if type not in Token::TYPES
      throw new TokenizeError line, 'Invalid token type: ' + type

  is: (type, text) ->
    return @type == type and (text is undefined or @text == text)

  TYPES: ['endline', 'keyword', 'identifier', 'int', 'float', 'string']

# Splits a LOLCODE source code string into a list of tokens.
tokenize = (text) ->
  tokens = []
  line = []
  line_index = 1

  # Flushes the current line to the tokens list.
  flushLine = ->
    if line.length
      tokens = tokens.concat line
      tokens.push new Token line_index, 'endline'
    line = []

  while text
    if match = text.match /^[ \t\v]+/
      # Skip spaces
    else if match = text.match /^(\r\n|\r|\n)/
      # Proceed to a new logical and physical line.
      line_index++
      flushLine()
    else if match = text.match /^,/
      # Consider the rest of the physical line a new logical line.
      flushLine()
    else if match = text.match /^(\u2026|\.\.\.)[ \t\v]*(\r\n|\r|\n)/
      # Continue the next physical line on the current logical line.
      line_index++
    else if match = text.match /^BTW\b.*/
      # Ignore single-line comment.
    else if match = text.match /^OBTW\b[^]*?\bTLDR\b/
      if line.length
        throw new TokenizeError line_index,
                                'Multi-line comments must start on a new line'
      # Ignore multi-line comment but count the lines we skipped.
      line_breaks = match[0].match /\r\n|\r|\n/g
      line_index += line_breaks.length
    else if match = text.match KEYWORD_REGEX
      keyword = match[0].replace /\s+/g, ' '
      line.push new Token line_index, 'keyword', match[0]
    else if match = text.match /^[a-zA-Z]\w*/
      line.push new Token line_index, 'identifier', match[0]
    else if match = text.match /^-?(\d+\.\d*|\d*\.\d+)/
      line.push new Token line_index, 'float', match[0]
    else if match = text.match /^-?\d+/
      line.push new Token line_index, 'int', match[0]
    else if match = text.match STRING_REGEX
      line.push new Token line_index, 'string', match[0]
    else
      snippet = text.match(/^.*/)[0]
      throw new TokenizeError line_index, 'Unrecognized sequence at: ' + snippet

    text = text[match[0].length..]

  flushLine()

  return tokens

# Exports.
window.LOLCoffee.Tokenizer =
  tokenize: tokenize
  Error: TokenizeError
  Token: Token
