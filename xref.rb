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
    @out = nil
    File.open(filename, "r") do |input|
      input.each_line.with_index do |line, index|
        @source[index+1] = line
      end
    end
  end

  # Write the webpage with assembly & source
  def writeWebPage
    dest = @filename + ".html"

    File.open(dest, "w") do |output|
        output.puts @@templatefront
    end

    writeHtmlBody

    File.open(dest, "a") do |output|
        output.puts @@templateend
    end
  end

  # Write c source to web page using an [start, end] array
  def writeSource source_block
    @out.puts "\t\t<td>"
    if source_block[0] != source_block[1]
      ((source_block[0]+1)..source_block[1]).each do |e|
        @out.puts "\t\t\t#{@source[e]}<br>"
      end
    else
      @out.puts "\t\t\t#{@source[source_block[0]]}<br>"
    end
    @out.puts "\t\t</td>" # end of instruction td
  end

  # Write instruction to web page using given start and end assembly address
  def writeInstruction start_addr, last_addr
    @out.puts "\t\t<td>"
    @objdump.getInstructionsByRange(start_addr, last_addr).each do |ins|
      @out.puts "\t\t\t#{ins[:addr].to_s(16)}: #{ins[:code]}<br>"
    end
    @out.puts "\t\t</td>" # end of instruction td
  end

  # Print the whole source and assembly using given source filename
  def writeHtmlBody
    dest = @filename + ".html"
    dline_info = @dwarf.line_info[@filename]
    start_addr = nil
    last_source_block = [nil, nil]
    last_diff_file = nil
    last_end = nil

    File.open("./" + @filename, "r") do |input|
      File.open(dest, "a") do |output|
        @out = output
        @out.puts "\t<!-- #{@filename} -->"
        dline_info.each do |pair|

          # Initial
          if start_addr.nil?
            start_addr = pair[:assembly_lineno]
            last_source_block = [pair[:source_lineno], pair[:source_lineno]]
            puts "#{@filename} initial #{start_addr} : #{last_source_block}"

          # check uri is another file
          elsif not pair[:uri].nil? and @filename != pair[:uri]
            output.puts "\t<tr>"
            writeSource last_source_block
            writeInstruction start_addr, pair[:assembly_lineno]
            output.puts "\t</tr>"
            last_source_block[0] = pair[:source_lineno]
            start_addr = pair[:assembly_lineno]
            last_diff_file = pair[:uri]

          # if the last iteration has a different uri
          elsif last_diff_file
            output.puts "\t\t<td>"
            # should print all from source file
            output.puts "\t<tr>"
            output.puts "outerrrr #{pair[:source_lineno]} : #{last_diff_file}"
            output.puts "\t\t</td>"
            writeInstruction start_addr, pair[:assembly_lineno]
            output.puts "\t</tr>"

            last_source_block[0] = last_source_block[1]
            last_source_block[1] = pair[:source_lineno]
            puts "test last difffile"
            p last_source_block
            last_diff_file = nil
            start_addr = pair[:assembly_lineno]

          elsif last_end == true
            start_addr = pair[:assembly_lineno]
            last_source_block = [pair[:source_lineno], pair[:source_lineno]]
            puts "end"

          # addr up and source up
          elsif pair[:assembly_lineno] > start_addr and
                pair[:source_lineno] > last_source_block[1]
            output.puts "\t<tr>"
            writeSource last_source_block
            writeInstruction start_addr, pair[:assembly_lineno]
            output.puts "\t</tr>"

            # update
            start_addr = pair[:assembly_lineno]
            last_source_block[0] = last_source_block[1]
            last_source_block[1] = pair[:source_lineno]

          # addr up and source down
          elsif pair[:assembly_lineno] > start_addr and
                pair[:source_lineno] < last_source_block[1]
            # ugly solution, but it works
            temp = last_source_block
            temp[0] = temp[0] - 1
            output.puts "\t<tr>"
            writeSource temp
            writeInstruction start_addr, pair[:assembly_lineno]
            output.puts "\t</tr>"

            # update
            start_addr = pair[:assembly_lineno]
            last_source_block = [pair[:source_lineno], pair[:source_lineno]]
            puts "addr up source down"

          # addr up and source is the same
          elsif pair[:assembly_lineno] > start_addr and
                pair[:source_lineno] == last_source_block[1]
            output.puts "\t<tr>"
            writeSource last_source_block
            writeInstruction start_addr, pair[:assembly_lineno]
            output.puts "\t</tr>"

            # update
            last_source_block[0] = last_source_block[1]
            last_source_block[1] = pair[:source_lineno]
          
          # if addr is the same and source up
          elsif pair[:assembly_lineno] == start_addr and
                pair[:source_lineno] > last_source_block[1]
            last_source_block[1] = pair[:source_lineno]

          end # end state machine

          if pair[:end].nil?
            last_end = false
          else
            last_end = true
          end
          p last_source_block
        end
      end # end append
    end # end read
  end # end writeHtmlBody
end

c_files = Dir["*.c"]
h_files = Dir["*.h"]
test = HTMLWriter.new "bar.c"
test.writeWebPage
test = HTMLWriter.new "foo.c"
test.writeWebPage
