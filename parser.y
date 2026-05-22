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

}