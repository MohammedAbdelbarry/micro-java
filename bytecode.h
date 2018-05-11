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
#define LDC "ldc"

/* Variable Loading */

#define ALOAD "aload"

#define ILOAD "iload"
#define FLOAD "fload"

#define I2F "i2f"

#define LDC "ldc"

/* Relational Operations */
#define IFCMP "ifcmp_"

#define SWAP "swap"

/* Arithmetic Operations */
#define IADD "iadd"
#define ISUB "isub"
#define IMUL "imul"
#define IDIV "idiv"
#define FADD "fadd"
#define FSUB "fsub"
#define FMUL "fmul"
#define FDIV "fdiv"

/* Misc */
#define PUBLIC "public"
#define STATIC "static"
#define INVOKE "invokenonvirtual"
#define RETURN "return"

/* Jump Instructions */
#define GOTO "goto"

#endif
