class Objdump
  attr_reader :filename, :functions, :instructions

  def initialize(filename)
    @filename = filename
    @functions = {}
    @instructions = []

    output = %x{ objdump -d #{filename} }

    # patterns

    # the func name in the bracket
    func_proto_pattern = /0000000000\w+\s<(\w+)>:/    # name is in group[1]
    instruction_pattern = /^\ {2}(\w{6}):\s+(.+)/     # address in group[1], instruction in group[2]

    last_func_name = nil

    # fill functions' info
    output.each_line do |line|
      if (line.match func_proto_pattern)
        m = line.match func_proto_pattern
        last_func_name = m[1]
        @functions[last_func_name] = Function.new last_func_name
      elsif (line.match instruction_pattern)
        m = line.match instruction_pattern
        instruction = Instruction.new m[1], m[2], last_func_name
        @functions[last_func_name].add_instruction instruction
        # @instructions[m[1].to_i(16)] = {:code => m[2], :func => last_func_name}
        @instructions << { :debug => m[1], :addr => m[1].to_i(16), :code => m[2] }
      end
    end

    # return an array of instructions by given start address and end address
    # start address should smaller than end address
    def getInstructionsByRange start_addr, end_addr
      result = []
      @instructions.each_with_object(result) do |instruction, acc|
        if instruction[:addr] >= start_addr and instruction[:addr] < end_addr
          acc << instruction
        elsif instruction[:addr] >= end_addr
          break
        end
      end
      result
    end

    def to_s
      s = ""
      @instructions.each_with_index do |e, i|
        s += "line #{i} : #{e}"
      end
    end
  end

  class Instruction
    attr_accessor :address, :code, :func

    # address is int
    def initialize address, code, func
      @address = address
      @code = code
      @func = func
    end
  end

  class Function
    attr_accessor :name, :instructions

    def initialize name
      @name = name
      @instructions = []
    end

    def add_instruction instruction
      @instructions << instruction.code
    end
  end
end

# test
ooo = Objdump.new "a.out"
p ooo.getInstructionsByRange(4195712, 4195728)
