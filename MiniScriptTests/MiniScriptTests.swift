//
//  MiniScriptTests.swift
//  MiniScriptTests
//
//  Created by Matthew Reagan on 7/15/20.
//  Copyright © 2020 Matt Reagan. All rights reserved.
//

import XCTest
import MiniScript

class MiniScriptTests: XCTestCase {
    
    func singleRun(_ script: String) -> String {
        return MiniScriptEngine().run(MiniScript(source: script))
    }

    func testBasicPrinting() throws {
        let script =
"""
print(1234)
print(Test)
print("Test")
print("Hello, world!")
"""
        let result =
"""
1234
Test
Test
Hello, world!
"""
        XCTAssertEqual(singleRun(script), result)
    }

    func testBasicIfElse() throws {
        
        let script =
"""
if true
    print(Pass1)
else
    print(Fail1)
end
if false
    print(Fail2)
else
    print(Pass2)
end
if true
    print(Pass3)
end
if false
    print(Fail4)
end
if false
    if true
        print(Fail5)
    else
        print(Fail6)
    end
end
if false
    if true
        print(Fail7)
    end
else
    if true
        print(Pass8)
    end
end
if true
    if true
        print(Pass9)
        if true
            if false
                print(Fail9)
            else
                print(Pass10)
            end
        else
            print(Fail11)
        end
    else
        print(Fail12)
    end
else
    print(Fail13)
end
if true
    if true
        print(Pass11)
        print(Pass12)
    end
end
"""
        let result =
"""
Pass1
Pass2
Pass3
Pass8
Pass9
Pass10
Pass11
Pass12
"""
        XCTAssertEqual(singleRun(script), result)
    }
    
    func testBasicMathExpressions() throws {
        let script =
"""
$a = 1 + 1
$b = 2 - 5
$c = $a + $b
print($c)

$a = 10
$c = $a * 5
print($c)
if c != 49
    print("Ok1")
end

$c = 5 / 10 * 3
print($c)
if $c > 1.2
    print("Ok2")
end
if $c < 2
    print("Ok3")
end

$c = 1 + 2 - 1 * 0.25
print($c)

$c = 2 / 6 * 9
print($c)
if $c = 3
    print("Ok4")
end
if $c != 42
    print("Ok5")
end
if $c >= 3
    print("Ok6")
end
if $c <= 2.99
    print("Fail")
else
    print("Ok7")
end

$c = 0.1283 + 8274.18 - 0.226
print($c)

if $c =
"""
        let result =
"""
-1
50
Ok1
1.5
Ok2
Ok3
0.5
3
Ok4
Ok5
Ok6
Ok7
8274.0823
"""
        XCTAssertEqual(singleRun(script), result)
    }
    
    func testBasicStringOperations() throws {
        let script =
"""
$a = "Hello "
$b = "world!"
$c = $a + $b
print($c)

if $a = "Hello "
    print("Ok1")
end
if $a != $b
    print("Ok2")
end
"""
        let result =
"""
Hello world!
Ok1
Ok2
"""
        XCTAssertEqual(singleRun(script), result)
    }
    
    func testStringInterpolationExpression() throws {
        let script =
"""
print("My favorite number is {{4 + 4 * 2}}.")
"""
        let result =
"""
My favorite number is 16.
"""
        XCTAssertEqual(singleRun(script), result)
    }
    
    func testEscapedQuoteStrings() throws {
        let script =
"""
print("The man said \\"hi\\".")
$hi = "more quotes! \\""
print("The man said \\"{{$hi}}\\".")
"""
        let result =
"""
The man said "hi".
The man said "more quotes! "".
"""
        XCTAssertEqual(singleRun(script), result)
    }
    
    func testPrintShorthandSyntax() throws {
        let script =
"""
``The man said \\"hi\\".
$hi = "more quotes! \\""
``The man said \\"{{$hi}}\\".
"""
        let result =
"""
The man said "hi".
The man said "more quotes! "".
"""
        XCTAssertEqual(singleRun(script), result)
    }
    
