###
Codegenable parse tree nodes for LOLCODE. The nodes are organized into a
hierarchy rooted at LOLCoffee.AST.Node:
  Node
    Program
    Statement
      FunctionDefinition
      Declaration
      Return
      Input
      Output
      Assignment
      IndexedAssignment
      Break
      Loop
      Conditional
      Switch
      StatementList
      Expression
        IdentifierExpression
        IndexingExpression
        CastExpression
        CallExpression
        UnaryExpression
        BinaryExpression
        InfinitaryExpression
        Literal
          NullLiteral
          BoolLiteral
          IntLiteral
          FloatLiteral
          StringLiteral

Each node has a codegen method that takes a CodeGenContext and emits the
instructions and labels that implement the node. The CodeGenContext keeps track
of the labels and instructions created by the nodes. It can be used to codegen
multiple programs. Each time it is used, the new instructions and labels are
appended to the existing ones. This allows multiple programs to run on the same
VM and share globals, as in the context of a REPL.

Example usage:
  parsed_program_1 = ...
  parsed_program_2 = ...
  codegen_context = new LOLCoffee.CodeGenContext
  try
    parsed_program_1.codegen codegen_context
    # Can now sync the VM to codegen_context and run the first program.
    parsed_program_2.codegen codegen_context
    # Can now sync the VM to codegen_context and run the second program.
  catch error
    console.assert error instanceof LOLCoffee.CodeGenError
    console.log error

Provides:
  LOLCoffee.CodeGenError
  LOLCoffee.CodeGenContext
  LOLCoffee.AST

Requires:
  LOLCoffee.Instructions
###

# Imports.
Instructions = @LOLCoffee.Instructions

# The type of error thrown by the code generator.
class CodeGenError extends Error
  constructor: (@message) ->
  name: 'CodeGenError'

# A persistent context for code generation which keeps track of emitted
# instructions, labels and loop labels (for breaking out).
class CodeGenContext
  constructor: ->
    @instructions = []
    @labels = []
    @_break_stack = []

  emit: (instruction) ->
    @instructions.push instruction

  newLabel: ->
    @labels.push null
    return @labels.length - 1
  emitLabel: (label) ->
    if label >= @labels.length
      throw new CodeGenError "Unknown label (#{label}). Top: #{@labels.length}"
    @labels[label] = @instructions.length

  getBreakLabel: ->
    return @_break_stack[@_break_stack.length - 1]
  popBreakLabel: ->
    @_break_stack.pop()
  pushBreakLabel: (label) ->
    @_break_stack.push label

# An abstract base class for all nodes.
class Node

# A program containing a list of statements followed by halt.
class Program extends Node
  constructor: (@body) ->
  codegen: (context) ->
    @body.codegen context
    context.emit new Instructions.Halt

# A function definition contains a declaration, a body and a jump after the
# declaration to the end of the body.
class FunctionDefinition extends Node
  constructor: (@name, @args, @body) ->
  codegen: (context) ->
    start_label = context.newLabel()
    end_label = context.newLabel()
    context.emit new Instructions.DeclareFunction @name, start_label
    context.emit new Instructions.Jump end_label
    context.emitLabel start_label

    @args.reverse()
    for arg in @args
      context.emit new Instructions.DeclareVariable arg
      context.emit new Instructions.Assign arg

    @body.codegen context
    context.emitLabel end_label

# An abstract base class for all statements.
class Statement extends Node

# A return statement. A value evaluation followed by a return instruction.
class Return extends Statement
  constructor: (@value) ->
  codegen: (context) ->
    @value.codegen context
    context.emit new Instructions.Return

# An input statement. An input instruction, and an assignment from its result.
class Input extends Statement
  constructor: (@identifier) ->
  codegen: (context) ->
    context.emit new Instructions.Input
    context.emit new Instructions.PushSyscallResult
    context.emit new Instructions.Assign @identifier

# An output statement. A value evaluation followed by an output instruction.
class Output extends Statement
  constructor: (@expression) ->
  codegen: (context) ->
    @expression.codegen context
    context.emit new Instructions.Output

