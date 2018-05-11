%{
#include <iostream>
#include <sstream>
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
void store_const(int c);
string get_relop(string op, int type1, int type2);
struct code get_declaration_code(const int tval, const string sval);
string get_label();

int var_ind = 1;

struct code {
    string code;
    int codelen;
};

struct var_metainfo {
    int ind;
    int type;
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
        char *code;
        int codelen;
    } codeval;
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
%type   <codeval>   DECLARATION
%type   <tval>  NUMBER
%type   <codeval>  EXPRESSION
%type   <codeval>  BOOL_EXPRESSION



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
                                string sval ($<sval>2);

                                if (id_exists(sval)) {
                                    string msg = "syntax error: Redeclaration of variable: " + string(sval);
                                    yyerror(msg.c_str());
                                } else {
                                    symtab[sval] = (struct var_metainfo) {var_ind, tval};

                                    struct code code_ = get_declaration_code(tval, sval);
                                    
                                    $<codeval.code>$ = strdup(code_.code.c_str());
                                    $<codeval.codelen>$ = code_.codelen;

                                    cout << $<codeval.code>$ << endl;

                                    var_ind++;
                                }
                            }
    |   PRIMITIVE
        ASSIGNMENT          {
                                int tval = $<tval>1;
                                string sval = $<sval>2;

                                if (id_exists(sval)) {
                                    string msg = "Syntax error: Redeclaration of variable: " + string(sval);
                                    yyerror(msg.c_str());
                                } else {
                                    //TODO: ICONST WITH VALUE OF INITIALIZATION.
                                    symtab[sval] = (struct var_metainfo) {var_ind, tval};
                                    store(sval);
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
                                } else {
                                    store(sval);
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
        T_SEMICOL
    |   T_ID
        T_ASSIGN
        BOOL_EXPRESSION
        T_SEMICOL

EXPRESSION:
        EXPRESSION_
    |   EXPRESSION
        T_PLUS
        EXPRESSION_         {cout << IADD << endl;}
    |   EXPRESSION
        T_MINUS
        EXPRESSION_         {cout << ISUB << endl;}
    |   EXPRESSION
        T_MUL
        EXPRESSION_         {cout << IMUL << endl;}
    |   EXPRESSION
        T_DIV
        EXPRESSION_         {cout << IDIV << endl;}
    |   EXPRESSION
        T_MOD
        EXPRESSION_
    |   EXPRESSION
        T_AND
        EXPRESSION_
    |   EXPRESSION
        T_XOR
        EXPRESSION_
    |   EXPRESSION
        T_OR
        EXPRESSION_

EXPRESSION_:
        T_INT_CONST         {   stringstream ss;
                                ss << LDC << " ";
                                ss << $1;
                                $<codeval.code>$ = strdup(ss.str().c_str());
                                $<codeval.codelen>$ = 2;
                            }
    |   T_FLOAT_CONST       {
                                stringstream ss;
                                ss << LDC << " ";
                                ss << $1;
                                $<codeval.code>$ = strdup(ss.str().c_str());
                                $<codeval.codelen>$ = 2;
                            }
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
        T_LT
        EXPRESSION          {
                                $<codeval.code>$ = strdup(get_relop("lt", $<tval>1, $<tval>3).c_str());
                                $<codeval.codelen>$ = 3;
                                cout << $<codeval.code>1 << endl << $<codeval.code>3 << endl <<  $<codeval.code>$ << endl;
                            }
    |   EXPRESSION
        T_GT
        EXPRESSION          {
                                $<codeval.code>$ = strdup(get_relop("gt", $<tval>1, $<tval>3).c_str());
                                $<codeval.codelen>$ = 3;
                                cout << $<codeval.code>1 << endl << $<codeval.code>3 << endl <<  $<codeval.code>$ << endl;
                            }
    |   EXPRESSION
        T_GE
        EXPRESSION          {
                                $<codeval.code>$ = strdup(get_relop("ge", $<tval>1, $<tval>3).c_str());
                                $<codeval.codelen>$ = 3;
                                cout << $<codeval.code>1 << endl << $<codeval.code>3 << endl <<  $<codeval.code>$ << endl;
                            }
    |   EXPRESSION
        T_LE
        EXPRESSION          {
                                $<codeval.code>$ = strdup(get_relop("le", $<tval>1, $<tval>3).c_str());
                                $<codeval.codelen>$ = 3;
                                cout << $<codeval.code>1 << endl << $<codeval.code>3 << endl <<  $<codeval.code>$ << endl;
                            }
    |   EXPRESSION
        T_EQ
        EXPRESSION          {
                                $<codeval.code>$ = strdup(get_relop("eq", $<tval>1, $<tval>3).c_str());
                                $<codeval.codelen>$ = 3;
                                cout << $<codeval.code>1 << endl << $<codeval.code>3 << endl <<  $<codeval.code>$ << endl;
                            }
    |   EXPRESSION
        T_NE
        EXPRESSION          {
                                $<codeval.code>$ = strdup(get_relop("ne", $<tval>1, $<tval>3).c_str());
                                $<codeval.codelen>$ = 3;
                                cout << $<codeval.code>1 << endl << $<codeval.code>3 << endl <<  $<codeval.code>$ << endl;
                            }
    |   BOOL_EXPRESSION
        T_ANDAND
        BOOL_EXPRESSION
    |   BOOL_EXPRESSION
        T_OROR
        BOOL_EXPRESSION
    |   T_NOT
        BOOL_EXPRESSION
    |   T_LPAREN
        BOOL_EXPRESSION
        T_RPAREN
    |   T_BOOL_LITERAL

    
NUMBER:
        T_INT_CONST         { store_const($1); }
    |   T_FLOAT_CONST


%%

int main() {
    yyparse();
    return 0;
}

void write_header() {

}

void yyerror (const char *s) {
    cout << yylineno << ": " << s << " near " << "'" << yytext << "''" << endl;
}

bool id_exists(string sval) {
    return (symtab.find(sval) != symtab.end());
}

void store(string ident) {
    cout << ISTORE << "_" << symtab[ident].ind << endl;
}

void store_const(int c) {
    if (c >= 0 && c <= 5){
        cout << ICONST << "_" << c << endl;
    } else if (c == -1) {
        cout << ICONST << "_m1";
    } else {
        cout << BIPUSH << "\t\t" << c << endl;
    }
}

string get_relop(string op, int type1, int type2) {
    string true_label = get_label();
    stringstream code_stream;
    code_stream << IFCMP << op << "\t\t" << true_label;
    code_stream << "\n";
    code_stream << BIPUSH << "\t\t" << 0;
    code_stream << "\n";
    code_stream << GOTO << "\t\t" << 2;
    code_stream << "\n";   
    code_stream << true_label << ": " << BIPUSH << "\t\t" << 1;
    
    return code_stream.str();
    if (type1 != type2) {
    
    } else {
        return IFCMP + op;
    }
}

string get_label() {
    static int label_cnt = 0;
    stringstream ss;
    ss << "L_" << (label_cnt++);
    return ss.str();
}

struct code get_declaration_code(const int tval, const string sval) {
    stringstream ss;

    switch (tval) {
        case T_INT:
            ss << ICONST << "_0" << endl;
            ss << ISTORE << " " << var_ind << endl;
            break;
        case T_FLOAT:
            ss << FCONST << "_0" << endl;
            ss << FSTORE << " " << var_ind << endl;
        default:
            yyerror("syntax error: Unmatched type!");
            break;
    }

    return code {ss.str(), 2};
}
