# TODO(max99x): Write high-level documentation.

# The error thrown by the virtual machine.
class ExecError extends Error
  constructor: (@message) ->
  name: 'ExecError'

class Value
  constructor: (@type, @value) ->

  equal: (other) ->
    if @type in ['float', 'int'] and other.type in ['float', 'int']
      return @value == other.value
    else if @type == other.type
      return @value == other.value
    else
      return false

  cast: (to_type, explicit = false) ->
    if to_type is 'null' then throw new ExecError 'Cannot cast tp NOOB'
    result = null
    switch @type
      when 'null'
        if explicit
          if to_type not of window.LOLCoffee.DEFAULT_VALUES
            throw new ExecError 'Unknown type ' + to_type
          result = window.LOLCoffee.DEFAULT_VALUES[to_type]
        else
          unless to_type is 'bool'
            throw new ExecError 'Cannot implicitly cast NOOB to ' + to_type
          result = false
      when 'bool'
        result = switch to_type
          when 'bool' then @value
          when 'int', 'float' then Number @value
          when 'string' then (if @value then 'WIN' else 'FAIL')
          else throw new ExecError 'Unknown type ' + to_type
      when 'int'
        result = switch to_type
          when 'bool' then @value != 0
          when 'int', 'float' then @value
          when 'string' then String @value 
          else throw new ExecError 'Unknown type ' + to_type
      when 'float'
        result = switch to_type
          when 'bool' then @value != 0
          when 'int' then Math.floor @value
          when 'float' then @value
          when 'string' then String @value 
          else throw new ExecError 'Unknown type ' + to_type
      when 'string'
        result = switch to_type
          when 'bool' then @value != ''
          when 'int'
            unless /^-?\d+$/.test @value
              throw new ExecError "Cannot parse integer from '#{@value}'"
            parseInt @value, 10
          when 'float'
            unless /^-?(\d+(\.\d*)?|\.\d+)$/.test @value
              throw new ExecError "Cannot parse float from '#{@value}'"
            parseFloat @value
          when 'string' then @value
          else throw new ExecError 'Unknown type ' + to_type
      else throw new ExecError 'Unknown type ' + @type
    return new Value to_type, result

class Frame
  constructor: (@stack_size, @opcode_ptr, @variables = {}) ->

class VirtualMachine
  constructor: (@input, @output, @error, @done) ->
    @opcode_ptr = 0
    @opcodes = []
    @labels = []
    @data_stack = []
    @frame_stack = [new Frame 0, 0, IT: new Value('null', null)]
    @functions = {}
    @halted = true
    @blocked = false
    @syscall_result = null

  sync: (codegen_context) ->
    @opcodes = codegen_context.opcodes[0..]
    @labels = codegen_context.labels[0..]
    @halted = false

  step: ->
    if @blocked or @halted
      throw new ExecError 'Cannot execute while blocked or halted'
    try
      @opcodes[@opcode_ptr++].exec @
    catch e
      @error e
      @halted = true

  run: ->
    @step() until @blocked or @halted

  block: ->
    @blocked = true

  pause: ->
    @blocked = true

  resume: (syscall_result = null) ->
    @syscall_result = syscall_result
    @blocked = false
    @run()

# Exports.
window.LOLCoffee.VirtualMachine = VirtualMachine
window.LOLCoffee.ExecError = ExecError
window.LOLCoffee.Value = Value
window.LOLCoffee.Frame = Frame
