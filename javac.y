%{
#include <iostream>
#include <sstream>
#include <cstring>
#include <unordered_map>
#include <vector>
#include "bytecode.h"
using namespace std;

extern "C" int yylex();
extern "C" int yyparse();
extern "C" FILE *yyin;

void yyerror(const char *s);

string get_header();
bool id_exists(string sval);
void declare_new_var(const int tval, const char *sval);
void store(string ident);
void store_const(int c);
void get_relop(string op, int type1, int type2);
string get_declaration_code(const int tval, const string sval);
string get_label();

int var_ind = 1;

struct var_metainfo {
    int ind;
    int type;
};

extern char* yytext;
extern int yylineno;

unordered_map<string, struct var_metainfo> symtab;
vector<string> code_list;
int label_cnt = 0;
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
%type   <tval>   DECLARATION
%type   <tval>  NUMBER
%type   <tval>  EXPRESSION
%type   <tval>  BOOL_EXPRESSION



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

METHOD_BODY:
        STATEMENT_LIST      {   
                                stringstream ss;
                                ss << get_header();  }

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

                                    string code_ = get_declaration_code(tval, sval);
                                    
                                    code_list.push_back(code_);
                                    
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
        EXPRESSION_         {code_list.push_back(IADD);}
    |   EXPRESSION
        T_MINUS
        EXPRESSION_         {code_list.push_back(ISUB);}
    |   EXPRESSION
        T_MUL
        EXPRESSION_         {code_list.push_back(IMUL);}
    |   EXPRESSION
        T_DIV
        EXPRESSION_         {code_list.push_back(IDIV);}
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
                                code_list.push_back(ss.str());
                            }
    |   T_FLOAT_CONST       {
                                stringstream ss;
                                ss << LDC << " ";
                                ss << $1;
                                code_list.push_back(ss.str());
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
                                get_relop("lt", $<tval>1, $<tval>3);
                            }
    |   EXPRESSION
        T_GT
        EXPRESSION          {
                                get_relop("gt", $<tval>1, $<tval>3);
                            }
    |   EXPRESSION
        T_GE
        EXPRESSION          {
                                get_relop("ge", $<tval>1, $<tval>3);
                            }
    |   EXPRESSION
        T_LE
        EXPRESSION          {
                                get_relop("le", $<tval>1, $<tval>3);
                            }
    |   EXPRESSION
        T_EQ
        EXPRESSION          {
                                get_relop("eq", $<tval>1, $<tval>3);
                            }
    |   EXPRESSION
        T_NE
        EXPRESSION          {
                                get_relop("ne", $<tval>1, $<tval>3);
                            }
    |   BOOL_EXPRESSION
        T_ANDAND
        BOOL_EXPRESSION     {
                                //TODO: GENERATE THE CODE!!
                            }
    |   BOOL_EXPRESSION
        T_OROR
        BOOL_EXPRESSION     {
                                //TODO: GENERATE THE CODE!!
                            }
    |   T_NOT
        BOOL_EXPRESSION     {
                                //TODO: COMMIT SUICIDE :/
                            }
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

string get_header() {
    stringstream ss;
    ss << SOURCE << " input.txt" << endl;
    ss << CLASS << " " << PUBLIC << " " << "test" << endl;
    ss << SUPER << " java/lang/object" << endl;
    ss << METHOD << " " << PUBLIC << " <init>()V" << endl;
    ss << INVOKE << " java/lang/object/<init>()V" << endl;
    ss << RETURN << endl;
    ss << END << " method" << endl;

    ss << METHOD << " " << PUBLIC << " " << STATIC << " main([Ljava/lang/String;)V" << endl;
    ss << LIMIT << " locals 100" << endl;
    ss << LIMIT << " stack 100" << endl;

    return ss.str();
}

void yyerror (const char *s) {
    cout << yylineno << ": " << s << " near " << "'" << yytext << "''" << endl;
    for (string line : code_list) {
        cout << line << endl;
    }
}

bool id_exists(string sval) {
    return (symtab.find(sval) != symtab.end());
}

void store(string ident) {
    stringstream ss;
    ss << ISTORE << "_" << symtab[ident].ind;
    code_list.push_back(ss.str());
}

void store_const(int c) {
    stringstream ss;
    if (c >= 0 && c <= 5){
        ss << ICONST << "_" << c;
    } else if (c == -1) {
        ss << ICONST << "_m1";
    } else {
        ss << BIPUSH << " " << c;
    }
    code_list.push_back(ss.str());
}

void clear(stringstream &ss) {
    ss.clear();
    ss.str(string());
}

void get_relop(string op, int type1, int type2) {
    string true_label = get_label();
    stringstream code_stream;
    code_stream << IFCMP << op << " " << true_label;
    code_list.push_back(code_stream.str());
    clear(code_stream);
    code_stream << ICONST << "_" << 0;
    code_list.push_back(code_stream.str());
    clear(code_stream);
    code_stream << GOTO << " " << 1;
    code_list.push_back(code_stream.str());
    clear(code_stream);
    code_stream << true_label << ": " << ICONST << "_" << 1;
    code_list.push_back(code_stream.str());
    clear(code_stream);
    
    if (type1 != type2) {
    
    } else {
    }
}

string get_label() {
    stringstream ss;
    ss << "L_" << (label_cnt++);
    return ss.str();
}

string get_declaration_code(const int tval, const string sval) {
    stringstream ss;

    switch (tval) {
        case T_INT:
            ss << ICONST << "_0";
            ss << ISTORE << " " << var_ind;
            break;
        case T_FLOAT:
            ss << FCONST << "_0";
            ss << FSTORE << " " << var_ind;
        default:
            yyerror("syntax error: Unmatched type!");
            break;
    }

    return ss.str();
}
