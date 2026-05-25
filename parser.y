%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_TASKS 100
#define MAX_DEPENDENCIES 10

typedef struct Task {
    char *name;
    char *command;
    char *schedule;
    char **dependencies;
    int dep_count;
    char *condition;
    int timeout;
    int has_time_schedule;
    int has_event_schedule;
    int executed;
    int result;
    int in_degree;
} Task;

Task tasks[MAX_TASKS];
int task_count = 0;
char current_task_name[256];
%}

%union {
    int num;
    char *string;
}

%token TASK RUN EVERY DAY WEEK ON AT TRIGGER AFTER BEFORE DEPENDS IF SUCCESS FAILURE WITHIN
%token <string> IDENT STRING TIME DAYNAME
%token <num> NUMBER
%token LBRACE RBRACE ERROR

%start program

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
    tasks[task_count].schedule = NULL;
    tasks[task_count].dependencies = NULL;
    tasks[task_count].dep_count = 0;
    tasks[task_count].condition = NULL;
    tasks[task_count].timeout = 0;
    tasks[task_count].has_time_schedule = 0;
    tasks[task_count].has_event_schedule = 0;
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

void set_task_schedule(const char *name, const char *sched, int is_time) {
    int idx = find_task(name);
    if (idx >= 0) {
        tasks[idx].schedule = strdup(sched);
        if (is_time)
            tasks[idx].has_time_schedule = 1;
        else
            tasks[idx].has_event_schedule = 1;
    }
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


int simulate_task_execution(int task_idx) {
    Task *t = &tasks[task_idx];
    
    printf("\n--- Executing: %s ---\n", t->name);
    printf("Command: %s\n", t->command);
    if (t->schedule)
        printf("Schedule: %s\n", t->schedule);
    if (t->dep_count > 0) {
        printf("Depends on:");
        for (int i = 0; i < t->dep_count; i++)
            printf(" %s", t->dependencies[i]);
        printf("\n");
    }
    if (t->condition)
        printf("Condition: %s\n", t->condition);
    if (t->timeout > 0)
        printf("Timeout: %d seconds\n", t->timeout);
    
    int success = 1;  /* Change to 0 to simulate failure */
    
    if (success) {
        printf("Status: SUCCESS (simulated)\n");
    } else {
        printf("Status: FAILURE (simulated)\n");
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
                int result = simulate_task_execution(i);
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
    
    int time_scheduled = 0, event_scheduled = 0, with_deps = 0;
    for (int i = 0; i < task_count; i++) {
        if (tasks[i].has_time_schedule) time_scheduled++;
        if (tasks[i].has_event_schedule) event_scheduled++;
        if (tasks[i].dep_count > 0) with_deps++;
    }
    
    printf("Time-scheduled tasks: %d\n", time_scheduled);
    printf("Event-scheduled tasks: %d\n", event_scheduled);
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


}