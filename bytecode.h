#ifndef BYTECODE
#define BYTECODE


/* Header Directives */
#define SOURCE ".source"
#define CLASS ".class"
#define SUPER ".super"
#define METHOD ".method"
#define END ".end"
#define LIMIT ".limit"

/* Variable Declarations */
#define ICONST "iconst"
#define FCONST "fconst"
#define BIPUSH "bipush"

/* Variable Storing */
#define ISTORE "istore"
#define FSTORE "fstore"

/* Variable Loading */
#define ALOAD "aload"

/* Arithmetic Operations */
#define IADD "iadd"
#define ISUB "isub"
#define IMUL "imul"
#define IDIV "idiv"

/* Misc */
#define PUBLIC "public"
#define STATIC "static"
#define INVOKE "invokenonvirtual"
#define RETURN "return"
#endif
