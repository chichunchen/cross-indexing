# Cross-Indexing

- dwarfdump information
    
    - Cannot capture typedef, enumerate, etc. "static" info cannot be found anywhere in the dump information.

    - DwarfDecode class
        - @global_var : hash {filename => Variable instances} 
        - @line_info  : hash {filename => content}
            - each element of content is: [real_address, lineno]
        - @functions  : hash {filename => Function instances}

    - Function class
        - @local_addr : 0x????????
        - @name
        - @params : list of Variable
        - @inner_var
            - The format is like: [..., [[...], [...]], [..., [..., [...]]]].
            - Each [] is like a {} in C code, the sequence is the same as in the C code.
            - Stored elements are Variable instances.
    
    - Variable class
        - @local_addr : 0x????????
        - @name
        - @extension  : the file extension name. Can make it whole filename here.
        - @lineno     : hex value of line number
        - @type       : list of type names
            - last one is base_type name
            - second last is "base"
            - others are like "array", "pointer", "const".
