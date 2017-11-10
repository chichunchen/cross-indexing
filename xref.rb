require './dwarfdump'
require './objdump'

class HTMLWriter
    @@folder_name = 'HTML'
    @@index_file = 'index.html'
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

  # Initialize using a c source file name
  # and it currently reads the binary filename from argv[0], which
  # might not be a good idea, but do it later.
  #
  # public function:
  # initialize
  # writeWebPage
  def initialize executable
    @executable = executable
    @dwarf = DwarfDecode.new "#{@executable}"
    @objdump = Objdump.new "#{@executable}"
    @allfiles = []
    @main_at = nil
    @used_list = {}     # key is the source filename
                        # value is the bitmap(array) with size of source and
                        # each element is nil if not printed, not nil (true) is printed

    # create new HTML folder
    if Dir.exist? @@folder_name
      # puts "rm -rf #{@@folder_name}"
      system 'rm', '-rf', @@folder_name
      Dir.mkdir @@folder_name
    else
      Dir.mkdir @@folder_name
    end

    # init header file used list
    Dir.glob("*.h") do |filename|
      line_count = `wc -l "#{filename}"`.strip.split(' ')[0].to_i
      @used_list[filename] = Array.new(line_count+1)
      p filename
      p @used_list[filename]
    end

    # producing web pages using all c source files
    Dir.glob("*.c") do |filename|
      @source = []
      @filename = filename
      @out = nil
      @dest = @@folder_name + '/' + @filename + '.html'
      @allfiles << @filename + '.html'

      # convert all sources into array
      File.open(@filename, "r") do |input|
        input.each_line.with_index do |line, index|
          @source[index+1] = line
        end
      end

      @used_list[@filename] = Array.new(@source.size)

      writeWebPage
    end

    # add index.html
    File.open(@@folder_name + '/' + @@index_file, "w") do |output|
      @allfiles.each do |file|
        output.puts "<a href=\"#{File.join(Dir.pwd, file)}\">"
        output.puts file
        output.puts "</a>"
        output.puts "<br>"
      end

      # link to main
      output.puts "<a href=\"#{File.join(Dir.pwd, @main_at)}\#main\">"
      output.puts "link to main"
      output.puts "</a>"
      output.puts "<br>"

      # when and where xref was run
      output.puts "<p> xref was run on #{Dir.pwd} </p>"
      output.puts "<p> xref was run at #{Time.now} </p>"
    end
  end

  private

    # Write the webpage with assembly & source
    def writeWebPage
      File.open(@dest, "w") do |output|
        @out = output
        @out.puts @@templatefront
        writeHtmlBody
        @out.puts @@templateend
      end
    end

    # Encode normal string to html.
    def htmlEncoding string
      space_pattern = /(^\s+)(.*)/
      result = ""

      string.gsub!(/\&/, '&amp;')
      string.gsub!(/\>/, '&gt;')
      string.gsub!(/\</, '&lt;')

      if string.match space_pattern
        # temp[1] -> spaces
        # temp[2] -> code
        temp = string.match space_pattern
        temp[1].size.times { |i| result += '&nbsp;' }
        result += temp[2]
        result
      else
        result = string
      end

      return result
    end

    # Write source code (which can be .c/.h) to web page using an
    # source_block: [start, end] array.
    def writeSource source, source_block, endFlag=nil
      if source_block[0] != source_block[1]
        (source_block[0]..source_block[1]).each do |e|
          # TODO
          # if e is the smallest in dwarf
          # then print from 1

          # print if haven't print it
          if @used_list[@filename][e].nil?
            @out.puts(htmlEncoding("#{source[e]}"))
            @out.puts "<br>"
            @used_list[@filename][e] = true
          end
        end
      else
        @out.puts(htmlEncoding("#{source[source_block[0]]}"))
        @out.puts "<br>"
        @used_list[@filename][source_block[0]] = true
      end
    end

    # Write instruction to web page using given start and end assembly address
    # use endFlag to deal with outputing the remaining instructions in the function
    # that the address in range[0].
    # If the instruction contains fixed address, then out put its link.
    def writeInstruction range, endFlag=nil
      fixed_address_pattern = /(\b[a-f0-9]{6}\ )/
      func_pattern = /<([\w\+]+)>/

      if endFlag.nil?
        start_addr, last_addr = range[0], range[1]
      elsif endFlag == true
        # find instruction's function name using start_addr
        start_addr = range[0]
        name = @objdump.instructions_hash[start_addr][:func]
        last_addr = @objdump.functions[name].instructions.last[:addr] + 1
      end
      @out.puts "\t\t<td>"
      @objdump.getInstructionsByRange(start_addr, last_addr).each do |ins|
        if fixed_address_pattern.match ins[:code] and func_pattern.match ins[:code]
          tag = func_pattern.match ins[:code]
          modified_code = ins[:code].gsub(/\ <[\w\+]*>/, '')
          @out.puts "\t\t\t <a href=\"##{tag[1]}\">"
          @out.puts "\t\t\t#{ins[:addr].to_s(16)}: #{modified_code}<br>"
          @out.puts "\t\t\t </a>"
        else
          @out.puts "\t\t\t#{ins[:addr].to_s(16)}: #{ins[:code]}<br>"
        end
      end
      @out.puts "\t\t</td>" # end of instruction td
    end

    # Write source and instruction using given range
    def writeCode sourceRange, instructRange, endFlag=nil
      @out.puts "\t<tr>"
      @out.puts "\t\t<td>"

      # If sourceRange[0] is the first instruction in the Function
      # then print out the tag.
      name = @objdump.instructions_hash[instructRange[0]][:func]
      if @objdump.functions[name].instructions.first[:addr] == instructRange[0]
        @out.puts "\t\t\t<a name=\"#{name}\">"
        if @main_at.nil? and name == 'main'
          @main_at = @dest
        end
      end

      writeSource @source, sourceRange, endFlag

      @out.puts "\t\t</td>" # end of instruction td
      writeInstruction instructRange, endFlag
      @out.puts "\t</tr>"
    end

    # Print the whole source and assembly using given source filename
    def writeHtmlBody
      dline_info = @dwarf.line_info[@filename]
      start_addr = nil
      last_source_block = [nil, nil]    # the source block from last iteration
      last_diff_file = nil              # check diff uri
      last_end = nil                    # check ET

      File.open("./" + @filename, "r") do |input|
        @out.puts "\t<!-- #{@filename} -->"
        dline_info.each do |pair|

          # Initial
          if start_addr.nil?
            # update
            start_addr = pair[:assembly_lineno]
            last_source_block = [pair[:source_lineno], pair[:source_lineno]]
            puts "#{@filename} initial #{start_addr} : #{last_source_block}"

          # Check uri is another file
          elsif not pair[:uri].nil? and @filename != pair[:uri]
            writeCode last_source_block, [start_addr, pair[:assembly_lineno]]

            # update
            last_source_block[0] = pair[:source_lineno]+1
            start_addr = pair[:assembly_lineno]
            last_diff_file = pair[:uri]

          # If the last iteration has a different uri
          elsif last_diff_file
            # should print all from source file
            @out.puts "\t<tr>"
            @out.puts "\t\t<td>"
            source_end = last_source_block[0]
            # write file outside the @source file
            File.open(last_diff_file, "r").each_with_index do |input, index|
              lineno = index+1
              if @used_list[last_diff_file][lineno].nil?
                @out.puts(htmlEncoding("#{input}"))
                @out.puts "<br>"
                @used_list[last_diff_file][lineno] = true
              end
              break if source_end-1 == lineno
              puts "s: #{source_end} index: #{index}"
            end
            @out.puts "\t\t</td>"
            writeInstruction [start_addr, pair[:assembly_lineno]]
            @out.puts "\t</tr>"

            # update
            puts "test last difffile"
            last_source_block[0] = last_source_block[1]+1
            last_source_block[1] = pair[:source_lineno]
            p last_source_block
            last_diff_file = nil
            start_addr = pair[:assembly_lineno]

          # Last iteration is ET
          elsif last_end == true

            # update
            start_addr = pair[:assembly_lineno]
            last_source_block = [pair[:source_lineno], pair[:source_lineno]]

          # Address up and source up
          elsif pair[:assembly_lineno] > start_addr and
                pair[:source_lineno] > last_source_block[1]
            writeCode last_source_block, [start_addr, pair[:assembly_lineno]]

            # update
            start_addr = pair[:assembly_lineno]
            last_source_block[0] = last_source_block[1]+1
            last_source_block[1] = pair[:source_lineno]

          # Address up and source down
          elsif pair[:assembly_lineno] > start_addr and
                pair[:source_lineno] < last_source_block[1]

            # no inline
            writeCode last_source_block, [start_addr, pair[:assembly_lineno]]

            # if inline

            # update
            start_addr = pair[:assembly_lineno]
            last_source_block = [pair[:source_lineno], pair[:source_lineno]]

          # Address up and source is the same
          # basically, this happens when the function is end
          elsif pair[:assembly_lineno] > start_addr and
                pair[:source_lineno] == last_source_block[1]
            writeCode last_source_block, [start_addr, pair[:assembly_lineno]], true

            # update
            last_source_block[0] = last_source_block[1]+1
            last_source_block[1] = pair[:source_lineno]
          
          # If addr is the same and source up
          elsif pair[:assembly_lineno] == start_addr and
                pair[:source_lineno] > last_source_block[1]
            # update
            last_source_block[1] = pair[:source_lineno]

          end # end state machine

          # Set end(ET) flag for next iteration
          if pair[:end].nil?
            last_end = false
          else
            last_end = true
          end
          p last_source_block
        end # end if
      end # end read
    end # end writeHtmlBody
end

test = HTMLWriter.new ARGV[0]