    func testStringInterpolation() throws {
        let script =
"""
$a = "red"
$b = "balloon"
print("{{sayHi(Matt, Reagan)}} Today at the zoo I bought a {{$a}} {{$b}}. It's a very bright {{$a}}! Please ignore these brackets: \\{\\{$a\\}\\}")
"""
        let result =
"""
Hi there, Matt Reagan! Today at the zoo I bought a red balloon. It's a very bright red! Please ignore these brackets: {{$a}}
"""
        let e = MiniScriptEngine()
        e.addCommand("sayHi") { args -> String? in
            return "Hi there, \(args[0]) \(args[1])!"
        }
        let out = e.run(MiniScript(source: script))
        XCTAssertEqual(out, result)
    }

    func testStringInterpolation2() throws {
        let script =
"""
$a = "red"
$space = " "
$b = "balloon"
print("Today at the {{join(Portland, Zoo)}} I bought a {{$a + $space + $b}}. It's very {{$a}}!")
"""
        let result =
        """
Today at the Portland Zoo I bought a red balloon. It's very red!
"""
        let e = MiniScriptEngine()
        e.addCommand("join") { args -> String? in
            return args[0] + " " + args[1]
        }
        let out = e.run(MiniScript(source: script))
        XCTAssertEqual(out, result)
    }
    
    func testWhileLoops() throws {
        let script =
"""
$a = 0
while $a < 10
    print("a: {{$a}}")
    $a = $a + 1
end
while $a < 20
    print("a: {{$a}}")
    $a = $a + 1
end

$a = 1
$b = 1
while $a < 100
    if true
        print("Looping!")
    else
        while $a < 100
            print("Nope")
        end
        print("Nope")
    end
    while $b < 10
        print("b: {{$b}}")
        $b = $b + 1
    end
    print("Finishing")
    $a = 101
end
$a = 0
while $a < 5
    $a = $a + 1
    while false
        print("No!")
    end
end
"""
        let result =
"""
a: 0
a: 1
a: 2
a: 3
a: 4
a: 5
a: 6
a: 7
a: 8
a: 9
a: 10
a: 11
a: 12
a: 13
a: 14
a: 15
a: 16
a: 17
a: 18
a: 19
Looping!
b: 1
b: 2
b: 3
b: 4
b: 5
b: 6
b: 7
b: 8
b: 9
Finishing
"""
        XCTAssertEqual(singleRun(script), result)
        }
    
    func testLocalVariables() throws {
        let script =
"""
$a = "hi "
$b = there
$c = " how are "
$d = "you today?"
$e = "!"
$part1 = $a + $b
$part2 = $c + $d + $e
$part3 = $part1 + $part2
print($part3)
"""
        let result =
"""
hi there how are you today?!
"""
        XCTAssertEqual(singleRun(script), result)
    }
    
    func testGlobalVariables() throws {
        let script1 =
"""
$a = 2
$b = $a * $a
&c = $b * 3
print($b)
print(&c)
"""
        let result1 =
"""
4
12
"""
        let script2 =
"""
if $b = ""
    print("B is empty as expected")
end
print(&c)
"""
        let result2 =
"""
B is empty as expected
12
"""
        let engine = MiniScriptEngine()
        
        let out1 = engine.run(MiniScript(source: script1))
        XCTAssertEqual(out1, result1)
        let out2 = engine.run(MiniScript(source: script2))
        XCTAssertEqual(out2, result2)
    }
    
    func testBadScripts() throws {
        XCTAssertEqual(singleRun("$a"), MiniScriptErrorResult)
        XCTAssertEqual(singleRun("+"), MiniScriptErrorResult)
        XCTAssertEqual(singleRun("if false"), MiniScriptErrorResult)
        XCTAssertEqual(singleRun("else"), MiniScriptErrorResult)
        XCTAssertEqual(singleRun("if"), MiniScriptErrorResult)
        XCTAssertEqual(singleRun("if\nelse\nelse"), MiniScriptErrorResult)
        XCTAssertEqual(singleRun("end\nelse\nelse"), MiniScriptErrorResult)
    }
}
