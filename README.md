# Cross-Indexing
http://www.cs.rochester.edu/courses/254/fall2017/assignments/xref.shtml

- TODO
    - [X] objdump, dwarfdump information extraction
    - [X] Convert the source code to HTML, with side-by-side assembly and source, and with embedded branch-target links. 
    - [X] Place the HTML file(s) into a subdirectory named HTML, with an extra file index.html that contains a link to the main HTML file(s), a location-specific link to the beginning of the code for main, and information about when and where the xref tool was run. 
    - [X] About "assembly centric": display assembly-language instructions, in **address order**, and show **next to** them the corresponding source.
    - [ ] About beautifying: the source line may appear more than once on your web page.  For the sake of clarity, you should print the second and subsequent occurrences in a **grayed-out color**. **Vertical white space** should be inserted as needed to make the alignment work out.
    - [ ] Subtles: `-O2`, `-O3` cases testing; static function with same name in different files.

- dwarfdump information
    
    - Cannot capture typedef, enumerate, etc. "static" info cannot be found anywhere in the dump information.

    - DwarfDecode class
        - @global_var : hash {filename => Variable instances} 
        - @line_info  : hash {filename => content}
            - each element of content is: hash {real_address => [lineno, "ET", uri's filename(str)]}
            - if not ET or no uri, the element is `nil`.
        - @functions  : hash {filename => Function instances}
        - @subroutine : has  {filename => Subroutine content}
            - each element of subroutine content is: {:local_addr => 0x.. :low_pc => 0x.., high_pc => dec, call_file => *.c|h, call_line => 0x..}
        - @min_lno    : hash {filename => minimum lineno (int)}
        - @intervals  : hash {filename => [low_addr(int), high_addr(int)]}
            - There are some lineno that cannot be matched. So store address instead and judge the range of address.

    - Function class
        - @local_addr : 0x????????
        - @type       : including void, static, etc
        - @decl_file
        - @lineno
        - @low_pc     : real address(hex) that matches objdump info.
        - @high_pc    : a dec number to be added to low_pc
        - @name
        - @params     : list of Variable
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
