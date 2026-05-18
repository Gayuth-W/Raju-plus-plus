# TaskLang++ Parser - Cyber-Incident Kill Switch DSL

TaskLang++ is a custom Domain-Specific Language (DSL) implemented in C using Flex and Bison. It is designed for defining, scheduling, and executing automated tasks, with a specific focus on orchestrating cyber-incident kill switch scenarios.

## Features

- **Task Definition**: Define isolated tasks with specific names and executable commands.
- **Time-based Scheduling**: Schedule tasks to run daily or weekly at specific times (e.g., `EVERY DAY AT 14:30`, `EVERY WEEK ON MONDAY AT 09:00`).
- **Event-based Triggers**: Trigger tasks based on custom events (e.g., `TRIGGER ON incident`).
- **Dependency Management**: Establish execution order using `AFTER`, `BEFORE`, or `DEPENDS ON` keywords.
- **Conditional Execution**: Run tasks conditionally based on the `success` or `failure` of previous tasks.
- **Execution Constraints**: Define timeouts for task execution using the `WITHIN` keyword.
- **Semantic Analysis**: Includes robust validation to catch unknown dependencies and a cycle detection algorithm to prevent circular dependencies.
- **Execution Simulation**: Automatically resolves dependencies and simulates the execution of defined tasks respecting dependencies and conditions.

## Prerequisites

To build and run this project, you need the following installed on your system:
- GCC (GNU Compiler Collection)
- Flex (Fast Lexical Analyzer Generator)
- Bison (GNU Parser Generator)
- Make

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
./tasklang input/test_kill_switch_complete.tasklang
```

## Project Structure

- `lexer.l`: Flex lexical analyzer definition containing token rules and regular expressions.
- `parser.y`: Bison grammar file containing the parser logic, abstract syntax tree nodes, and semantic validation.
- `Makefile`: Build instructions for compiling the project.
- `input/`: Directory containing various test cases, error simulations, and examples of TaskLang++ scripts.

## Language Syntax Example

```text
TASK shutdown_server {
    RUN "/sbin/shutdown -h now"
    TRIGGER ON breach_detected
    WITHIN 60
}

TASK notify_admin {
    RUN "send_alert.sh admin@example.com"
    AFTER shutdown_server
    IF success
}
```
