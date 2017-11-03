
# Cannot capture typedef, enumerate, etc. "static" info cannot be found anywhere.

class Variable
    def initialize(var, whole_code)
        @local_addr = var[0]
        @name       = var[1]
        @extension  = var[2]
        @lineno     = var[3]
        @type       = dig_type(var[4], whole_code).flatten
    end
    
    # This function recursively dig into the type information of a variable.
    # Returns [type of type(base, pointer, const, array); type_name]
    def dig_type(address, whole_code)
        res = []
        type_info = whole_code.scan(/<#{address}>\s*DW_TAG_([a-zA-Z]+)_type/)
        # If the size of res is 0, then find for typedef. Implement later
        res << type_info[0][0] 
        
        if res[0] == "base"
            tmp = whole_code.scan(/<#{address}>\s*DW_TAG_base_type.*?DW_AT_name\s*?(\w.*?$)/m)
            res << tmp[0][0]
        else
            tmp = whole_code.scan(/<#{address}>\s*DW_TAG_#{res[0]}_type.*?DW_AT_type\s*<(\w+)>/m)
            res << dig_type(tmp[0][0], whole_code)
        end
    
        return res
    
    end
    
    attr_reader :local_addr, :name, :extension, :lineno, :type
end


class Function
    def initialize(block, whole_code)
        @local_addr = block[0]
        @name       = block[1]
        @params     = block[2].scan(/< 2><(\w+)>\s*DW_TAG_formal_parameter\s*DW_AT_name\s*(\w*$)\s*DW_AT_decl_file.*?\.(c|h)$\s*DW_AT_decl_line\s*(\w*$)\s*DW_AT_type\s*<(\w*)>/)
        @params.map! { |var|
            Variable.new(var, whole_code)
        }
        @inner_var  = extract_blocks(block[2], 2, whole_code)
    end

    # The format is like:
    # [..., [[...], [...]], [..., [..., [...]]]] 
    # Each [] is like a {} in C code, the sequence is the same as in the C code.
    def extract_blocks(code, scope_no, whole_code)
        res = code.scan(/< #{scope_no}><(\w+)>\s*DW_TAG_variable\s*DW_AT_name\s*(\w*$)\s*DW_AT_decl_file.*?\.(c|h)\s*DW_AT_decl_line\s*(\w*$)\s*DW_AT_type\s*<(\w*)>/)
        res.map! { |var|
            Variable.new(var, whole_code)
        } 

        # lexical = code.scan(/#{scope_no}><0x\w+>\s*DW_TAG_lexical_block\s*DW_AT_low_pc\s*(\w+$)\s*DW_AT_high_pc\s*<offset.from.lowpc>(\d+)$(.*?)(< (?=[1-#{scope_no}])|\z)/m)
        # The format under DW_TAG_lexical_block varies. Don't know what they mean yet.
        
        # each element is: [scope_content] (doesn't matter)
        lexical = code.scan(/#{scope_no}><0x\w+>\s*DW_TAG_lexical_block(.*?)(< (?=[1-#{scope_no}])|\z)/m)
        
        ### Up there, the [1-#{scope_no}] may not capture numbers of two digits
        ### However, there rarely exists any program with so many levels of scopes.
        ### Just optimize it later.
    
        if lexical.size == 0 
            # no more deeper level scopes
            return res
        end
        lexical.each do |scope|
            # each element is: [local_address, variable_name, lineno(hex), type(address)]
            vars = scope[0].scan(/< #{scope_no + 1}><(\w+)>\s*DW_TAG_variable\s*DW_AT_name\s*(\w*$)\s*DW_AT_decl_file.*?\.(c|h)$\s*DW_AT_decl_line\s*(\w*$)\s*DW_AT_type\s*<(\w*)>/)
            vars.map! { |var|
                Variable.new(var, whole_code)
            }
            res << vars
            res << extract_blocks(scope[0], scope_no + 1, whole_code)
    
        end

        return res
    end

    attr_reader :local_addr, :name, :params, :inner_var
end


class DwarfDecode
    def initialize(output)
        # each element is: [file_name, debug_info_content, debug_line_content]
        
        dwarfdump = %x{ ~cs254/bin/dwarfdump #{output} }

        @global_var = Hash.new
        @line_info  = Hash.new
        @functions  = Hash.new

        debug_info = dwarfdump.scan(/COMPILE_UNIT.+?DW_AT_language.+?$\s*DW_AT_name\s*(.+?$).+?LOCAL_SYMBOLS(.+?)\.debug_line(.+?)\.debug_macro/m)
        debug_info.each do |file|
            
            file_name = file[0].split('.')[0]
            
            # each element is: [local_address, name, extension(.c or .h), lineno(hex), type(address)]
            @global_var[file_name] = file[1].scan(/< 1><(\w+)>\s*DW_TAG_variable\s*DW_AT_name\s*(\w*$)\s*DW_AT_decl_file.*?#{file_name}\.(c|h)\s*DW_AT_decl_line\s*(\w*$)\s*DW_AT_type\s*<(\w*)>/)
            @global_var[file_name].map! { |var|
                Variable.new(var, file[1])
            }
        
            # each element is: [local_address, name, function_content, (unimportant thing)]
            @functions[file_name] = file[1].scan(/<(\w+)>\s*DW_TAG_subprogram.*?DW_AT_name\s*(\w*$)(.*?)(< 1>|\z)/m)
            @functions[file_name].map! { |block|
                Function.new(block, file[1])
            }
           
            # each element is: [real_address, lineno]
            @line_info[file_name] = file[2].scan(/(0x\w+)\s*\[\s*(\d+),/)
            @line_info[file_name].map! { |tuple|
                [tuple[-1].to_i, tuple[0]]                
            }
            @line_info[file_name] = @line_info[file_name].to_h
        end

    end

    attr_reader :global_var, :line_info, :functions
    
end    

debug = DwarfDecode.new("a.out")
puts debug.line_info
