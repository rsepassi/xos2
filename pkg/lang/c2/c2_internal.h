#ifndef C2_INTERNAL_H_
#define C2_INTERNAL_H_

#include "c2.h"
#include "khash.h"

// Symbol table C2_Name -> C2_TypeId
KHASH_MAP_INIT_INT(mc2symtab, C2_TypeId);
#define c2_symtab_t khash_t(mc2symtab)
c2_symtab_t* c2_symtab_init();
void c2_symtab_deinit(c2_symtab_t* s);
void c2_symtab_reset(c2_symtab_t* s);
void c2_symtab_put(c2_symtab_t* s, C2_Name name, C2_TypeId type);
C2_TypeId c2_symtab_get(c2_symtab_t* s, C2_Name name);

extern const char* c2_stmt_strs[];

#endif
