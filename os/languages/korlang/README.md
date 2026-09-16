# Korlang — Simple, Fast, AI-Native

A systems language that's as easy as Python but compiles to C and runs at native speed.

## Quick Start

```bash
# Install
python3 korlang.py hello.kor --run

# Or compile to C then build
python3 korlang.py hello.kor --emit-c
gcc -o hello hello.c -lm
./hello
```

## Syntax — Python-easy, C-fast

### Variables
```kor
let name = "KorrinOS"        # immutable (like Python)
let count: i32 = 0           # typed
mut score: f64 = 99.5        # mutable (like Kotlin 'var')
val pi: f64 = 3.14           # immutable (like Kotlin 'val')
```

### Functions
```kor
fn greet(name: string) {
    print("Hello, {name}!")
}

fn add(a: i32, b: i32) -> i32 {
    return a + b
}

fn main() {
    greet("World")
    let result = add(2, 3)
    print("2 + 3 = {result}")
}
```

### If/Else
```kor
fn main() {
    let age = 25
    
    if age >= 18 {
        print("Adult")
    } elif age >= 13 {
        print("Teen")
    } else {
        print("Child")
    }
    
    # ternary (like C/JavaScript)
    let status = if age >= 18 { "adult" } else { "minor" }
}
```

### Loops
```kor
fn main() {
    # for loop (like Python)
    for i in 5 {
        print("i = {i}")
    }
    
    # while loop
    mut x = 0
    while x < 10 {
        print("x = {x}")
        x += 1
    }
    
    # infinite loop (like Rust)
    loop {
        break
    }
}
```

### Structs (like Rust + Python dataclass)
```kor
struct User {
    pub name: string
    pub age: i32
    pub email: string
}

fn main() {
    let user = User { name: "Alice", age: 30, email: "alice@example.com" }
    print("{user.name} is {user.age} years old")
}
```

### Enums (like Rust + TypeScript)
```kor
enum Color {
    Red,
    Green,
    Blue,
    Rgb(i32, i32, i32)
}

fn main() {
    let c = Color::Red
    match c {
        Color::Red => print("Red!"),
        Color::Green => print("Green!"),
        Color::Blue => print("Blue!"),
        Color::Rgb(r, g, b) => print("RGB({r},{g},{b})"),
    }
}
```

### Pattern Matching (like Rust + Scala)
```kor
fn describe(x: i32) -> string {
    match x {
        0 => "zero",
        1 | 2 | 3 => "small",
        4...10 => "medium",
        _ => "large",
    }
}
```

### Closures (like JavaScript + Python lambda)
```kor
fn main() {
    let numbers = [1, 2, 3, 4, 5]
    let doubled = numbers.map(fn(x) => x * 2)
    let evens = numbers.filter(fn(x) => x % 2 == 0)
    let sum = numbers.reduce(0, fn(acc, x) => acc + x)
}
```

### Error Handling (like Go + Rust)
```kor
fn divide(a: f64, b: f64) -> result<f64, string> {
    if b == 0.0 {
        return err("division by zero")
    }
    return ok(a / b)
}

fn main() {
    try {
        let result = divide(10.0, 3.0)?
        print("Result: {result}")
    } catch (e) {
        print("Error: {e}")
    }
}
```

### Concurrency (like Go goroutines)
```kor
fn worker(id: i32) {
    print("Worker {id} started")
    # ... work ...
    print("Worker {id} done")
}

fn main() {
    # parallel block — runs tasks concurrently
    par {
        task worker(1)
        task worker(2)
        task worker(3)
    }
    
    # channels (like Go)
    let ch = channel<i32>(10)
    spawn(fn() { ch.send(42) })
    let val = ch.recv()
}
```

### AI Primitives (built-in)
```kor
fn main() {
    # Load a model
    let model = ai.load("tinkeria.3b")
    
    # Create tensors
    let t = tensor([2, 3], [1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
    let m = matrix([[1, 2], [3, 4]])
    
    # Inference
    let result = model.infer("What is KorrinOS?")
    print(result)
    
    # Matrix math
    let product = t.matmul(m)
}
```

