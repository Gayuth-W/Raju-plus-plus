%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>
#include <errno.h>

volatile sig_atomic_t timeout_triggered = 0;
pid_t current_child_pid = -1;

void alarm_handler(int sig) {
    timeout_triggered = 1;
    if (current_child_pid > 0) {
        kill(current_child_pid, SIGKILL);
    }
}

#define MAX_TASKS 100
#define MAX_DEPENDENCIES 10

typedef struct Task {
    char *name;
    char *command;
    char **dependencies;
    int dep_count;
    char *condition;
    int timeout;
    int executed;
    int result;
    int in_degree;
} Task;

Task tasks[MAX_TASKS];
int task_count = 0;
char current_task_name[256];

int find_task(const char *name) {
    for (int i = 0; i < task_count; i++)
        if (strcmp(tasks[i].name, name) == 0)
            return i;
    return -1;
}

void add_task(const char *name) {
    if (task_count >= MAX_TASKS) {
        fprintf(stderr, "[ERROR] Too many tasks (max %d)\n", MAX_TASKS);
        exit(1);
    }
    tasks[task_count].name = strdup(name);
    tasks[task_count].command = NULL;
    tasks[task_count].dependencies = NULL;
    tasks[task_count].dep_count = 0;
    tasks[task_count].condition = NULL;
    tasks[task_count].timeout = 0;
    tasks[task_count].executed = 0;
    tasks[task_count].result = 0;
    tasks[task_count].in_degree = 0;
    task_count++;
}

void set_task_command(const char *name, const char *cmd) {
    int idx = find_task(name);
    if (idx >= 0)
        tasks[idx].command = strdup(cmd);
}



void add_task_dependency(const char *name, const char *dep) {
    int idx = find_task(name);
    if (idx < 0) return;
    
    for (int i = 0; i < tasks[idx].dep_count; i++) {
        if (strcmp(tasks[idx].dependencies[i], dep) == 0)
            return;
    }
    
    tasks[idx].dep_count++;
    tasks[idx].dependencies = realloc(tasks[idx].dependencies, 
                                      sizeof(char*) * tasks[idx].dep_count);
    tasks[idx].dependencies[tasks[idx].dep_count - 1] = strdup(dep);
}

void set_task_condition(const char *name, const char *cond) {
    int idx = find_task(name);
    if (idx >= 0)
        tasks[idx].condition = strdup(cond);
}

void set_task_timeout(const char *name, int sec) {
    int idx = find_task(name);
    if (idx >= 0)
        tasks[idx].timeout = sec;
}

void validate_all_dependencies_exist() {
    for (int i = 0; i < task_count; i++) {
        for (int j = 0; j < tasks[i].dep_count; j++) {
            if (find_task(tasks[i].dependencies[j]) == -1) {
                fprintf(stderr, "[SEMANTIC ERROR] Task '%s' depends on unknown task '%s'\n",
                        tasks[i].name, tasks[i].dependencies[j]);
                exit(1);
            }
        }
    }
}

int has_cycle_util(int idx, int *visited, int *rec_stack) {
    if (rec_stack[idx]) return 1;
    if (visited[idx]) return 0;
    
    visited[idx] = 1;
    rec_stack[idx] = 1;
    
    for (int i = 0; i < tasks[idx].dep_count; i++) {
        int dep_idx = find_task(tasks[idx].dependencies[i]);
        if (dep_idx >= 0) {
            if (has_cycle_util(dep_idx, visited, rec_stack))
                return 1;
        }
    }
    
    rec_stack[idx] = 0;
    return 0;
}

void detect_circular_dependencies() {
    int visited[MAX_TASKS] = {0};
    int rec_stack[MAX_TASKS] = {0};
    
    for (int i = 0; i < task_count; i++) {
        if (!visited[i]) {
            if (has_cycle_util(i, visited, rec_stack)) {
                fprintf(stderr, "[SEMANTIC ERROR] Circular dependency detected involving task '%s'\n",
                        tasks[i].name);
                exit(1);
            }
        }
    }
}

