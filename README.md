# Raju++ Parser - Cyber-Incident Kill Switch DSL

TaskLang++ is a custom Domain-Specific Language (DSL) implemented in C using Flex and Bison. It is designed for defining and executing automated tasks in a real OS shell environment, with a specific focus on orchestrating cyber-incident kill switch and workflow automation scenarios.

## Features

- **Task Definition**: Define isolated tasks with specific names and real-world executable shell commands.
- **Dependency Management**: Establish execution order using `AFTER`, `BEFORE`, or `DEPENDS ON` keywords, automatically resolved via a Directed Acyclic Graph (DAG) dependency resolver.
- **Conditional Execution**: Run tasks conditionally based on the `success` or `failure` of previous tasks.
- **Timeout Constraints**: Enforce execution timeouts on tasks using the `WITHIN <seconds>` keyword (realized via signal-based `alarm()` and process `SIGKILL` termination).
- **Semantic Analysis**: Includes robust validation to catch unknown dependencies and a cycle detection algorithm to prevent circular dependencies.
- **Real-Time Shell Execution Engine**: Executes real Linux shell commands, python scripts (`python3 file.py`), and arbitrary binaries under a process-controlled subshell using `fork()`, `execl()`, and `waitpid()`. Captures standard output and error via Unix pipes, streaming command output to `stdout` in real-time.

## Prerequisites

To build and run this project, you need the following installed on your system:
- GCC (GNU Compiler Collection)
- Flex (Fast Lexical Analyzer Generator) or WinFlexBison (on Windows)
- Bison (GNU Parser Generator)
- Make

*Note: Since the execution engine uses POSIX features like `fork()`, `pipe()`, and `sigaction()`, the executable must be compiled and run under a POSIX-compliant environment such as Linux or WSL (Windows Subsystem for Linux).*

## Build Instructions

To build the `tasklang` parser, navigate to the project directory and run:

```bash
make
```

To clean the compiled binaries and generated C files, run:

```bash
make clean
```

## Usage

After building the project, you can run the parser by passing a TaskLang script as an argument:

```bash
./tasklang <path_to_script.tasklang>
```

Example:

```bash
./tasklang input/test_basic.tasklang
```

## Project Structure

- `lexer.l`: Flex lexical analyzer definition containing token rules and regular expressions.
- `parser.y`: Bison grammar file containing the parser logic, execution engine, and semantic validation.
- `Makefile`: Build instructions for compiling the project.
- `input/`: Directory containing various test cases verifying basic and advanced DAG execution flows.

## Language Syntax Example

```text
TASK shutdown_server {
    RUN "/sbin/shutdown -h now"
    WITHIN 60
}

TASK notify_admin {
    RUN "send_alert.sh admin@example.com"
    AFTER shutdown_server
    IF success
}
```
