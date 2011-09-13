#LOLCoffee

A REPL-friendly LOLCODE compiler and virtual machine written in CoffeeScript.
Strictly implements the [LOLCODE 1.2 spec](http://lolcode.com/specs/1.2),
except for the following deviations:

1. The `HAI`/`KTHXBYE` enclosing block is optional, for REPL friendliness.
2. `BUKKIT` is a reserved word, in case arrays are introduced later.
3. String indexing rvalue, using `<string> AT <index>`.
4. String indexing lvalue, using `PUTZ <expression> INTA <string> AT <index>`.
5. String length, using `LENGZ OF <string>`.
6. The ASCII code of the first character of a string, using `ORDZ OF <string>`.
7. Convertion of ASCII codes to a string, using `CHARZ OF <string>`.

### License

LOLCoffee is available under the MIT license.
