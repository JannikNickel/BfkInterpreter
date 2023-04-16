# BFK Interpreter
A brainfuck interpreter written in x64 NASM assembly for Linux.

## Build
### Either run the build script:

`./build.sh` to build and link a linux command line application in the 'bin/' directory.

Optionally, pass the `--dbg` flag to the build script to include debug information. 

### Or assemble and link the code yourself:
```
nasm -f elf64 -o bin/bfkint.o interpreter.asm
ld -m elf_x86_64 -o bin/bfkint bin/bfkint.o
```

## Usage
Run `./bin/bfkint file` to interpret the brainfuck code in a `file`.

Alternatively, the `./build_run file` script can be used to build the interpreter and then interpret the `file`.

*Input/output works through the interactively through the terminal.*

## Technical
This interpreter uses 32768 memory cells by default, which can be modified by changing the value of `%define CELLS` line at the top of the [interpreter.asm](interpreter.asm) file. At the beginning, the memory ptr points to cell 0. Negative cells and `cells >= 32768` are not allowed and will most likely result in a crash of the interpreter or undefined behaviour.

Each cell has a size of 1 unsigned byte. Values wrap around when decrementing 0 or incrementing 255.

The program ends when the interpreter reaches the end of the code file. There is no output when this happens and the program ends with exit code 0.

The interpreter detects and outputs the following errors:
- Invalid cmd argument(s)
- Code file doesnt exist or could not be opened
- `'['` or `']'` mismatch

Only the 8 brainfuck instruction characters `'>', '<', '+', '-', '.', ',', '[', ']'` are interpreted, everything else counts as comment.

## Examples
The [examples/](/examples) directory contains some basic example scripts to test the interpreter.
Attributions to the original authors are inside each file if required.

## License
The code is released under the MIT license. See [LICENSE](LICENSE).
See the section above for license information for the examples.

## Brainfuck
A brainfuck program consists of 8 instructions and can access an array of at least 30000 memory cells which usually hold 8 bit and move a pointer to a cell in memory.

| Instruction | Description |
| ----------- | ----------- |
| >           | Move the ptr right |
| <           | Move the ptr left  |
| +           | Increment the memory cell at the ptr |
| -           | Decrement the memory cell at the ptr |
| .           | Output the memory cell at the ptr as character |
| ,           | Input a character and save it in the memory cell at the ptr | 
| [           | If the cell at the ptr is 0, jump past the matching ] |
| ]           | If the cell at the ptr is not 0, jump to the matching [ |
