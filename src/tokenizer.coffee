class TokenizeError extends Error
  constructor: (line, message) ->
    @name = 'TokenizeError'
    @message = "Line #{line}: #{message}."

TOKEN_TYPES: ['endline', 'keyword', 'identifier', 'int', 'float', 'string']

class Token
  constructor: (@type, @text, @line) ->
    if type not in TOKEN_TYPES
      throw new TokenizeError line, 'Invalid token type: ' + type

  is: (type, text) ->
    return @type == type and (text is undefined or @text == text)

# All LOLCODE keywords in longer-first order to ensure correct greedy capture.
KEYWORDS = [
  'IF U SAY SO'
  'IM OUTTA YR'
  'QUOSHUNT OF'
  'PRODUKT OF'
  'BOTH SAEM'
  'EITHER OF'
  'HOW DUZ I'
  'SMALLR OF'
  'BIGGR OF'
  'DIFFRINT'
  'FOUND YR'
  'IM IN YR'
  'IS NOW A'
  'BOTH OF'
  'DIFF OF'
  'I HAS A'
  'KTHXBYE'
  'VISIBLE'
  'ALL OF'
  'ANY OF'
  'BUKKIT'
  'GIMMEH'
  'MOD OF'
  'NERFIN'
  'NUMBAR'
  'NO WAI'
  'O RLY\\?'
  'OMGWTF'
  'SMOOSH'
  'SUM OF'
  'WON OF'
  'YA RLY'
  'MEBBE'
  'NUMBR'
  'TROOF'
  'UPPIN'
  'FAIL'
  'GTFO'
  'MAEK'
  'MKAY'
  'NOOB'
  'WILE'
  'WTF\\?'
  'YARN'
  'HAI'
  'ITZ'
  'NOT'
  'OIC'
  'OMG'
  'TIL'
  'WIN'
  'AN'
  'YR'
  '!'
  'A'
  'R'
]
KEYWORDS = (i.replace /[ ]/g, '[ \\t\\v]+' for i in KEYWORDS)
KEYWORD_REGEX = new RegExp "^(#{KEYWORDS.join '|'})(?=$|\\b|\\W)"
STRING_REGEX = ///
  ^"                 # Starting string quote.
  (                  # Either...
    :(                 # An escape sequence, which may be one of:
      [)>o":]            # A single-character escape code.
    |
      \([\dA-Fa-f]+\)    # A hexadecimal escape sequence.
    |
      \{[A-Za-z]+\w+\}   # An embedded variable.
    |
      \[[^\[\]]+\]       # A unicode normative name.
    )
  |                  # Or...
    [^"]               # Any non-quote character.
  )*                 # Repeated any number of times.
  "                  # Ending string quote.
///

# Splits a LOLCODE source code string into a list of tokens.
tokenize = (text) ->
  tokens = []
  line = []
  line_index = 1

  # Flushes the current line to the tokens list.
  flushLine = ->
    if line.length
      tokens = tokens.concat line
      tokens.push new Token 'endline', '\n', line_index
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
    else if match = text.match /^OBTW\b[^]*\bTLDR\b/
      if line.length
        throw new TokenizeError line_index,
                                'Multi-line comments must start on a new line'
      # Ignore multi-line comment.
    else if match = text.match KEYWORD_REGEX
      keyword = match[0].replace /\s+/g, ' '
      line.push new Token 'keyword', match[0], line_index
    else if match = text.match /^[a-zA-Z]\w*/
      line.push new Token 'identifier', match[0], line_index
    else if match = text.match /^-?(\d+\.\d*|\d*\.\d+)/
      line.push new Token 'float', match[0], line_index
    else if match = text.match /^-?\d+/
      line.push new Token 'int', match[0], line_index
    else if match = text.match /^"(:([)>o":]|\([\dA-Fa-f]+\))|[^"])*"/
      line.push new Token 'string', match[0], line_index
    else
      snippet = text.match(/^.*/)[0]
      throw new TokenizeError line_index, 'Unrecognized sequence at: ' + snippet

    text = text[match[0].length..]

  flushLine()

  return tokens

# Exports.
window.LOLCoffee.Tokenizer =
  tokenize: tokenize
  TokenizeError: TokenizeError
  Token: Token
