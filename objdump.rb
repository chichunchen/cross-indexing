class Instruction
  attr_accessor :address, :code

  def initialize address, code
    @address = address
    @code = code
  end
end

class Function
  attr_accessor :name, :instructions

  def initialize name
    @name = name
    @instructions = []

    # puts "create new func: #{@name}"
  end

  def add_instruction instruction
    @instructions << instruction
  end
end

class ObjectDump
  attr_reader :filename, :functions

  def initialize filename
    @filename = filename
    @functions = {}

    # write objdump to file system
    objdump_filename = filename + ".obj"
    command = "objdump -d #{filename} > #{objdump_filename}"
    system(command)

    # patterns

    # the func name in the bracket
    func_proto_pattern = /0000000000\w+\s<(\w+)>:/    # name is in group[1]
    instruction_pattern = /^\ {2}(\w{6}):\s+(.+)/     # address in group[1], instruction in group[2]

    last_func_name = nil

    # fill functions' info
    f = File.open("./" + objdump_filename, "r")
    f.each_line do |line|
      if (line.match func_proto_pattern)
        m = line.match func_proto_pattern
        last_func_name = m[1]
        @functions[last_func_name] = Function.new last_func_name
      elsif (line.match instruction_pattern)
        m = line.match instruction_pattern
        instruction = Instruction.new m[1], m[2]
        @functions[last_func_name].add_instruction instruction
      end
    end
    f.close
  end
end

# test
# ooo = ObjectDump.new "a.out"
# p ooo.functions["qq"]
# p ooo.functions["main"]
# p ooo.functions["abc"]
# p ooo.functions["gg"]
