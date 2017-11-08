require './dwarfdump'
require './objdump'

class HTMLWriter
    @@templatefront = ' <!DOCTYPE html>
<html>
<head>
    <title>Assembly C Example</title>
    <style type="text/css">
        * { 
            font-family: monospace; 
            line-height: 1.5em;
        }
        table {
            width: 100%;
        }
        td
        {
            padding: 8px;
            border-bottom: 2px solid black;
            vertical-align: bottom;
            width: 50%;
        }
        th
        {
            border: 1px solid black;
        }
        .grey {
            color: #888
        }
    </style>
</head>
<body>
    <table>
    '
    @@templateend = ' </table>
</body>
</html>
		'

  def initialize filename
    @filename = filename
    @dwarf = DwarfDecode.new "#{ARGV[0]}"
    @objdump = Objdump.new "#{ARGV[0]}"
    @source = []
    File.open(filename, "r") do |input|
      input.each_line.with_index do |line, index|
        @source[index+1] = line
      end
    end
  end

  # write the webpage with assembly & source
  def write
    dest = @filename + ".html"

    File.open(dest, "w") do |output|
        output.puts @@templatefront
    end

    printHtmlBody

    File.open(dest, "a") do |output|
        output.puts @@templateend
    end
  end

  # Print the whole source and assembly using given source filename
  def printHtmlBody
    dest = @filename + ".html"
    dline_info = @dwarf.line_info[@filename]
    start_addr = nil
    last_source_block = [nil, nil]

    File.open("./" + @filename, "r") do |input|
      File.open(dest, "a") do |output|
        output.puts "\t<!-- #{@filename} -->"
        dline_info.each do |pair|
          print @filename
          p pair
          last_addr = pair[0]
          p last_addr.to_s 16
          last_source_line = pair[1]

          # if not first loop and also have different source line
          if not start_addr.nil? and start_addr != last_addr
            output.puts "\t<tr>"
            output.puts "\t\t<td>"

            if last_source_block[0] == last_source_block[1]
              output.puts "\t\t\t#{@source[last_source_block[0]]}<br>"
              last_source_block[1] = last_source_line
            elsif last_source_block[0] < last_source_block[1]
              ((last_source_block[0]+1)..last_source_block[1]).each do |e|
                output.puts "\t\t\t#{@source[e]}<br>"
              end
              last_source_block[0] = last_source_block[1]
              last_source_block[1] = last_source_line
            elsif last_source_line > last_source_block[1]
              last_source_block[1] = last_source_line
            end

            output.puts "\t\t</td>" # end of source td

            output.puts "\t\t<td>"
            @objdump.getInstructionsByRange(start_addr, last_addr).each do |ins|
              output.puts "\t\t\t#{ins[:addr].to_s(16)}: #{ins[:code]}<br>"
            end

            # check if it's the end of the file, then print all remaining
            # assembly line
            if pair == dline_info.last
              func_name = @objdump.instructions_hash[last_addr][:func]
              last_instrct =  @objdump.functions[func_name].instructions.last[:addr]
              @objdump.getInstructionsByRange(last_addr, last_instrct).each do |ins|
                output.puts "\t\t\t#{ins[:addr].to_s(16)}: #{ins[:code]}<br>"
              end
            end

            output.puts "\t\t</td>" # end of instruction td
            output.puts "\t</tr>"

          end # end if not first loop

          start_addr = last_addr
          if last_source_block == [nil, nil]
            last_source_block = [last_source_line, last_source_line]
          end
          p last_source_block
        end
      end # end append
    end # end read
  end # end printHtmlBody
end

c_files = Dir["*.c"]
h_files = Dir["*.h"]
test = HTMLWriter.new "bar.c"
test.write
test = HTMLWriter.new "foo.c"
test.write