### System Calls (like C + Rust)
```kor
fn main() {
    # Read /proc
    let cpu_info = proc.read("/proc/cpuinfo")
    print(cpu_info)
    
    # Write to /proc
    proc.write("/proc/sys/vm/swappiness", "10")
    
    # Hardware detection
    let hw = hw.detect()
    print("CPU: {hw.cpu_model}")
    print("RAM: {hw.ram_mb}MB")
    print("GPU: {hw.gpu_name}")
}
```

### SQL Embedded (like Java JPA)
```kor
fn main() {
    let users = sql("SELECT * FROM users WHERE age > 18")
    for user in users {
        print("{user.name}: {user.email}")
    }
}
```

### Defer (like Go)
```kor
fn main() {
    let file = open("data.txt")
    defer { close(file) }  # runs when scope exits
    
    let content = read(file)
    process(content)
    # file is closed automatically
}
```

### Traits (like Rust + Java interfaces)
```kor
trait Drawable {
    fn draw(&self)
    fn area(&self) -> f64
}

struct Circle {
    radius: f64
}

impl Drawable for Circle {
    fn draw(&self) {
        print("Drawing circle with radius {self.radius}")
    }
    
    fn area(&self) -> f64 {
        3.14159 * self.radius * self.radius
    }
}
```

### String Interpolation (like Dart + JavaScript)
```kor
fn main() {
    let name = "KorrinOS"
    let version = 1.3
    
    # Simple interpolation
    print("Welcome to {name} v{version}")
    
    # Expressions in interpolation
    print("2 + 2 = {2 + 2}")
    
    # Multi-line strings (like Dart)
    let msg = """
    Hello, {name}!
    Version: {version}
    """
}
```

### Null Safety (like Dart + Kotlin)
```kor
fn main() {
    let name: ?string = get_name()  # nullable
    
    # Safe call (like Kotlin)
    let len = name?.length
    
    # Null coalescing (like Dart/JavaScript)
    let display = name ?? "Anonymous"
    
    # Assert non-null (like Dart !)
    let forced = name!
}
```

### Imports (like Python + Rust)
```kor
import std.io
import std.math
use std::collections::HashMap

fn main() {
    let map = HashMap::new()
    map.insert("key", "value")
}
```

---

## Types

| Type | Description |
|------|-------------|
| `i8`, `i16`, `i32`, `i64` | Signed integers |
| `u8`, `u16`, `u32`, `u64` | Unsigned integers |
| `f32`, `f64` | Floating point |
| `bool` | true/false |
| `char` | Single character |
| `string` | UTF-8 string |
| `T?` | Optional (nullable) |
| `*T` | Pointer |
| `&T` | Reference |
| `[T]` | Array |
| `map<K,V>` | HashMap |
| `channel<T>` | Concurrency channel |
| `result<T,E>` | Result type (ok/err) |
| `tensor` | N-dimensional array (AI) |
| `matrix` | 2D tensor |

---

## Operators

| Op | Name | Example |
|----|------|---------|
| `+` `-` `*` `/` `%` | Arithmetic | `a + b` |
| `==` `!=` `<` `>` `<=` `>=` | Comparison | `a == b` |
| `&&` `\|\|` `!` | Logical | `a && b` |
| `&` `\|` `^` `~` `<<` `>>` | Bitwise | `a & b` |
| `=` `+=` `-=` `*=` `/=` | Assignment | `a += 1` |
| `..` `...` | Range | `0..10` |
| `=>` | Lambda/Fat arrow | `fn(x) => x * 2` |
| `?.` `!.` | Null safe call | `name?.length` |
| `??` | Null coalescing | `name ?? "default"` |
| `? :` | Ternary | `a > b ? a : b` |

---

## Compilation

```
.kor file → Lexer → Tokens → Parser → AST → CCodeGen → .c file → GCC → binary
```

Korlang compiles to C, then uses GCC/LLVM to produce native binaries. This means:
- **No custom backend needed** — leverages decades of C compiler optimization
- **Full C interop** — call any C library directly
- **Fast compilation** — parsing + codegen is instant
- **Portable** — runs anywhere C runs

---

## Philosophy

1. **Simple** — if you know Python, you know 80% of Korlang
2. **Fast** — compiles to C, runs at native speed
3. **Safe** — ownership system prevents memory bugs
4. **AI-native** — tensor types and inference built into the language
5. **OS-ready** — system calls, kernel access, hardware detection as first-class features