int execute_task_real(int task_idx) {
    Task *t = &tasks[task_idx];
    
    printf("\n--- EXECUTING: %s ---\n", t->name);
    printf("Command: %s\n", t->command);
    
    int pipefd[2];
    if (pipe(pipefd) == -1) {
        perror("[ERROR] pipe failed");
        printf("Status: FAILURE\n");
        return 0;
    }
    
    timeout_triggered = 0;
    current_child_pid = fork();
    
    if (current_child_pid == -1) {
        perror("[ERROR] fork failed");
        close(pipefd[0]);
        close(pipefd[1]);
        printf("Status: FAILURE\n");
        return 0;
    }
    
    if (current_child_pid == 0) {
        // Child process
        // Redirect stdout and stderr to the write end of the pipe
        dup2(pipefd[1], STDOUT_FILENO);
        dup2(pipefd[1], STDERR_FILENO);
        
        // Close both pipe descriptors in child
        close(pipefd[0]);
        close(pipefd[1]);
        
        // Execute the command in standard shell
        execl("/bin/sh", "sh", "-c", t->command, (char *)NULL);
        
        // If execl fails:
        perror("[ERROR] exec failed");
        exit(127);
    }
    
    // Parent process
    close(pipefd[1]); // Close unused write end
    
    // Set up timeout if within constraint is specified
    struct sigaction sa;
    struct sigaction old_sa;
    int has_timeout = (t->timeout > 0);
    
    if (has_timeout) {
        memset(&sa, 0, sizeof(sa));
        sa.sa_handler = alarm_handler;
        sigemptyset(&sa.sa_mask);
        sigaction(SIGALRM, &sa, &old_sa);
        alarm(t->timeout);
    }
    
    char buffer[4096];
    ssize_t bytes_read;
    
    while (1) {
        bytes_read = read(pipefd[0], buffer, sizeof(buffer) - 1);
        if (bytes_read > 0) {
            buffer[bytes_read] = '\0';
            printf("%s", buffer);
            fflush(stdout);
        } else if (bytes_read == 0) {
            // EOF reached
            break;
        } else {
            if (errno == EINTR) {
                if (timeout_triggered) {
                    break;
                }
                continue; // Interrupted by other signal, retry read
            }
            perror("[ERROR] read failed");
            break;
        }
    }
    
    close(pipefd[0]);
    
    // Wait for the child process and gather exit status
    int status;
    pid_t wpid;
    do {
        wpid = waitpid(current_child_pid, &status, 0);
    } while (wpid == -1 && errno == EINTR);
    
    // Disable alarm and restore previous handler
    if (has_timeout) {
        alarm(0);
        sigaction(SIGALRM, &old_sa, NULL);
    }
    
    int success = 0;
    if (timeout_triggered) {
        fprintf(stderr, "[ERROR] Task '%s' timed out after %d seconds and was terminated.\n", t->name, t->timeout);
        success = 0;
    } else if (wpid == -1) {
        perror("[ERROR] waitpid failed");
        success = 0;
    } else {
        if (WIFEXITED(status)) {
            int exit_code = WEXITSTATUS(status);
            if (exit_code == 0) {
                success = 1;
            } else {
                success = 0;
            }
        } else if (WIFSIGNALED(status)) {
            success = 0;
        }
    }
    
    if (success) {
        printf("Status: SUCCESS\n");
    } else {
        printf("Status: FAILURE\n");
    }
    
    return success;
}