# A variable declaration statement. Translated directly to its instruction.
class Declaration extends Statement
  constructor: (@identifier) ->
  codegen: (context) ->
    context.emit new Instructions.DeclareVariable @identifier

# An assignment statement. A value evaluation followed by an assignment
# instruction.
class Assignment extends Statement
  constructor: (@identifier, @value) ->
  codegen: (context) ->
    @value.codegen context
    context.emit new Instructions.Assign @identifier

# An index assignment statement. Value and evaluations followed by an assignment
# at index instruction.
class IndexedAssignment extends Statement
  constructor: (@identifier, @index, @value) ->
  codegen: (context) ->
    @value.codegen context
    @index.codegen context
    context.emit new Instructions.AssignAtIndex @identifier

# A break statement. An jump to the nearest loop/switch context end label.
class Break extends Statement
  constructor: ->
  codegen: (context) ->
    context.emit new Instructions.Jump context.getBreakLabel()

# A list of statements. Simply generates all its statements in order.
class StatementList extends Statement
  constructor: (@statements) ->
  codegen: (context) ->
    for statement in @statements
      statement.codegen context

# An If condition. A comparison that selectively jumps to the code generated by
# then_body or else_body then to the end.
class Conditional extends Statement
  constructor: (@then_body, @else_body) ->
  codegen: (context) ->
    else_label = context.newLabel()
    end_label = context.newLabel()
    context.emit new Instructions.PushVariable 'IT'
    context.emit new Instructions.Cast 'bool'
    context.emit new Instructions.JumpIfZero else_label
    @then_body.codegen context
    context.emit new Instructions.Jump end_label
    context.emitLabel else_label
    if @else_body then @else_body.codegen context
    context.emitLabel end_label

# A switch statement. Generates all its blocks within its context preceded by
# a series of comparisons that jump to the first matching case block.
class Switch extends Statement
  constructor: (@cases, @default_case) ->
  codegen: (context) ->
    case_tuple.push context.newLabel() for case_tuple in @cases
    if @default_case then default_label = context.newLabel()
    end_label = context.newLabel()

    for [condition, _, label] in @cases
      condition.codegen context
      context.emit new Instructions.PushVariable 'IT'
      context.emit new Instructions.Unequal
      context.emit new Instructions.JumpIfZero label
    if @default_case
      context.emit new Instructions.Jump default_label

    context.pushBreakLabel end_label
    for [_, body, label] in @cases
      context.emitLabel label
      body.codegen context
    if @default_case
      context.emitLabel default_label
      @default_case.codegen context
    context.popBreakLabel()

    context.emitLabel end_label

# A loop statement. Generates a condition check with a conditional jump to the
# end, followed by its body and step, then a jump back to the condition.
class Loop extends Statement
  constructor: (@step, @condition, @body) ->
  codegen: (context) ->
    start_label = context.newLabel()
    end_label = context.newLabel()

    context.emitLabel start_label
    if @condition
      @condition.codegen context
      context.emit new Instructions.Cast 'bool'
      context.emit new Instructions.JumpIfZero end_label

    @body.codegen context
    if @step then @step.codegen context
    context.emit new Instructions.Jump start_label

    context.emitLabel end_label

# An abstract base class for all expressions.
class Expression extends Node

# A call expression. Generates all the arguments followed by a call instruction.
class CallExpression extends Expression
  constructor: (@func_name, @args) ->
  codegen: (context) ->
    for arg in @args
      arg.codegen context
    context.emit new Instructions.Call @func_name, @args.length

# An identifier evaluation expression. Translated directly to a variable lookup
# instruction.
class IdentifierExpression extends Expression
  constructor: (@identifier) ->
  codegen: (context) ->
    context.emit new Instructions.PushVariable @identifier

# An indexing expression. Evaluates the index, then the base and then applies
# the index to the base usign an indexing instruction.
class IndexingExpression extends Expression
  constructor: (@base, @index) ->
  codegen: (context) ->
    @index.codegen context
    @base.codegen context
    context.emit new Instructions.GetIndex

