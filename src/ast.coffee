# TODO(max99x): Write high-level documentation.

class Node
  constructor: (@body) ->

class Program extends Node
  constructor: (@body) ->

class FunctionDefinition extends Node
  constructor: (@name, @args, @body) ->

class Statement extends Node
  constructor: ->
class Return extends Statement
  constructor: (@value) ->
class Input extends Statement
  constructor: (@identifier) ->
class Output extends Statement
  constructor: (@expression) ->
class Declaration extends Statement
  constructor: (@identifier) ->
class Assignment extends Statement
  constructor: (@identifier, @expression) ->
class Break extends Statement
  constructor: ->
class StatementList extends Statement
  constructor: (@statements) ->
class Loop extends Statement
  constructor: (@label, @operation, @variable, @condition, @body) ->
class Conditional extends Statement
  constructor: (@then_body, @else_body) ->
class Select extends Statement
  constructor: (@cases, @default_case) ->

class Expression extends Node
class IdentifierExpression extends Expression
  constructor: (@identifier) ->
class CastExpression extends Expression
  constructor: (@identifier, @type) ->
class CallExpression extends Expression
  constructor: (@func_name, @args) ->
class UnaryExpression extends Expression
  constructor: (@operator, @operand) ->
class BinaryExpression extends Expression
  constructor: (@operator, @left, @right) ->
class InfinitaryExpression extends Expression
  constructor: (@operator, @operands) ->

class Literal extends Expression
class NullLiteral extends Literal
class BoolLiteral extends Literal
  constructor: (@value) ->
class IntLiteral extends Literal
  constructor: (@value) ->
class FloatLiteral extends Literal
  constructor: (@value) ->
class StringLiteral extends Literal
  constructor: (@value) ->

# Export all AST node classes.
window.LOLCoffee.AST =
  Node: Node
  Program: Program
  FunctionDefinition: FunctionDefinition
  Statement: Statement
  Return: Return
  Input: Input
  Output: Output
  Declaration: Declaration
  Assignment: Assignment
  Break: Break
  StatementList: StatementList
  Loop: Loop
  Conditional: Conditional
  Select: Select
  Expression: Expression
  IdentifierExpression: IdentifierExpression
  CastExpression: CastExpression
  CallExpression: CallExpression
  UnaryExpression: UnaryExpression
  BinaryExpression: BinaryExpression
  InfinitaryExpression: InfinitaryExpression
  Literal: Literal
  NullLiteral: NullLiteral
  BoolLiteral: BoolLiteral
  IntLiteral: IntLiteral
  FloatLiteral: FloatLiteral
  StringLiteral: StringLiteral
