# pf-runner polyglot languages (native-linux)

The `shell` verb now supports many languages via inline `lang:` or task-wide `shell_lang`.

## Supported languages

- bash, sh, dash, zsh, fish, ksh, tcsh, pwsh
- python, node, typescript, tsx, deno, ts-node, perl, php, ruby, r, julia, haskell, ocaml, elixir, dart, lua
- go, rust, c, cpp, fortran, asm, zig, nim, crystal, haskell-compile, ocamlc
- java-openjdk, java-android

## Runtime resolution

The runner writes inline snippets to a temporary file and then executes them with
the selected runtime. For the common interpreted languages it now checks that a
runtime starts successfully before using it:

- `python`, `py`, `python3`: tries `python3`, then `python`
- `bash`: tries `bash`
- `fish`: tries `fish`
- `perl`, `pl`: tries `perl`
- `javascript`, `js`, `node`: tries `node`, then `nodejs`, then `bun`
- `typescript`, `ts`: tries local `./node_modules/.bin/tsx`, global `tsx`, local `ts-node`, global `ts-node`, `deno run`, then `bun`
- `tsx`: tries local `./node_modules/.bin/tsx`, then global `tsx`
- `ts-node`: tries local `./node_modules/.bin/ts-node`, then global `ts-node`

This catches cases where a command exists on `PATH` but cannot start, then falls
through to the next compatible runtime. If no runtime works, pf prints the list
of candidates it tried.

## Optional dependencies

Minimal pf execution requires Python. Additional language support requires the
corresponding runtime to be installed:

- Bash: `bash`
- Fish: `fish`
- Perl: `perl`
- JavaScript: `nodejs` or `bun`
- TypeScript: `tsx`, `ts-node`, `deno`, or `bun`; for local project installs,
  add `tsx` and `typescript` to the project dependencies.

## LLVM IR Output

- c-llvm, cpp-llvm, fortran-llvm - Generate LLVM IR (text format)
- c-llvm-bc, cpp-llvm-bc - Generate LLVM bitcode and disassemble to IR

## Aliases

See README section "Polyglot languages (native-linux target)" for full alias list.

LLVM aliases:
- c-ir, c-ll → c-llvm
- cpp-ir, cpp-ll → cpp-llvm
- c-bc → c-llvm-bc
- cpp-bc → cpp-llvm-bc
- fortran-ll, fortran-ir → fortran-llvm

## Examples

```text
task demo
  shell [lang:bash] echo hello
  shell [lang:python] print("hi")
  shell [lang:javascript] console.log("yo")
  shell [lang:typescript] const msg: string = "typed"; console.log(msg)
  shell [lang:pwsh] Write-Output 'ok'
  shell [lang:c-llvm] int main() { return 42; }
end

task multi
  shell_lang python
  shell print("one")
  shell print("two")
  shell_lang default
  shell echo "back to default shell"
end
```