# A cast expression. Translated directly to a cast instruction.
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
    context.emit new Instructions.Cast sane_type, true

# An n-ary expression with variable N. Generates its operands in reverse order
# then the appropriate instruction depending on the operator.
class InfinitaryExpression extends Expression
  constructor: (@operator, @operands) ->
  codegen: (context) ->
    @operands.reverse()
    for operand in @operands
      operand.codegen context
    op = switch @operator
      when 'ALL OF' then new Instructions.All @operands.length
      when 'ANY OF' then new Instructions.Any @operands.length
      when 'SMOOSH' then new Instructions.Concat @operands.length
      else throw new CodeGenError 'Unknown infinitary operator.'
    context.emit op

# An binary expression with variable N. Generates its operands in reverse order
# then the appropriate instruction depending on the operator.
class BinaryExpression extends Expression
  constructor: (@operator, @left, @right) ->
  codegen: (context) ->
    @right.codegen context
    @left.codegen context
    op = switch @operator
      when 'SUM OF' then new Instructions.Add
      when 'DIFF OF' then new Instructions.Subtract
      when 'PRODUKT OF' then new Instructions.Multiply
      when 'QUOSHUNT OF' then new Instructions.Divide
      when 'MOD OF' then new Instructions.Modulo
      when 'BIGGR OF' then new Instructions.Max
      when 'SMALLR OF' then new Instructions.Min
      when 'BOTH OF' then new Instructions.And
      when 'EITHER OF' then new Instructions.Or
      when 'WON OF' then new Instructions.Xor
      when 'BOTH SAEM' then new Instructions.Equal
      when 'DIFFRINT' then new Instructions.Unequal
      else throw new CodeGenError 'Unknown binary operator.'
    context.emit op

# An n-ary expression with variable N. Generates its operand then the
# appropriate instruction depending on the operator.
class UnaryExpression extends Expression
  constructor: (@operator, @operand) ->
  codegen: (context) ->
    @operand.codegen context
    op = switch @operator
      when 'NOT' then new Instructions.Invert
      when 'LENGZ OF' then new Instructions.GetLength
      when 'CHARZ OF' then new Instructions.FromCharCode
      when 'ORDZ OF' then new Instructions.ToCharCode
      else throw new CodeGenError 'Unknown unary operator.'
    context.emit op

# An abstract base class for all literals.
class Literal extends Expression

# A null literal. Generates a push of its value onto the stack.
class NullLiteral extends Literal
  codegen: (context) ->
    context.emit new Instructions.PushLiteral 'null', null

# A boolean literal. Generates a push of its value onto the stack.
class BoolLiteral extends Literal
  constructor: (@value) ->
  codegen: (context) ->
    context.emit new Instructions.PushLiteral 'bool', @value

# An integer literal. Generates a push of its value onto the stack.
class IntLiteral extends Literal
  constructor: (@value) ->
  codegen: (context) ->
    context.emit new Instructions.PushLiteral 'int', @value

# A floating point literal. Generates a push of its value onto the stack.
class FloatLiteral extends Literal
  constructor: (@value) ->
  codegen: (context) ->
    context.emit new Instructions.PushLiteral 'float', @value

# A string literal. Generates a push of its value onto the stack.
class StringLiteral extends Literal
  constructor: (@value) ->
  codegen: (context) ->
    context.emit new Instructions.PushLiteral 'string', @value

# Exports.
@LOLCoffee.CodeGenError = CodeGenError
@LOLCoffee.CodeGenContext = CodeGenContext
@LOLCoffee.AST =
  Node: Node
  Program: Program
  Statement: Statement
  FunctionDefinition: FunctionDefinition
  Declaration: Declaration
  Return: Return
  Input: Input
  Output: Output
  Assignment: Assignment
  IndexedAssignment: IndexedAssignment
  Break: Break
  Loop: Loop
  Conditional: Conditional
  Switch: Switch
  StatementList: StatementList
  Expression: Expression
  IdentifierExpression: IdentifierExpression
  IndexingExpression: IndexingExpression
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
