%{
#include <iostream>
#include <sstream>
#include <cstring>
#include <unordered_map>
#include <vector>
#include <unordered_set>
#include "bytecode.h"
using namespace std;

extern "C" int yylex();
extern "C" int yyparse();
extern "C" FILE *yyin;

void yyerror(const char *s);

string get_header();
bool id_exists(string sval);
void store(string ident);
void store_f(string ident);
void store_const(int c);
void store_const_f(float c);
void load(string ident);
void adjust_types(int t1, int t2);
void get_relop(string op, int type1, int type2);
string get_label(int);
void backpatch(unordered_set<int> *list, int label_id);
unordered_set<int> *merge_lists(unordered_set<int> *list1, unordered_set<int> *list2);

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
%type   <tval>   DECLARATION
%type   <tval>  NUMBER
%type   <tval>  EXPRESSION
%type   <assignment_metainfo>  ASSIGNMENT
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
                                } else if (tval == T_BOOLEAN) {
                                    // TODO
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
        T_SEMICOL           { $$.type = T_BOOLEAN; $$.sval = $1; }

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
                                if ($$ == T_FLOAT){
                                    if ($3 == T_INT){
                                        code_list.push_back(I2F);
                                    } else if ($1 == T_INT){
                                        code_list.push_back(SWAP);
                                        code_list.push_back(I2F);
                                        code_list.push_back(SWAP);
                                    }
                                    code_list.push_back(FADD);
                                } else {
                                    code_list.push_back(IADD);
                                }
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
                                if ($$ == T_FLOAT){
                                    if ($3 == T_INT){
                                        code_list.push_back(I2F);
                                    } else if ($1 == T_INT){
                                        code_list.push_back(SWAP);
                                        code_list.push_back(I2F);
                                        code_list.push_back(SWAP);
                                    }
                                    code_list.push_back(FSUB);
                                } else {
                                    code_list.push_back(ISUB);
                                }
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
                                if ($$ == T_FLOAT){
                                    if ($3 == T_INT){
                                        code_list.push_back(I2F);
                                    } else if ($1 == T_INT){
                                        code_list.push_back(SWAP);
                                        code_list.push_back(I2F);
                                        code_list.push_back(SWAP);
                                    }
                                    code_list.push_back(FMUL);
                                } else {
                                    code_list.push_back(IMUL);
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
                                if ($$ == T_FLOAT){
                                    if ($3 == T_INT){
                                        code_list.push_back(I2F);
                                    } else if ($1 == T_INT){
                                        code_list.push_back(SWAP);
                                        code_list.push_back(I2F);
                                        code_list.push_back(SWAP);
                                    }
                                    code_list.push_back(FDIV);
                                } else {
                                    code_list.push_back(IDIV);
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
        T_INT_CONST         {
                                $$ = T_INT;
                                store_const($1);
                            }
    |   T_FLOAT_CONST       {
                                $$ = T_FLOAT;
                                store_const_f($1);
                            }


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

void store_f(string ident) {
    stringstream ss;
    if (symtab[ident].ind >= 0 && symtab[ident].ind <= 3) {
        ss << FSTORE << "_" << symtab[ident].ind;
    } else {
        ss << FSTORE << "\t\t" << symtab[ident].ind;
    }
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

void store_const_f(float c) {
    stringstream ss;
    ss << LDC << "\t\t" << "#" << obj_ind++ << "\t\t\t// float " << c << "f";
    code_list.push_back(ss.str());
}

void load(string ident) {
    stringstream ss;

    if (symtab[ident].type == T_INT){
      ss << ILOAD << "_" << symtab[ident].ind;
    }
    else {
      if (symtab[ident].ind >= 0 && symtab[ident].ind <= 3) {
          ss << FLOAD << "_" << symtab[ident].ind;
      }
      else {
          ss << FLOAD << "\t\t" << symtab[ident].ind;
      }
    }
    code_list.push_back(ss.str());
}

void adjust_types(int t1, int t2) {
    if (t1 != t2) {
        code_list.push_back(I2F);
    }
}

void clear(stringstream &ss) {
    ss.clear();
    ss.str(string());
}

void get_relop(string op, int type1, int type2) {
    string true_label = get_label(label_cnt++);
    stringstream code_stream;
    code_stream << IFCMP << op << " " << true_label;
    code_list.push_back(code_stream.str());
    clear(code_stream);
    code_stream << ICONST << "_" << 0;
    code_list.push_back(code_stream.str());
    clear(code_stream);
    code_stream << GOTO;
    code_list.push_back(code_stream.str());
    clear(code_stream);
    code_stream << true_label << ": " << ICONST << "_" << 1;
    code_list.push_back(code_stream.str());
    clear(code_stream);

    if (type1 != type2) {

    } else {
    }
}

string get_label(int _label_cnt) {
    stringstream ss;
    ss << "L_" << _label_cnt;
    return ss.str();
}

unordered_set<int> *merge_lists(unordered_set<int> *list1, unordered_set<int> *list2) {
    if (list1 == nullptr || list2 == nullptr) {
        return nullptr;
    }

    unordered_set<int> *union_list = new unordered_set<int>(list1->begin(), list1->end());
    union_list->insert(list2->begin(), list2->end());
    return union_list;
}

void backpatch(unordered_set<int> *list, int label_id) {
    if (list == nullptr) {
        return;
    }
    string label = get_label(label_id);

    for (int code_idx : *list) {
        code_list[code_idx] = code_list[code_idx] + " " + label;
    }
}
