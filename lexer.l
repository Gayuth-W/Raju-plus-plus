%{
#include <stdio.h>
#include <string.h>
#include "parser.tab.h"

extern int yylineno;
extern char *yytext;

void report_lex_error(const char *msg) {
    fprintf(stderr, "[LEXICAL ERROR] Line %d: %s\n", yylineno, msg);
}
%}

%option yylineno noyywrap nodefault

%%

"TASK"                  { return TASK; }
"RUN"                   { return RUN; }
"EVERY"                 { return EVERY; }
"DAY"                   { return DAY; }
"WEEK"                  { return WEEK; }
"ON"                    { return ON; }
"AT"                    { return AT; }
"TRIGGER"               { return TRIGGER; }
"AFTER"                 { return AFTER; }
"BEFORE"                { return BEFORE; }
"DEPENDS"               { return DEPENDS; }
"IF"                    { return IF; }
"success"               { return SUCCESS; }
"failure"               { return FAILURE; }
"WITHIN"                { return WITHIN; }

MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY|SUNDAY {
    yylval.string = strdup(yytext);
    return DAYNAME;
}

[0-9]+:[0-9]{2}         { 
    /* Validate time format */
    int hh, mm;
    sscanf(yytext, "%d:%d", &hh, &mm);
    if (hh < 0 || hh > 23 || mm < 0 || mm > 59) {
        report_lex_error("Invalid time: hours must be 00-23, minutes 00-59");
        return ERROR;
    }
    yylval.string = strdup(yytext);
    return TIME;
}

[0-9]+                  { 
    yylval.num = atoi(yytext);
    return NUMBER;
}

[a-zA-Z_][a-zA-Z0-9_]*  { 
    yylval.string = strdup(yytext);
    return IDENT;
}

\"[^\"]*\"              { 
    yylval.string = strdup(yytext+1);
    yylval.string[strlen(yylval.string)-1] = '\0';
    return STRING;
}

"{"                     { return LBRACE; }
"}"                     { return RBRACE; }
"/*"                    { 
    /* Skip block comments */
    int c;
    while ((c = input()) != EOF) {
        if (c == '*' && (input() == '/')) break;
    }
}
"//"                    { 
    /* Skip line comments */
    int c;
    while ((c = input()) != EOF && c != '\n');
}

\n                      { /* ignore */ }
[ \t\r]+                { /* ignore whitespace */ }

.                       { 
    report_lex_error("Invalid character");
    return ERROR;
}

%%
