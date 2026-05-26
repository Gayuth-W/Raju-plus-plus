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
"ON"                    { return ON; }
"AFTER"                 { return AFTER; }
"BEFORE"                { return BEFORE; }
"DEPENDS"               { return DEPENDS; }
"IF"                    { return IF; }
"success"               { return SUCCESS; }
"failure"               { return FAILURE; }
"WITHIN"                { return WITHIN; }

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
