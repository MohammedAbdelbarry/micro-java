%{
#include <cstdio>
#include <iostream>
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

relop "=="|"!="|">"|">="|"<"|"<="
boolop "&&"|"||"|"!"
op "+"|"-"|"*"|"/"|"%"|"&"|"|"|"^"

id          ({letter}|_|\$)({letter}|{digit}|_|\$)*
%%
[ \t]          ;

"="         return T_ASSIGN;
";"         return T_SEMICOL;
    
"+"         return T_PLUS;
"-"         return T_MINUS;
"*"         return T_MUL;
"/"         return T_DIV;
"%"         return T_MOD;

"&&"        return T_ANDOP;
"||"        return T_OROP;
"!"         return T_NOT;

"&"         return T_BIT_AND;
"|"         return T_BIT_OR;
"^"         return T_BIT_XOR;
"~"         return T_CMPL;

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

{int}       return T_INT;
{float}     return T_float;
{boolean}   return T_BOOLEAN;
{while}     return T_WHILE;
{for}       return T_FOR;
{if}        return T_IF;
{else}      return T_ELSE;


{inum}      {yy.fval = atof(yytext); return T_INT_LITERAL;}
{fnum}      {yy.ival = atoi(yytext); return T_FLOAT_LITERAL;}
{bin}       {yy.bval = !strcmp(yytext, "true") ? 1 : 0; return T_BOOL_LITERAL;}
{id}        {yy.sval = strdup(yytext); return T_ID;}

\n          ;
%%

int main(int, char**) {
	yylex();
}
