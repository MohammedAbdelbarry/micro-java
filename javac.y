%{
// #include <bytecode.h>
#include <iostream>
#include <cstring>
#include <map>
#include "bytecode.h"
using namespace std;

extern "C" int yylex();
extern "C" int yyparse();
extern "C" FILE *yyin;

void yyerror(const char *s);

void write_header();
bool id_exists(char *sval);
void declare_new_var(const int tval, const char *sval);

int var_ind = 0;

struct var_metainfo {
    int ind;
    int type;
};

extern char* yytext;
extern int yylineno;

map<char *, struct var_metainfo> symtab;

%}
%start METHOD_BODY

/* Grammar */
%union {
    int ival;
    float fval;
    bool bval;
    char *sval;
    int tval;
}
%token  <ival>  T_INT_CONST
%token  <fval>  T_FLOAT_CONST
%token  <bval>  T_BOOL_LITERAL
%token  <sval>  T_ID
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
%token  T_LPAREN    T_RPAREN    T_LBRACE    T_RBRACE    T_LBRACK    T_RBRACK    /*  (   )  {   }    */
%token  T_ASSIGN    T_SEMICOL   /*  =   ;           */


%type   <tval>  PRIMITIVE


%left       T_OROR
%left       T_ANDAND
%left       T_OR
%left       T_XOR
%left       T_EQ T_NE
%nonassoc   T_LE T_LT T_GE T_GT
%left       T_AND
%left       T_PLUS T_MINUS
%left       T_MUL T_DIV T_MOD   
%left       T_NEG T_CPL T_NOT
%right      T_INC T_DEC


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
        T_ID
        T_SEMICOL           {
                                int tval = $<tval>1;
                                char *sval = $<sval>2;

                                if (id_exists(sval)) {
                                    string msg = "Syntax error: Redeclaration of variable: " + string(sval);
                                    yyerror(msg.c_str());
                                } else {
                                    symtab[sval] = var_metainfo {var_ind, var_ind};
                                    declare_new_var(tval, sval);
                                    var_ind++;
                                }
                                
                            }
    |   PRIMITIVE
        ASSIGNMENT

PRIMITIVE:                  
        T_INT               {   $$ = T_INT;      }
    |   T_FLOAT             {   $$ = T_FLOAT;    }
    |   T_BOOLEAN           {   $$ = T_BOOLEAN;  }

IF:
        T_IF
        T_LPAREN
        EXPRESSION
        T_RPAREN
        T_LBRACE
        STATEMENT_LIST
        T_RBRACE
        T_ELSE
        T_LBRACE
        STATEMENT_LIST
        T_RBRACE
    |   T_IF
        T_LPAREN
        EXPRESSION
        T_RPAREN
        T_SEMICOL

WHILE:
        T_WHILE
        T_LPAREN
        BOOL_EXPRESSION
        T_RPAREN
        T_LBRACE
        STATEMENT_LIST
        T_RBRACE
    |   T_WHILE
        T_LPAREN
        BOOL_EXPRESSION
        T_RPAREN
        T_SEMICOL

ASSIGNMENT:
        T_ID
        T_ASSIGN
        EXPRESSION
        T_SEMICOL
    |   T_ID
        T_ASSIGN
        BOOL_EXPRESSION
        T_SEMICOL

EXPRESSION:
        EXPRESSION_
    |   EXPRESSION
        ARITH_OPERATOR
        EXPRESSION_

EXPRESSION_:
        NUMBER
    |   T_ID
    |   T_LPAREN
        EXPRESSION
        T_RPAREN
    |   T_CPL
        EXPRESSION
    |   T_MINUS
        EXPRESSION      %prec T_NEG
        

BOOL_EXPRESSION:
        EXPRESSION
        REL_OPERATOR
        EXPRESSION
    |   BOOL_EXPRESSION
        BOOL_OPERATOR
        BOOL_EXPRESSION_
    |   BOOL_EXPRESSION_
    
BOOL_EXPRESSION_:
    |   T_NOT
        BOOL_EXPRESSION
    |   T_LPAREN
        BOOL_EXPRESSION
        T_RPAREN
    |   T_BOOL_LITERAL
        
NUMBER:
        T_INT_CONST
    |   T_FLOAT_CONST

        
ARITH_OPERATOR:
        T_PLUS | T_MINUS | T_MUL | T_DIV | T_MOD | T_AND | T_OR
    
REL_OPERATOR:
        T_LT | T_GT | T_LE | T_GE | T_EQ | T_NE

BOOL_OPERATOR:
        T_ANDAND | T_OROR

%%

int main() {
    yyparse();
    return 0;
}

void write_header() {
    
}

void yyerror (const char *s) {
    cout << yylineno << ": " << s << " near " << yytext << endl;
}

bool id_exists(char *sval) {
    return (symtab.find(sval) != symtab.end());
}

void declare_new_var(const int tval, const char *sval) {
    switch(tval) {
        case T_INT:
            cout << ICONST << "_0" << endl;
            cout << ISTORE << " " << var_ind << endl;
            break;
        case T_FLOAT:
            cout << FCONST << "_0" << endl;
            cout << FSTORE << " " << var_ind << endl;
            break;
        case T_BOOLEAN:
            // TODO: Haven't found yet a matching mnemonic.
            break;
        default:
            yyerror("syntax error: unmatched type!");
            break;
    }
}
