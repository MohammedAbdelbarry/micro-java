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
bool id_exists(string sval);
void declare_new_var(const int tval, const char *sval);
void store(string ident);
void store_f(string ident);
void store_const(int c);
void store_const_f(float c);
void load(string ident);
void adjust_types(int t1, int t2);

int var_ind = 1;
int obj_ind = 2;

struct var_metainfo {
    int ind;
    int type;
    bool initialized;
};

struct assignment_metainfo {
    int type;
    string sval;
};

extern char* yytext;
extern int yylineno;

map<string, struct var_metainfo> symtab;

%}
%start METHOD_BODY

/* Grammar */
%union {
    int ival;
    float fval;
    bool bval;
    char *sval;
    int tval;
    struct {
        int type;
        char *sval;
    } assignment_metainfo;
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
%type   <tval>  NUMBER
%type   <tval>  EXPRESSION
%type   <assignment_metainfo>  ASSIGNMENT


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
    |   ASSIGNMENT_

DECLARATION:
        PRIMITIVE
        T_ID
        T_SEMICOL           {
                                int tval = $<tval>1;
                                string sval = $<sval>2;

                                if (id_exists(sval)) {
                                    string msg = "Syntax error: Redeclaration of variable: " + string(sval);
                                    yyerror(msg.c_str());
                                } else {
                                    symtab[sval] = (struct var_metainfo) {var_ind, tval, false};
                                    var_ind++;
                                }

                            }
    |   PRIMITIVE
        ASSIGNMENT          {
                                int tval = $<tval>1;
                                string sval = $2.sval;

                                if (id_exists(sval)) {
                                    string msg = "Syntax error: Redeclaration of variable: " + string(sval);
                                    yyerror(msg.c_str());
                                } else if (tval != $2.type && !(tval == T_FLOAT && $2.type == T_INT)){
                                    string msg = "Syntax error: Incompatible types";
                                    yyerror(msg.c_str());
                                } else {
                                    symtab[sval] = (struct var_metainfo) {var_ind, tval, true};
                                    adjust_types(tval, $2.type);
                                    if (tval == T_INT)
                                      store(sval);
                                    else
                                      store_f(sval);
                                    var_ind++;
                                }
                            }

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


ASSIGNMENT_:
        T_ID
        T_ASSIGN
        EXPRESSION
        T_SEMICOL           {
                                string sval = $<sval>1;
                                if (!id_exists(sval)) {
                                    string msg = "Syntax error: Cannot find symbol: " + string(sval);
                                    yyerror(msg.c_str());
                                } else if (symtab[$1].type != $3 && !(symtab[$1].type == T_FLOAT && $3 == T_INT)){
                                    string msg = "Syntax error: Incompatible types";
                                    yyerror(msg.c_str());
                                } else {
                                    symtab[$1].initialized = true;
                                    adjust_types(symtab[$1].type, $3);
                                    if (symtab[$1].type == T_INT)
                                      store(sval);
                                    else
                                      store_f(sval);
                                }
                            }
    |   T_ID
        T_ASSIGN
        BOOL_EXPRESSION
        T_SEMICOL

ASSIGNMENT:
        T_ID
        T_ASSIGN
        EXPRESSION
        T_SEMICOL           { $$.type = $3; $$.sval = $1; }
    |   T_ID
        T_ASSIGN
        BOOL_EXPRESSION
        T_SEMICOL

EXPRESSION:
        EXPRESSION
        T_PLUS
        EXPRESSION          {
                                if (($1 != T_INT && $1 != T_FLOAT) || ($3 != T_INT && $3 != T_FLOAT )) {
                                    string msg = "Syntax error: Bad operand types";
                                    yyerror(msg.c_str());
                                } else if ($1 == $3) {
                                    $$ = $1;
                                } else {
                                    $$ = T_FLOAT;
                                }
                                cout << IADD << endl;
                            }
    |   EXPRESSION
        T_MINUS
        EXPRESSION          {
                                if (($1 != T_INT && $1 != T_FLOAT) || ($3 != T_INT && $3 != T_FLOAT )) {
                                    string msg = "Syntax error: Bad operand types";
                                    yyerror(msg.c_str());
                                } else if ($1 == $3) {
                                    $$ = $1;
                                } else {
                                    $$ = T_FLOAT;
                                }
                                cout << ISUB << endl;
                            }
    |   EXPRESSION
        T_MUL
        EXPRESSION          {
                                if (($1 != T_INT && $1 != T_FLOAT) || ($3 != T_INT && $3 != T_FLOAT )) {
                                    string msg = "Syntax error: Bad operand types";
                                    yyerror(msg.c_str());
                                } else if ($1 == $3) {
                                    $$ = $1;
                                } else {
                                    $$ = T_FLOAT;
                                }
                            }
    |   EXPRESSION
        T_DIV
        EXPRESSION          {
                                if (($1 != T_INT && $1 != T_FLOAT) || ($3 != T_INT && $3 != T_FLOAT )) {
                                    string msg = "Syntax error: Bad operand types";
                                    yyerror(msg.c_str());
                                } else if ($1 == $3) {
                                    $$ = $1;
                                } else {
                                    $$ = T_FLOAT;
                                }
                            }
    |   EXPRESSION
        T_MOD
        EXPRESSION
    |   EXPRESSION
        T_AND
        EXPRESSION
    |   EXPRESSION
        T_XOR
        EXPRESSION
    |   EXPRESSION
        T_OR
        EXPRESSION
    |   NUMBER              { $$ = $1; }
    |   T_ID                {
                                if (!id_exists($1)) {
                                  string msg = "Syntax error: Cannot find symbol: " + string($1);
                                  yyerror(msg.c_str());
                                } else if (!symtab[$1].initialized){
                                  string msg = "Syntax error: variable " + string($1) + " might not have been initialized";
                                  yyerror(msg.c_str());
                                } else {
                                  load($1);
                                  $$ = symtab[$1].type;
                                }
                            }
    |   T_LPAREN
        EXPRESSION
        T_RPAREN            { $$ = $2; }
    |   T_CPL
        EXPRESSION
    |   T_MINUS
        EXPRESSION      %prec T_NEG



BOOL_EXPRESSION:
        EXPRESSION
        T_LT
        EXPRESSION
    |   EXPRESSION
        T_GT
        EXPRESSION
    |   EXPRESSION
        T_GE
        EXPRESSION
    |   EXPRESSION
        T_LE
        EXPRESSION
    |   EXPRESSION
        T_EQ
        EXPRESSION
    |   EXPRESSION
        T_NE
        EXPRESSION
    |   BOOL_EXPRESSION
        T_ANDAND
        BOOL_EXPRESSION_
    |   BOOL_EXPRESSION
        T_OROR
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
        T_INT_CONST         {
                                $$ = T_INT;
                                store_const($1);
                            }
    |   T_FLOAT_CONST       {
                                $$ = T_FLOAT;
                                store_const_f($1);
                            }


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

bool id_exists(string sval) {
    return (symtab.find(sval) != symtab.end());
}

void store(string ident) {
    cout << ISTORE << "_" << symtab[ident].ind << endl;
}

void store_f(string ident) {
    if (symtab[ident].ind >= 0 && symtab[ident].ind <= 3) {
        cout << FSTORE << "_" << symtab[ident].ind << endl;
    } else {
        cout << FSTORE << "\t\t" << symtab[ident].ind << endl;
    }
}

void store_const(int c) {
    if (c >= 0 && c <= 5){
        cout << ICONST << "_" << c << endl;
    } else if (c == -1) {
        cout << ICONST << "_m1" << endl;
    } else {
        cout << BIPUSH << "\t\t" << c << endl;
    }
}

void store_const_f(float c) {
    cout << LDC << "\t\t" << "#" << obj_ind++ << "\t\t\t// float " << c << "f" << endl;
}

void load(string ident) {
    if (symtab[ident].type == T_INT){
      cout << ILOAD << "_" << symtab[ident].ind << endl;
    } else {
      if (symtab[ident].ind >= 0 && symtab[ident].ind <= 3) {
          cout << FLOAD << "_" << symtab[ident].ind << endl;
      } else {
          cout << FLOAD << "\t\t" << symtab[ident].ind << endl;
      }
    }
}

void adjust_types(int t1, int t2) {
    if (t1 != t2) {
        cout << I2F << endl;
    }
}

// void declare_new_var(const int tval, const char *sval) {
//     switch(tval) {
//         case T_INT:
//             cout << ICONST << "_0" << endl;
//             cout << ISTORE << " " << var_ind << endl;
//             break;
//         case T_FLOAT:
//             cout << FCONST << "_0" << endl;
//             cout << FSTORE << " " << var_ind << endl;
//             break;
//         case T_BOOLEAN:
//             // TODO: Haven't found yet a matching mnemonic.
//             break;
//         default:
//             yyerror("syntax error: unmatched type!");
//             break;
//     }
// }
