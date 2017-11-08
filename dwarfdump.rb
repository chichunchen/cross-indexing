
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


# Cannot capture typedef, enumerate, etc. "static" info cannot be found anywhere.

class Variable
    attr_reader :local_addr, :name, :decl_file, :lineno, :type

    def initialize(var, whole_code)
        @local_addr = var[0]
        @name       = var[1]
        @decl_file  = var[2]
        @lineno     = var[3]
        @type       = dig_type(var[4], whole_code).flatten
    end
end


class Function
    attr_reader :local_addr, :type, :name, :low_pc, :high_pc, :params, :inner_var
    
    def initialize(block, whole_code)
        @local_addr = block[0]
        
        # Here is all about type
        if (/yes/ =~ block[1]).nil?
            @type = ["static"]
        else
            @type = []
        end
        if (/DW_AT_type/ =~ block[5]).nil?
            @type << "void"
        else
            type_addr = block[5].scan(/<(.+?)>/)[0][0]
            @type.concat(dig_type(type_addr, whole_code).flatten)
        end


        @name       = block[2]
        @decl_file  = block[3]
        @lineno     = block[4]
        @low_pc     = block[6]
        @high_pc    = block[7]
        @params     = block[8].scan(/< 2><(\w+)>\s*DW_TAG_formal_parameter\s*DW_AT_name\s*(\w*$)\s*DW_AT_decl_file.*?\/([^\/]+?)\s*DW_AT_decl_line\s*(\w*$)\s*DW_AT_type\s*<(\w*)>/)
        @params.map! { |var|
            Variable.new(var, whole_code)
        }
        @inner_var  = extract_blocks(block[8], 2, whole_code)
    end

    # The format is like:
    # [..., [[...], [...]], [..., [..., [...]]]] 
    # Each [] is like a {} in C code, the sequence is the same as in the C code.
    def extract_blocks(code, scope_no, whole_code)
        res = code.scan(/< #{scope_no}><(\w+)>\s*DW_TAG_variable\s*DW_AT_name\s*(\w*$)\s*DW_AT_decl_file.*?\/([^\/]+?)\s*DW_AT_decl_line\s*(\w*$)\s*DW_AT_type\s*<(\w*)>/)
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
            vars = scope[0].scan(/< #{scope_no + 1}><(\w+)>\s*DW_TAG_variable\s*DW_AT_name\s*(\w*$)\s*DW_AT_decl_file.*?\/([^\/]+?)\s*DW_AT_decl_line\s*(\w*$)\s*DW_AT_type\s*<(\w*)>/)
            vars.map! { |var|
                Variable.new(var, whole_code)
            }
            res << vars
            res << extract_blocks(scope[0], scope_no + 1, whole_code)
    
        end

        return res
    end
end


class DwarfDecode
    attr_reader :global_var, :line_info, :functions, :subroutine

    def initialize(src_file)
        # each element is: [file_name, debug_info_content, debug_line_content]
        output = %x{ ~cs254/bin/dwarfdump #{src_file} }
        @global_var = {}
        @line_info  = {}      # for drive instructions
        @functions  = {}
        @subroutine = {}

        debug_info = output.scan(/COMPILE_UNIT.+?DW_AT_language.+?$\s*DW_AT_name\s*(.+?$).+?LOCAL_SYMBOLS(.+?)\.debug_line(.+?)\.debug_macro/m)
        debug_info.each do |file|
            
            file_name = file[0] # .split('.')[0]
           
            # What files this .c file has included (including itself)
            used_file = file[2].scan(/\/([^\/]+?\..)/).uniq

            @global_var[file_name] = []
            @functions[file_name] = []
            @subroutine[file_name] = []
            used_file.each do |each_file|
                # each element is: [local_address, check_if_static, name, decl_file, decl_line, type_check_info, low_pc, high_pc, function_content, (unimportant thing)]
                tmp_func = file[1].scan(/<(\w+)>\s*DW_TAG_subprogram(.*?)DW_AT_name\s*(\w+$)\s*DW_AT_decl_file.*?(#{each_file[0]})\s*DW_AT_decl_line\s*(\w*$)\s*(.*?)DW_AT_low_pc\s*(\w+$)\s*DW_AT_high_pc\s*<offset-from-lowpc>(\d+$)(.*?)(< 1>|\z)/m)
                
                # each element is: [local_address, name, decl_file_name, lineno(hex), type(address)]
                tmp_var = file[1].scan(/< 1><(\w+)>\s*DW_TAG_variable\s*DW_AT_name\s*(\w*$)\s*DW_AT_decl_file.*?(#{each_file[0]})\s*DW_AT_decl_line\s*(\w*$)\s*DW_AT_type\s*<(\w*)>/)

                # each element is: [local_addr_refer_to_name, low_pc, high_pc, call_file, call_line(hex)]
                tmp_sub = file[1].scan(/DW_TAG_inlined_subroutine\s*DW_AT_abstract_origin\s*<(\w+)>\s*DW_AT_low_pc\s*(\w+$)\s*DW_AT_high_pc\s*<offset-from-lowpc>(\d+)\s*DW_AT_call_file.*?\/([^\/]+?..)\s*DW_AT_call_line\s*(\w+)/)
                @global_var[file_name].concat(tmp_var)
                @functions[file_name].concat(tmp_func)
                @subroutine[file_name].concat(tmp_sub)

            end

            @subroutine[file_name] = @subroutine[file_name].uniq

            @global_var[file_name].map! { |var|
                Variable.new(var, file[1])
            }
        
            @functions[file_name].map! { |block|
                Function.new(block, file[1])
            }
           
            # each element is: [real_address, lineno, uri or ET msg]
            sourcelineAndAssembly = file[2].scan(/(0x\w+)\s*\[\s*(\d+),.+?NS(.*$)/)
            @line_info[file_name] = sourcelineAndAssembly
            @line_info[file_name].map! { |tuple|
                [tuple[0].to_i(16), [tuple[1].to_i, tuple[2].scan(/ET/)[0], tuple[2].scan(/[^\/]+?\../)[0]]]
            }
        end
    end
end    

debug = DwarfDecode.new "#{ARGV[0]}"
# p debug.subroutine
