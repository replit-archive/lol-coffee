# TODO(max99x): Write high-level documentation.

# Shortcuts.
Value = window.LOLCoffee.Value
Frame = window.LOLCoffee.Frame
ExecError = window.LOLCoffee.ExecError

class Halt
  exec: (machine) ->
    machine.halted = true
    machine.done()

class Jump
  constructor: (@label) ->
  exec: (machine) ->
    machine.opcode_ptr = machine.labels[@label]

class JumpIfZero
  constructor: (@label) ->
  exec: (machine) ->
    if machine.data_stack.pop().value == false
      machine.opcode_ptr = machine.labels[@label]

class DeclareFunction
  constructor: (@name, @label) ->
  exec: (machine) ->
    machine.functions[@name] = machine.labels[@label]

class DeclareVariable
  constructor: (@identifier) ->
  exec: (machine) ->
    if @identifier is 'IT'
      throw new ExecError 'Cannot declare the special variable IT'
    top_frame = machine.frame_stack[-1..][0]
    top_frame.variables[@identifier] = new Value 'null', null

class Assign
  constructor: (@identifier) ->
  exec: (machine) ->
    global_vars = machine.frame_stack[0].variables
    local_vars = machine.frame_stack[-1..][0].variables
    value = machine.data_stack.pop()

    if @identifier of local_vars
      local_vars[@identifier] = value
    else if @identifier of global_vars
      global_vars[@identifier] = value
    else
      throw new ExecError 'Assignment to undefined variable: ' + @identifier

class Input
  exec: (machine) ->
    machine.pause()
    machine.input()

class Output
  exec: (machine) ->
    machine.pause()
    machine.output machine.data_stack.pop().value

class PushSyscallResult
  exec: (machine) ->
    result = machine.syscall_result
    result = if result then String result else ''
    machine.data_stack.push new Value 'string', result

class PushVariable
  constructor: (@identifier) ->
  exec: (machine) ->
    global_vars = machine.frame_stack[0].variables
    local_vars = machine.frame_stack[-1..][0].variables

    if @identifier of local_vars
      value = local_vars[@identifier]
    else if @identifier of global_vars
      value = global_vars[@identifier]
    else
      throw new ExecError 'Reference to undefined variable: ' + @identifier
    machine.data_stack.push value

class PushLiteral
  constructor: (@type, @value) ->
  exec: (machine) ->
    machine.data_stack.push new Value @type, @value

class Cast
  constructor: (@type, @explicit = false) ->
  exec: (machine) ->
    machine.data_stack.push machine.data_stack.pop().cast @type, @explicit

class Call
  constructor: (@func_name, @args_count) ->
  exec: (machine) ->
    stack_size = machine.data_stack.length - @args_count
    machine.frame_stack.push new Frame stack_size, machine.opcode_ptr
    machine.opcode_ptr = machine.functions[@func_name]

class Return
  exec: (machine) ->
    result = machine.data_stack.pop()
    frame = machine.frame_stack.pop()

    machine.opcode_ptr = frame.opcode_ptr
    machine.data_stack.length = frame.stack_size

    machine.data_stack.push result

class All
  constructor: (@args_count) ->
  exec: (machine) ->
    args = for _ in [0...@args_count]
      machine.data_stack.pop().cast('bool').value
    result = true
    for arg in args
      unless arg then result = false; break
    machine.data_stack.push new Value 'bool', result

class Any
  constructor: (@args_count) ->
  exec: (machine) ->
    args = for _ in [0...@args_count]
      machine.data_stack.pop().cast('bool').value
    result = false
    for arg in args
      if arg then result = true; break
    machine.data_stack.push new Value 'bool', result

class Concat
  constructor: (@args_count) ->
  exec: (machine) ->
    args = for _ in [0...@args_count]
      machine.data_stack.pop().cast('string').value
    machine.data_stack.push new Value 'string', args.join ''

class MathOperation
  exec: (machine, operation) ->
    left = machine.data_stack.pop()
    right = machine.data_stack.pop()
    type = if 'float' in [left.type, right.type] then 'float' else 'int'
    left = left.cast(type).value
    right = right.cast(type).value
    result = operation left, right
    if type is 'int' then result = Math.floor result
    machine.data_stack.push new Value type, result

class Add extends MathOperation
  exec: (machine) ->
    super machine, (x, y) -> x + y

class Subtract extends MathOperation
  exec: (machine) ->
    super machine, (x, y) -> x - y

class Multiply extends MathOperation
  exec: (machine) ->
    super machine, (x, y) -> x * y

class Divide extends MathOperation
  exec: (machine) ->
    super machine, (x, y) -> x / y

class Modulo extends MathOperation
  exec: (machine) ->
    super machine, (x, y) -> x % y

class Max extends MathOperation
  exec: (machine) ->
    super machine, (x, y) -> if x > y then x else y

class Min extends MathOperation
  exec: (machine) ->
    super machine, (x, y) -> if x < y then x else y

class BoolOperation
  exec: (machine, operation) ->
    left = machine.data_stack.pop().cast('bool').value
    right = machine.data_stack.pop().cast('bool').value
    machine.data_stack.push new Value 'bool', operation left, right

class And extends BoolOperation
  exec: (machine) ->
    super machine, (x, y) -> x and y

class Or extends BoolOperation
  exec: (machine) ->
    super machine, (x, y) -> x or y

class Xor extends BoolOperation
  exec: (machine) ->
    super machine, (x, y) -> x ^ y

class Equal
  exec: (machine) ->
    left = machine.data_stack.pop()
    right = machine.data_stack.pop()
    machine.data_stack.push new Value 'bool', left.equal right

class Unequal
  exec: (machine) ->
    left = machine.data_stack.pop()
    right = machine.data_stack.pop()
    machine.data_stack.push new Value 'bool', not left.equal right

class Invert
  exec: (machine) ->
    operand = machine.data_stack.pop().cast('bool').value
    machine.data_stack.push new Value 'bool', not operand

# Export all Opcode classes.
window.LOLCoffee.OPCodes =
  Halt: Halt
  PushLiteral: PushLiteral
  DeclareFunction: DeclareFunction
  Jump: Jump
  DeclareVariable: DeclareVariable
  Assign: Assign
  Return: Return
  Input: Input
  PushSyscallResult: PushSyscallResult
  Output: Output
  PushVariable: PushVariable
  Cast: Cast
  JumpIfZero: JumpIfZero
  Call: Call
  All: All
  Any: Any
  Concat: Concat
  Add: Add
  Subtract: Subtract
  Multiply: Multiply
  Divide: Divide
  Modulo: Modulo
  Max: Max
  Min: Min
  And: And
  Or: Or
  Xor: Xor
  Equal: Equal
  Unequal: Unequal
  Invert: Invert