void execute_tasks_by_dependency() {
    printf("\n=== EXECUTION START ===\n");
    
    int executed[MAX_TASKS] = {0};
    int task_result[MAX_TASKS] = {0};
    int remaining = task_count;
    
    while (remaining > 0) {
        int found = 0;
        
        for (int i = 0; i < task_count; i++) {
            if (executed[i]) continue;
            
            int deps_satisfied = 1;
            int dep_failed = 0;
            
            for (int j = 0; j < tasks[i].dep_count; j++) {
                int dep_idx = find_task(tasks[i].dependencies[j]);
                if (dep_idx >= 0) {
                    if (!executed[dep_idx]) {
                        deps_satisfied = 0;
                        break;
                    }
                    if (task_result[dep_idx] == -1) {
                        dep_failed = 1;
                    }
                }
            }
            
            if (!deps_satisfied) continue;
            
            int should_execute = 1;
            if (tasks[i].condition && dep_failed) {
                if (strcmp(tasks[i].condition, "success") == 0) {
                    should_execute = 0;
                }
            }
            if (tasks[i].condition && !dep_failed) {
                if (strcmp(tasks[i].condition, "failure") == 0) {
                    should_execute = 0;
                }
            }
            
            if (should_execute) {
                int result = execute_task_real(i);
                task_result[i] = result ? 1 : -1;
            } else {
                printf("\n--- Skipping: %s ---\n", tasks[i].name);
                printf("Reason: Condition '%s' not met\n", tasks[i].condition);
                task_result[i] = -1;
            }
            
            executed[i] = 1;
            found = 1;
            remaining--;
        }
        
        if (!found) {
            fprintf(stderr, "\n[ERROR] Unable to resolve dependencies.\n");
            break;
        }
    }
    
    printf("\n=== EXECUTION COMPLETE ===\n");
}

void print_validation_summary() {
    printf("\n=== VALIDATION SUMMARY ===\n");
    printf("Total tasks defined: %d\n", task_count);
    
    int with_deps = 0;
    for (int i = 0; i < task_count; i++) {
        if (tasks[i].dep_count > 0)
            with_deps++;
    }
    
    printf("Tasks with dependencies: %d\n", with_deps);
    printf("Grammar: Valid\n");
    printf("Dependencies: Acyclic\n");
    printf("Task references: All resolved\n");
}

extern int yylineno;
void yyerror(const char *s) {
    fprintf(stderr, "[SYNTAX ERROR] Line %d: %s\n", yylineno, s);
    exit(1);
}

int yylex(void);
%}

%union {
    int num;
    char *string;
}

%token TASK RUN ON AFTER BEFORE DEPENDS IF SUCCESS FAILURE WITHIN
%token <string> IDENT STRING
%token <num> NUMBER
%token LBRACE RBRACE ERROR

%start program

%%

program
    : task_list
    ;

task_list
    : task
    | task_list task
    ;

task
    : TASK IDENT LBRACE { strcpy(current_task_name, $2); add_task($2); } task_body RBRACE
    ;

task_body
    : run_stmt optional_parts
    ;

run_stmt
    : RUN STRING
        { set_task_command(current_task_name, $2); }
    ;

optional_parts
    : /* empty */
    | optional_parts dependency
    | optional_parts condition
    | optional_parts constraint
    ;

dependency
    : AFTER IDENT
        { add_task_dependency(current_task_name, $2); }
    | BEFORE IDENT
        { 
            add_task_dependency($2, current_task_name);
        }
    | DEPENDS ON IDENT
        { add_task_dependency(current_task_name, $3); }
    ;

condition
    : IF SUCCESS
        { set_task_condition(current_task_name, "success"); }
    | IF FAILURE
        { set_task_condition(current_task_name, "failure"); }
    ;

constraint
    : WITHIN NUMBER
        { set_task_timeout(current_task_name, $2); }
    ;

%%

int main(int argc, char **argv) {
    extern FILE *yyin;
    
    printf("\nTaskLang++ Parser - Cyber-Incident Kill Switch DSL\n");
    
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <input.tasklang>\n", argv[0]);
        return 1;
    }
    
    yyin = fopen(argv[1], "r");
    if (!yyin) {
        perror(argv[1]);
        return 1;
    }
    
    printf("Parsing file: %s\n", argv[1]);
    printf("----------------------------------------\n");
    
    int parse_status = yyparse();
    fclose(yyin);
    
    if (parse_status == 0) {
        validate_all_dependencies_exist();
        detect_circular_dependencies();
        print_validation_summary();
        execute_tasks_by_dependency();
    } else {
        fprintf(stderr, "[ERROR] Parsing failed.\n");
        return 1;
    }
    
    return 0;
}