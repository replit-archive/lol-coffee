#LOLCoffee

A REPL-friendly LOLCODE compiler and virtual machine written in CoffeeScript.
Strictly implements the [LOLCODE 1.2 spec](http://lolcode.com/specs/1.2),
except for the following deviations:

1. The `HAI`/`KTHXBYE` enclosing block is optional, for REPL friendliness.
2. `BUKKIT` is a reserved word, in case arrays are introduced later.

Planned but still unimplemented extensions to the standard are:

1. String indexing rvalue, using `TAEK <index> OV DA <string>`.
2. String indexing lvalue, using `<string> AT <index> IZ NAO <expression>`.
3. String length, using `LEN OF <string>`.
4. The ASCII code of the first character of a string, using `ORD OF <string>`.
5. Convertion of ASCII codes to a string, using `CHR OF <string>`.
