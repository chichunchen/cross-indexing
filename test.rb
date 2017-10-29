### Only printed results.
### Shared parts can be matched using (?=x)

def extract_blocks(code, scope_no)
    # lexical = code.scan(/#{scope_no}><0x\w+>\s*DW_TAG_lexical_block\s*DW_AT_low_pc\s*(\w+$)\s*DW_AT_high_pc\s*<offset.from.lowpc>(\d+)$(.*?)(< (?=[1-#{scope_no}])|\z)/m)
 
    # The format under DW_TAG_lexical_block varies. Don't know what they mean yet.
    lexical = code.scan(/#{scope_no}><0x\w+>\s*DW_TAG_lexical_block(.*?)(< (?=[1-#{scope_no}])|\z)/m)
    
    ### Up there, the [1-#{scope_no}] may not capture numbers of two digits
    ### However, there rarely exists any program with so many levels of scopes.
    ### Just optimize it later.

    if lexical.size == 0 
        # no more deeper level scopes
        return
    end
    lexical.each do |scope|
        vars = scope[0].scan(/< #{scope_no + 1}><(\w+)>\s*DW_TAG_variable\s*DW_AT_name\s*(\w*$)\s*DW_AT_decl_file.*?$\s*DW_AT_decl_line\s*(\w*$)\s*DW_AT_type\s*<(\w*)>/)
        puts "#{"  " * (scope_no - 1)}var of lexical (level #{scope_no + 1}): #{vars}"
        extract_blocks(scope[0], scope_no + 1)

    end
end



dwarfdump = %x{ ~cs254/bin/dwarfdump #{ARGV[0]} }
debug_info = dwarfdump.scan(/COMPILE_UNIT.+?DW_AT_language.+?$\s*DW_AT_name\s*(.+?$).+?LOCAL_SYMBOLS(.+?)\.debug_line/m)

debug_info.each do |file|
    
    puts "--------"
    puts file[0] 
    puts "--------"
    
    file_name = file[0].split('.')[0]

    base_type = file[1].scan(/<(\w+)>\s*DW_TAG_base_type.*?DW_AT_name\s*?(\w.*?$)/m)
    puts "base_type: #{base_type}"
    
    global_var = file[1].scan(/< 1><(\w+)>\s*DW_TAG_variable\s*DW_AT_name\s*(\w*$)\s*DW_AT_decl_file.*?#{file_name}\.(c|h)\s*DW_AT_decl_line\s*(\w*$)\s*DW_AT_type\s*<(\w*)>/)
    puts "global_var: #{global_var}"
    
    func_blocks = file[1].scan(/<(\w+)>\s*DW_TAG_subprogram.*?DW_AT_name\s*(\w*$)(.*?)(< 1>|\z)/m)
    # function level
    func_blocks.each do |block|
        puts ""
        puts block[1] # names of function
        
        # recursively dig into lexical blocks (scopes)
        extract_blocks(block[2], 2)
        
        # parameters of the function.
        params = block[2].scan(/< 2><(\w+)>\s*DW_TAG_formal_parameter\s*DW_AT_name\s*(\w*$)\s*DW_AT_decl_file.*?$\s*DW_AT_decl_line\s*(\w*$)\s*DW_AT_type\s*<(\w*)>/)
        # vars = block[2].scan(/< (\d+)><(\w+)>\s*DW_TAG_variable\s*DW_AT_name\s*(\w*$)\s*DW_AT_decl_file.*?$\s*DW_AT_decl_line\s*(\w*$)\s*DW_AT_type\s*<(\w*)>/)
        puts "params: #{params}"
    end
end
