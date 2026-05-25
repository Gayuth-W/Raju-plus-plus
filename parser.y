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

}