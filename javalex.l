%{
#include <cstdio>
#include <iostream>
#include "javac.tab.h"
#define YY_DECL extern "C" int yylex()
using namespace std;

int line_num = 1;
%}

%option yylineno
%option noyywrap

letter      [a-zA-Z]
digit       [0-9]
digits      {digit}+
sign        [+-]
int         "int"
float       "float"
boolean     "boolean"
while       "while"
for         "for"
if          "if"
else        "else"
bin         "true"|"false"
inum        {digit}+
fnum        (({digit}*\.{digit}+)|({digit}+\.{digit}*)){exp}?
exp         [eE]{sign}?{digit}+

id          ({letter}|_|\$)({letter}|{digit}|_|\$)*
%%
[ \t]          ;


"+"         return T_PLUS;
"-"         return T_MINUS;
"*"         return T_MUL;
"/"         return T_DIV;
"%"         return T_MOD;

"++"		return T_INC;
"--"		return T_DEC;

"&&"        return T_ANDAND;
"||"        return T_OROR;
"!"         return T_NOT;

"<<"		return T_LS;
">>"		return T_RS;
"&"         return T_AND;
"|"         return T_OR;
"^"         return T_XOR;
"~"         return T_CPL;

"=="        return T_EQ;
"!="        return T_NE;
"<"         return T_LT;
"<="        return T_LE;
">"         return T_GT;
">="        return T_GE;

"("         return T_LPAREN;
")"         return T_RPAREN;
"["         return T_LBRACK;
"]"         return T_RBRACK;
"{"         return T_LBRACE;
"}"         return T_RBRACE;

";"			return T_SEMICOL;

{int}       return T_INT;
{float}     return T_FLOAT;
{boolean}   return T_BOOLEAN;
{while}     return T_WHILE;
{for}       return T_FOR;
{if}        return T_IF;
{else}      return T_ELSE;


{inum}      {yylval.fval = atoi(yytext); return T_INT_CONST;}
{fnum}      {yylval.ival = atof(yytext); return T_FLOAT_CONST;}
{bin}       {yylval.bval = !strcmp(yytext, "true") ? 1 : 0; return T_BOOL_LITERAL;}
{id}        {yylval.sval = strdup(yytext); return T_ID_LITERAL;}

\n          ;
%%
/*
int main(int, char**) {
	yylex();
}*/
