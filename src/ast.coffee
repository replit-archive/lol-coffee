# TODO(max99x): Write high-level documentation.

# The error thrown by the code generator.
class CodeGenError extends Error
  constructor: (@message) ->
  name: 'CodeGenError'

# Shortcuts.
OPC = window.LOLCoffee.OPCodes

class CodeGenContext
  constructor: ->
    @opcodes = []
    @labels = []
    @_break_stack = []

  emit: (opcode) ->
    @opcodes.push opcode

  newLabel: ->
    @labels.push null
    return @labels.length - 1
  emitLabel: (label) ->
    if label >= @labels.length
      throw new CodeGenError "Unknown label (#{label}). Top: #{@labels.length}"
    @labels[label] = @opcodes.length

  getBreakLabel: ->
    return @_break_stack[@_break_stack.length - 1]
  popBreakLabel: ->
    @_break_stack.pop()
  pushBreakLabel: (label) ->
    @_break_stack.push label

class Node
  codegen: (context) ->
    throw new Error 'Abstract method!'

class Program extends Node
  constructor: (@body) ->
  codegen: (context) ->
    @body.codegen context
    context.emit new OPC.Halt

class FunctionDefinition extends Node
  constructor: (@name, @args, @body) ->
  codegen: (context) ->
    start_label = context.newLabel()
    end_label = context.newLabel()
    context.emit new OPC.DeclareFunction @name, start_label
    context.emit new OPC.Jump end_label
    context.emitLabel start_label

    @args.reverse()
    for arg in @args
      context.emit new OPC.DeclareVariable arg
      context.emit new OPC.Assign arg

    @body.codegen context
    context.emitLabel end_label

class Statement extends Node
  codegen: (context) ->
    throw new Error 'Abstract method!'

class Return extends Statement
  constructor: (@value) ->
  codegen: (context) ->
    @value.codegen context
    context.emit new OPC.Return

class Input extends Statement
  constructor: (@identifier) ->
  codegen: (context) ->
    context.emit new OPC.Input
    context.emit new OPC.PushSyscallResult
    context.emit new OPC.Assign @identifier

class Output extends Statement
  constructor: (@expression) ->
  codegen: (context) ->
    @expression.codegen context
    context.emit new OPC.Output

class Declaration extends Statement
  constructor: (@identifier) ->
  codegen: (context) ->
    context.emit new OPC.DeclareVariable @identifier

class Assignment extends Statement
  constructor: (@identifier, @expression) ->
  codegen: (context) ->
    @expression.codegen context
    context.emit new OPC.Assign @identifier

class Break extends Statement
  constructor: ->
  codegen: (context) ->
    context.emit new OPC.Jump context.getBreakLabel()

class StatementList extends Statement
  constructor: (@statements) ->
  codegen: (context) ->
    for statement in @statements
      statement.codegen context

class Conditional extends Statement
  constructor: (@then_body, @else_body) ->
  codegen: (context) ->
    else_label = context.newLabel()
    end_label = context.newLabel()
    context.emit new OPC.PushVariable 'IT'
    context.emit new OPC.Cast 'bool'
    context.emit new OPC.JumpIfZero else_label
    @then_body.codegen context
    context.emit new OPC.Jump end_label
    context.emitLabel else_label
    if @else_body then @else_body.codegen context
    context.emitLabel end_label

class Select extends Statement
  constructor: (@cases, @default_case) ->
  codegen: (context) ->
    case_tuple.push context.newLabel() for case_tuple in @cases
    if @default_case then default_label = context.newLabel()
    end_label = context.newLabel()

    for [condition, _, label] in @cases
      condition.codegen context
      context.emit new OPC.PushVariable 'IT'
      context.emit new OPC.Unequal
      context.emit new OPC.JumpIfZero label
    if @default_case
      context.emit new OPC.Jump default_label

    context.pushBreakLabel end_label
    for [_, body, label] in @cases
      context.emitLabel label
      body.codegen context
    if @default_case
      context.emitLabel default_label
      @default_case.codegen context
    context.popBreakLabel()

    context.emitLabel end_label

