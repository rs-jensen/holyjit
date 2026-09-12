# holyjit

A tiny JIT compiler written in HolyC. It compiles a small language straight into x86-64 machine code at runtime and runs it.

## Language

- variables: single lowercase letters, a to z
- assignment: `x = 5`
- arithmetic: `+ - * /`
- comparisons: `< > ==`
- loops: `while (cond) { ... }`
- output: `print expr`

Example:

```
a=1;i=1;while(i<11){a=a*i;print a;i=i+1}
```

This prints the running factorial from 1 to 10.

## How it works

The compiler is a recursive descent parser. Instead of building a syntax tree it writes raw x86-64 bytes into a buffer while it parses, the same way Terry Davis wrote the original HolyC compiler.

Numbers are loaded with `mov`. Arithmetic uses `push`/`pop` to combine operands, then `add`, `sub`, `imul`, or `idiv`. Comparisons use `cmp` and `setcc`. A `while` loop emits a conditional jump with a placeholder offset, compiles the loop body, then patches the jump once the body length is known.

Variables are stored in an array of 26 `I64` values on the host side. A pointer to that array is passed into the generated code through `RDI`, following the normal calling convention, so the JIT code and the host program agree on where each variable lives.

`print` calls back into HolyC from inside the generated code. It loads the address of a small host function into a register and calls it directly, using the same stack and calling convention as the rest of the program.

## Running

Load `jit.HC` in TempleOS and run it. `Main` runs three example programs: a factorial loop, a variable test, and a fibonacci loop.
