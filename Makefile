CC = gcc
CFLAGS = -Wall -g

all: tasklang

tasklang: lex.yy.c parser.tab.c
	$(CC) $(CFLAGS) -o tasklang lex.yy.c parser.tab.c

lex.yy.c: lexer.l parser.tab.h
	flex lexer.l || win_flex lexer.l

parser.tab.c parser.tab.h: parser.y
	bison -d parser.y || win_bison -d parser.y

clean:
	rm -f tasklang lex.yy.c parser.tab.c parser.tab.h
