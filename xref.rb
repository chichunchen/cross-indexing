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
  end

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

  def hasBranch? code
    if not code.include? "$" and code.match /\d\w{5}/
      true
    else
      false
    end
  end

  # Print the whole source and assembly using given source filename
  def printHtmlBody
    dest = @filename + ".html"

    dline_info = @dwarf.line_info[@filename]
    block_start = nil
    code_block = ""

    File.open("./" + @filename, "r") do |input|
      File.open(dest, "a") do |output|
        output.puts "<!-- #{@filename} -->"
        @objdump.instructions.each do |assembly|
          
        end
      end # end append
    end # end read
  end # end printHtmlBody
end

c_files = Dir["*.c"]
h_files = Dir["*.h"]
c_files.each do |dot_c|
    test = HTMLWriter.new dot_c
    test.write
end
