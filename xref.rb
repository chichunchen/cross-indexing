require './dwarfdump'
require './objdump'

class HTMLWriter
    @@templatefront = "<!DOCTYPE html> <html> <body><pre>"
    @@templateend = " </pre> </body> </html>"

    def initialize filename
        dest = filename + ".html"

        File.open(dest, "w") do |output|
            output.puts @@templatefront
        end

        printHtmlBody filename

        File.open(dest, "a") do |output|
            output.puts @@templateend
        end
    end

    def printHtmlBody filename
        source = filename
        dest = filename + ".html"

        dwarf = DwarfDecode.new "a.out"
        dline_info = dwarf.line_info['a']
        objdump = Objdump::Translate.new "a.out"
        block_start = nil
        code_block = ""

        File.open("./" + filename, "r") do |input|
            File.open(dest, "a") do |output|
                input.each_line.with_index do |line, index|

                source_line = index+1
                code_addr = dline_info[source_line]

                # Check if the source line has it own instructions, if it has,
                # then we simply prints out all the instructions left for the
                # last source line.
                if not block_start.nil? and not code_addr.nil?
                  block_end = code_addr.to_i(16)
                  # puts "start #{objdump.instructions[block_start]}"
                  (block_start...block_end).each do |i|
                    if not objdump.instructions[i].nil?
                      output.puts "#{i.to_s(16)}: #{objdump.instructions[i]}"
                    end
                  end
                  # puts "end"
                end

                output.puts "line: #{source_line}: #{line}"

                # If the current source line has a corresponding instruction
                # then save the address of the instruction.
                # The saving is for producing multiple instructions for a source
                # line.
                if not code_addr.nil?
                  block_start = code_addr.to_i(16)
                end
              end
              output.flush
            end
        end
    end
end

test = HTMLWriter.new "a.c"
