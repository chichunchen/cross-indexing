# Cross-Indexing
http://www.cs.rochester.edu/courses/254/fall2017/assignments/xref.shtml

- TODO
    - [X] objdump, dwarfdump information extraction
    - [X] Convert the source code to HTML, with side-by-side assembly and source, and with embedded branch-target links. 
    - [ ] Place the HTML file(s) into a subdirectory named HTML, with an extra file index.html that contains a link to the main HTML file(s), a location-specific link to the beginning of the code for main, and information about when and where the xref tool was run. 
    - [ ] About "assembly centric": display assembly-language instructions, in **address order**, and show **next to** them the corresponding source.
    - [ ] About beautifying: the source line may appear more than once on your web page.  For the sake of clarity, you should print the second and subsequent occurrences in a **grayed-out color**. **Vertical white space** should be inserted as needed to make the alignment work out.
    - [ ] Subtles: `-O2`, `-O3` cases testing; static function with same name in different files.
    - [ ] HTMLWriter optimization


- dwarfdump information
    
    - Cannot capture typedef, enumerate, etc. "static" info cannot be found anywhere in the dump information.

    - DwarfDecode class
        - @global_var : hash {filename => Variable instances} 
        - @line_info  : hash {filename => content}
            - each element of content is: hash {lineno => real_address}
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
        - @decl_file  : the whole filename where the variable is declared.
        - @lineno     : hex value of line number
        - @type       : list of type names
            - last one is base_type name
            - second last is "base"
            - others are like "array", "pointer", "const".
