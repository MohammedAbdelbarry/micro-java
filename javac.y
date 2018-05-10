%{
// #include <bytecode.h>
#include <iostream>
#include <cstring>
using namespace std;

extern "C" int yylex();
extern "C" int yyparse();
extern "C" FILE *yyin;

void yyerror(const char *s);

void write_header();
void declare_new_var();

%}
%start METHOD_BODY

/* Grammar */
%union {
    int ival;
    float fval;
    bool bval;
    char *sval;
}
%token  <ival>  T_INT_CONST
%token  <fval>  T_FLOAT_CONST
%token  <bval>  T_BOOL_LITERAL
%token  <sval>  T_ID_LITERAL
%token  <sval>  T_STR_LITERAL

/* Primitives */
%token  T_INT   T_FLOAT T_BOOLEAN

/* Control Directives */
%token  T_IF    T_ELSE
%token  T_FOR   T_WHILE

/* Arithmetic Operators */
%token  T_PLUS      T_MINUS     T_MUL   T_DIV   T_MOD   /*  +   -   *   /   %   */

/* Bitwise Operators */
%token  T_AND   T_OR    T_XOR   T_LS    T_RS    T_NOT   T_CPL   /*  &   |   ^   <<  >>  !   ~   */

/* LOGICAL OPERATORS */
%token  T_ANDAND    T_OROR      /*  &&  ||  */

/* Comparison Operators */
%token  T_LE    T_GE    T_EQ    T_NE    T_GT    T_LT    /*  <=  >=  ==  !=  >   <   */

/* Special Arithemtic Operators */
%token  T_INC   T_DEC  /*  ++  --  <<  >>  &&  ||  */

/* Punctuation */
%token  T_LPAREN    T_RPAREN    T_LBRACE    T_RBRACE    T_LBRACK    T_RBRACK    /*  {   }   (   )   */
%token  T_ASSIGN    T_SEMICOL   /*  =   ;           */


%type   <type>  PRIMITIVE

%%

METHOD_BODY:                {   write_header();  }
        STATEMENT_LIST

STATEMENT_LIST:
        STATEMENT
    |   STATEMENT_LIST
        STATEMENT

STATEMENT:
        DECLARATION
    |   IF
    |   WHILE
    |   ASSIGNMENT


DECLARATION:
        PRIMITIVE
        T_ID_LITERAL
        T_SEMICOL           

PRIMITIVE:
        T_INT               
    |   T_FLOAT             
    |   T_BOOLEAN           

IF:
        T_IF
        T_LBRACE
        EXPRESSION
        T_RBRACE
        T_LPAREN
        STATEMENT
        T_RPAREN
        T_ELSE
        T_LPAREN
        STATEMENT
        T_RPAREN

WHILE:
        T_WHILE
        T_LBRACE
        EXPRESSION
        T_RBRACE
        T_LPAREN
        STATEMENT
        T_RPAREN

ASSIGNMENT:
        T_ID_LITERAL
        T_EQ
        EXPRESSION
        T_SEMICOL

EXPRESSION:
        EXPRESSION_
    |   EXPRESSION_
        INFIX_OPERATOR
        EXPRESSION_

EXPRESSION_:
        NUMBER
    |   T_ID_LITERAL
    |   T_LBRACE
        EXPRESSION
        T_RBRACE

NUMBER:
        T_INT_CONST
    |   T_FLOAT_CONST

        
INFIX_OPERATOR:
        T_PLUS | T_MINUS | T_MUL | T_DIV | T_MOD
    |   T_LT | T_GT | T_LE | T_GE | T_EQ | T_NE | T_OROR | T_ANDAND

%%

int main() {
    yyparse();
    return 0;
}

void write_header() {
    
}

void yyerror (const char *s) {
    cout << s << endl;
}