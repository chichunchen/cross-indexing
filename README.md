# Cross-Indexing
Visualizing and cross referencing the source code of C and Assembly code as web pages with friendly UI.

## Features
- Translate all source code to corresponding html file
	- bar.c -> bar.c.html
	- foo.c -> foo.c.html
- The application works well on visualizing non-trivial applications such as [picoc](https://gitlab.com/zsaleeba/picoc), a C interpreter.
- Support all the optimization flag in gcc (O1, O2, O3, Os).

## How to run
```
make
ruby xref.rb a.out
```

## Result
- Referene C and Assembly using O3 flag
![](https://i.imgur.com/msh7wrq.png)
- Reference function from header
![](https://i.imgur.com/iNeEPor.png)
- Result of referencing [picoc](https://gitlab.com/zsaleeba/picoc)
	- When testing with `picoc`, we can jump to different .html files by clicking links if the called function is declared in another file.
![](https://i.imgur.com/ZUAuxQJ.png)
	- Content of one of the file 
![](https://i.imgur.com/hvKKq7W.png)

## TODO
    - [X] objdump, dwarfdump information extraction
    - [X] Convert the source code to HTML, with side-by-side assembly and source, and with embedded branch-target links. 
    - [X] Place the HTML file(s) into a subdirectory named HTML, with an extra file index.html that contains a link to the main HTML file(s), a location-specific link to the beginning of the code for main, and information about when and where the xref tool was run. 
    - [X] About "assembly centric": display assembly-language instructions, in **address order**, and show **next to** them the corresponding source.
    - [X] Subtles: `-O2`, `-O3` cases testing; static function with same name in different files.
    - [ ] About beautifying: the source line may appear more than once on your web page.  For the sake of clarity, you should print the second and subsequent occurrences in a **grayed-out color**. **Vertical white space** should be inserted as needed to make the alignment work out.

## Docs

### dwarfdump.rb

- DwarfDecode class
    - Parses all the information we need in .debug_info and .debug_line
    - The picoc example is too large, and a single scan on the whole dwarfdump output costs too much time. So we divide them into several parts per filename.
    - @global_var : hash {filename => Variable instances} 
    - @line_info  : hash {filename => content}
        - each element of content is: hash {real_address => [lineno, "ET", uri's filename(str)]}
        - if not ET or no uri, the element is `nil`.
    - @functions  : hash {filename => Function instances}
    - @subroutine : has  {filename => Subroutine content}
        - each element of subroutine content is: {:local_addr => 0x.. :low_pc => 0x.., high_pc => dec, call_file => \*.c|h, call_line => 0x..}
    - @min_lno    : hash {filename => minimum lineno (int)}
    - @intervals  : hash {filename => [low_addr(int), high_addr(int)]}
        - There are some lineno that cannot be matched. So store address instead and judge the range of address.
    - @lexical    : hash {filename => {lowpc => highpc}} 
    - @lexical_rev: hash {filename => {highpc => lowpc}}
        - These two give us reference for jumps in loops
    - @name2file  : hash {function name => filename}
        - Static functions are recognized and not stored here
        - This can help eniminate useless href links.

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
        - last one is base_type name, such as "int", "char"
        - second last is "base"
        - others are like "array", "pointer", "const".

- dig_type(adress, whole_code)
    - This function recursively generates the name of a type, given the local address.
    - Currently support all base types, pointer, array, and other types with format `/DW_TAG_[a-z]+_type/`
    - Get stuck when faced with `typedef`, so in our testing, we just leave an empty dig_type function.


### objump.rb
- This file define a `Objdump` class
	- Take the file name of executable as parameter
	- Private class in `Objdump` class
		- Instruction
			- Attributes
				- address
				- assembly code
				- name of function
			- `Objdump` can use all of the attributes in `Instruction` class
	- Expose `functions`, `instructsions`, and `instructions_hash` for read-only.
		- functions
			- hash
				- key: name of the function in objdump
				- value:
					- A list of `Instruction` object.
		- instructions
			- An array of instructions
				- Each element contains address of the instruction and code of the instruction
			- The array is for driving the assembly-centric output using `sort_by `
				- `@instructions.sort_by! { |obj| obj[:addr] }`
		- instructions_hash
			- key
				- Address of instruction
			- value
				- `{ :code => assebmly_code, :func => name_of_function }`
	- Methods
		- getInstructionsByRange(start_addr, end_addr)
			- return an array of instructions window that contains all the instructions from start_addr to end_addr-1
			- This method is mostly used by printing instructions in `xref.rb`

### xref.rb
- This file define a `CrossIndex` class, which is also the driver of A4.
	- Public Methods:
		- sourceToHTML
			- If HTML folder does not exists
				- create a HTML folder
			- If HTML folder exists
				- rm -rf HTML
				- create a new HTML folder
			- Produce all web pages and put all of them into HTML/
			- Produce index.html into HTML/
	- Nontrivial private Methods:
		- writeSource
			- Write C source into web page using a range of source line number.
			- endFlag
				- Decide whether print out the remaing instruction.
			- repeatFlag
				- Grey the c source block if repeatFlag is set.
		- writeInstruction
			- Write instruction to web page using given start and end assembly address
			- Use endFlag to deal with outputing the remaining instructions in the function that the address in range[0]. 
			- If the instruction contains fixed address, then output its link
		- writeHTMLBody
			- Print the whole source and assembly with assembly centric
		- htmlEncoding
			- Escape `&, <, >`