class Loop extends Statement
  constructor: (@step, @condition, @body) ->
  codegen: (context) ->
    start_label = context.newLabel()
    end_label = context.newLabel()

    context.emitLabel start_label
    if @condition
      @condition.codegen context
      context.emit new OPC.Cast 'bool'
      context.emit new OPC.JumpIfZero end_label

    @body.codegen context
    if @step then @step.codegen context
    context.emit new OPC.Jump start_label

    context.emitLabel end_label

class Expression extends Node
  codegen: (context) ->
    throw new Error 'Abstract method!'

class CallExpression extends Expression
  constructor: (@func_name, @args) ->
  codegen: (context) ->
    for arg in @args
      arg.codegen context
    context.emit new OPC.Call @func_name, @args.length

class IdentifierExpression extends Expression
  constructor: (@identifier) ->
  codegen: (context) ->
    context.emit new OPC.PushVariable @identifier

class CastExpression extends Expression
  constructor: (@expression, @type) ->
  codegen: (context) ->
    @expression.codegen context
    sane_type = switch @type
      when 'NOOB' then 'null'
      when 'TROOF' then 'bool'
      when 'NUMBR' then 'int'
      when 'NUMBAR' then 'float'
      when 'YARN' then 'string'
    context.emit new OPC.Cast sane_type, true

class InfinitaryExpression extends Expression
  constructor: (@operator, @operands) ->
  codegen: (context) ->
    @operands.reverse()
    for operand in @operands
      operand.codegen context
    op = switch @operator
      when 'ALL OF' then new OPC.All @operands.length
      when 'ANY OF' then new OPC.Any @operands.length
      when 'SMOOSH' then new OPC.Concat @operands.length
      else throw new CodeGenError 'Unknown infinitary operator.'
    context.emit op

class BinaryExpression extends Expression
  constructor: (@operator, @left, @right) ->
  codegen: (context) ->
    @right.codegen context
    @left.codegen context
    op = switch @operator
      when 'SUM OF' then new OPC.Add
      when 'DIFF OF' then new OPC.Subtract
      when 'PRODUKT OF' then new OPC.Multiply
      when 'QUOSHUNT OF' then new OPC.Divide
      when 'MOD OF' then new OPC.Modulo
      when 'BIGGR OF' then new OPC.Max
      when 'SMALLR OF' then new OPC.Min
      when 'BOTH OF' then new OPC.And
      when 'EITHER OF' then new OPC.Or
      when 'WON OF' then new OPC.Xor
      when 'BOTH SAEM' then new OPC.Equal
      when 'DIFFRINT' then new OPC.Unequal
      else throw new CodeGenError 'Unknown binary operator.'
    context.emit op

class UnaryExpression extends Expression
  constructor: (@operator, @operand) ->
  codegen: (context) ->
    @operand.codegen context
    op = switch @operator
      when 'NOT' then new OPC.Invert
      else throw new CodeGenError 'Unknown unary operator.'
    context.emit op

class Literal extends Expression
  codegen: (context) ->
    throw new Error 'Abstract method!'

class NullLiteral extends Literal
  codegen: (context) ->
    context.emit new OPC.PushLiteral 'null', null

class BoolLiteral extends Literal
  constructor: (@value) ->
  codegen: (context) ->
    context.emit new OPC.PushLiteral 'bool', @value

class IntLiteral extends Literal
  constructor: (@value) ->
  codegen: (context) ->
    context.emit new OPC.PushLiteral 'int', @value

class FloatLiteral extends Literal
  constructor: (@value) ->
  codegen: (context) ->
    context.emit new OPC.PushLiteral 'float', @value

class StringLiteral extends Literal
  constructor: (@value) ->
  codegen: (context) ->
    context.emit new OPC.PushLiteral 'string', @value

# Export the codegen error.
window.LOLCoffee.CodeGenError = CodeGenError
# Export the codegen context class.
window.LOLCoffee.CodeGenContext = CodeGenContext
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
