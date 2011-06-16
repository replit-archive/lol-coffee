class ParseError extends Error
  constructor: (line, message) ->
    @name = 'ParseError'
    @message = "Line #{line}: #{message}."

class Token
  constructor: (@text, @line) ->
class KeywordToken extends Token
class IdentifierToken extends Token
class LiteralToken extends Token
class IntToken extends LiteralToken
class FloatToken extends LiteralToken
class StringToken extends LiteralToken

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

# Splits a LOLCODE source code string into an array of logical lines, each line
# an array of tokens.
tokenize = (text) ->
  lines = []
  line = []
  line_index = 1

  while text
    if match = text.match /^[ \t\v]+/
      # Skip spaces
    else if match = text.match /^(\r\n|\r|\n)/
      # Proceed to a new logical and physical line.
      line_index++
      lines.push line
      line = []
    else if match = text.match /^,/
      # Consider the rest of the physical line a new logical line.
      lines.push line
      line = []
    else if match = text.match /^(\u2026|\.\.\.)[ \t\v]*(\r\n|\r|\n)/
      # Continue the next physical line on the current logical line.
      line_index++
    else if match = text.match /^BTW\b.*/
      # Ignore single-line comment.
    else if match = text.match /^OBTW\b[^]*\bTLDR\b/
      if line.length
        throw new ParseError line_index,
                             'Multi-line comments must start on their own line'
      # Ignore multi-line comment.
    else if match = text.match KEYWORD_REGEX
      keyword = match[0].replace /\s+/g, ' '
      line.push new KeywordToken match[0], line_index
    else if match = text.match /^[a-zA-Z]\w*/
      line.push new IdentifierToken match[0], line_index
    else if match = text.match /^-?(\d+\.\d*|\d*\.\d+)/
      line.push new FloatToken match[0], line_index
    else if match = text.match /^-?\d+/
      line.push new IntToken match[0], line_index
    else if match = text.match /^"(:([)>o":]|\([\dA-Fa-f]+\))|[^"])*"/
      line.push new StringToken match[0], line_index
    else
      snippet = text.match /^.*/
      throw new ParseError line_index, 'Unrecognized sequence at: ' + snippet[0]

    text = text[match[0].length..]

  if line.length then lines.push line

  return lines

# Exports.
window.LOLCoffee.Tokenizer =
  tokenize: tokenize
  ParseError: ParseError
  Token: Token
  KeywordToken: IdentifierToken
  LiteralToken: LiteralToken
  IntToken: IntToken
  FloatToken: FloatToken
  StringToken: StringToken
