#LOLCoffee

A REPL-friendly LOLCODE compiler and virtual machine written in CoffeeScript.
Implements the LOLCODE 1.2 spec, except for the following changes:

1. Empty statements are allowed after ellipses.
2. `BUKKIT` is a reserved word.

Planned but still unimplemented deviations from the standard are:

1. String indexing, using `TAEK <index> OV DA <string>`.
2. String length, using `LEN OF <string>`.
3. The ASCII code of the first character of a string, using `ORD OF <string>`.
4. Convertion of ASCII codes to a string, using `CHR OF <string>`.
