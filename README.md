#  MiniScript

MiniScript is an extremely simple and ultra-lightweight scripting language with a BASIC-like syntax, written in Swift. It supports:

    - Basic logic & control flow (if/else/end, while loops)
    - Local & global (cross-script) variables
    - Integer & floating-point math, and strings
    - String interpolation
    - Super-easy bridging to Swift code, via custom commands. This gives you access to the full Swift standard library (as well as UIKit / AppKit, etc.)

## What's it for?

MiniScript is ideal for game engines or applications written in Swift, which need to support simple runtime / user scripting, and bridging to your compiled Swift code.

Typically, most Swift apps that need such functionality are required to import rather massive language libraries like Lua, and then deal with the relative complexity of trying to bind your Swift code to custom commands that can be used in the scripts. Or in other cases apps might require that some specific third-party language (Python, Ruby, etc.) is already installed on user's machines. 

MiniScript is designed to be an extremely simple alternative to this.

## Why MiniScript?

- The entire MiniScript engine is contained in a single Swift file. Just drop it into your project and you're ready to go.
- Runing a script can be done in a single line of code. The API is this easy: `MiniScriptEngine().run(MiniScript(source: "print(Hello world!)"))`
- MiniScript is designed to be ultra-easy to bridge with your existing Swift code. For an example of how ridiculously simple it is to connect MiniScript commands to your compiled Swift code, see **Command Hooks** below.

## Why _Not_ MiniScript?

MiniScript is very limited at the moment. And frankly, some stuff isn't really implemented correctly (see the ToDo section below). Language parsing not my area of expertise and so the code could certainly be improved. For supporting basic scripting in a hobbyist app it may suit your needs, though for anything beyond that you'll probably run into walls (or bugs) fairly quickly.

Despite this, I've open sourced it since its basic features work reliably and are functional enough to possibly be of use. Also, there are a few unit tests already added to assure you of the stability of the basic language features.

# Getting Started

Step 1. Drop the MiniScript.swift file into your Xcode project
Step 2. You're done.

## Running a Script

To run a script, create a `MiniScript` instance from the script source. Then create an instance of `MiniScriptEngine` and call its `run()` command. That's it!

Example:
```
let engine = MiniScriptEngine()
let script = MiniScript(source: "print(Hello world!)")
let result = engine.run()

// RESULT: Hello world!
```

# Reference

## Syntax

Line breaks are used to separate individual commands or expressions. Commands and keywords are separated by a space. Here's an example of a simple MiniScript:

```
// Variables

$a = "Matt"
$x = 5
$yourFavNumber = 20

// Math

$n = 2 * $x

// String interpolation

print("{{$a}}'s favorite number is {{$n}}.")

// Logic

if $n < $yourFavNumber
    $combined = "That's less than your favorite number: " + $yourFavNumber
    print($combined)
else
    print("Your favorite number is bigger (or equal).")
end

// Simple commands

$randomNumber = rand(10)
if $randomNumber < 5
    print("{{$randomNumber}} is less than 5.")
else
    print("{{$randomNumber}} is more than 5!")
end

```

## Command Hooks: Bridging to Swift

One of the key features of MiniScript is that it is designed for scripts to be powered by your existing compiled Swift code. This means you can easily define custom commands, and when used in a script the engine will call into your Swift code to do whatever you want.

This allows MiniScripts to do **just about anything**: manipulate images, fetch web or HTTP resources, edit system files or data stores, etc.

Here is an example of how to add a custom command, use that command in a MiniScript, and then execute some Swift code as a result:

```swift
let engine = MiniScriptEngine()
engine.addCommand("myCustomCommand") { args -> String? in
    if args[0] == "is cool" {
        return "I agree!"
    }
    return nil
}
```

After configuring our command (`miniScript()`), any scripts we run can make use of this command to run our arbitrary Swift code we supplied in the block.

So if we then run a simple script:

```swift
let output = engine.run(MiniScript(source: "$a = myCustomCommand(is cool)  \n  print($a)"))
```

**The output is**:
```
I agree!
```

Any number of arbitrary commands can be added to MiniScript. The language comes with some built-in commands (like `print`), but these can be overridden if desired.

## Quick Reference Guide

### Variables

Variables in MiniScript can either be local to the script instance, or global to all scripts run by a specific `MiniScriptEngine` instance. Local variables are prefixed by `$` and globals by `&`. 

You can also "inject" variables before running a script by passing them into the `environment` as part of the `run` command. This allows your engine to expose any arbitrary data from your Swift application to your scripts. Games, for example, can pass in information about the current game object or game state, which scripts can then access like normal variables.

Internally, MiniScript variables are always stored as strings, however their treatment when used with MiniScript operators can be either as strings, integers, or floating point numbers depending on their content. Variables with only numeric characters are generally treated as numbers.

### Comments

Lines prefixed by `//` are ignored.

### Strings and Printing

Strings can be passed to commands as whole words, or wrapped in quotes (`"…"`) to include whitespace. Quotes can be used within strings by escaping them with backslashes, for example:

```
print("The man said \"hi\".")

// OUTPUT: The main said "hi".
```

### Operators

Basic arithmetic operators (`+`, `-`, `/`, `*` etc) can be used on all floating point or integer variables. Some operators like + can also be used on strings, for e.g. concatenation.

Standard comparators are also available: `>`, `<`, `>=`, `<=`. Equality is checked using `=`.

### String Interpolation

MiniScript supports basic string interpolation. This means expressions can be evaluated within strings.

In MiniScript, you can include expressions between `{{` and `}}`. Here is an example:

(If you need to use `{{` in your strings you can escape them: `\{\{`.)

```swift
        let script =
"""
$a = "red"
$b = "balloon"
print("Today at the zoo I bought a {{$a}} {{$b}}.")
"""

MiniScriptEngine().run(MiniScript(source: script))
```

**Output:**
`Today at the zoo I bought a red balloon.`

### Commands

For a list of built-in commands please see the `MiniScriptDefaultCommand` enum in the source.

Because custom commands can be added so easily to tap the Swift standard library, MiniScript has very few commands built-in. In general, for anything you need, you can create a command hook to perform the necessary Swift code.

### Print Shorthand Syntax

MiniScript was originally designed to be used to drive a text-heavy game engine. For this reason, it provides a shorthand for printing text.

You can print text simply by prefixing a line with two backticks. Internally, MiniScript simply replaces the backticks with a `print` command.

This code:

```
``This is a string! It has \"escaped quotes \". It will be printed!
```

will be converted to:

```
print("This is a string! It has \"escaped quotes \". It will be printed!")
```

## MiniScript Examples

For a few simple examples of logic, math, and string usage, please take a look at the included unit tests.

## Major ToDo's

There are a _lot_ of big pieces missing. MinScript at this stage is mostly an MVP / proof-of-concept for very basic scripting needs, though for things like simple game engine scripting it may be adequate (currently I'm using it in a hobby game project I'm developing).

- Fix operator precedence and order of operations for math expressions
- Support nested and recursive function calls (`command(command())`)
- Provide syntax checker and warnings
- Improved math and string utilities
- Performance tuning
- Additional control and logic statements
- Syntax checker and detailed error output
- Better documentation (if anyone actually wants to use MiniScript, email me and I'll try to expand on this README...)
