#include <stdlib.h>

#define ABORT() abort()

void _Unwind_Backtrace() { ABORT(); }
void _Unwind_FindEnclosingFunction() { ABORT(); }
void _Unwind_GetCFA() { ABORT(); }
void _Unwind_GetDataRelBase() { ABORT(); }
void _Unwind_GetIP() { ABORT(); }
void _Unwind_GetIPInfo() { ABORT(); }
void _Unwind_GetLanguageSpecificData() { ABORT(); }
void _Unwind_GetRegionStart() { ABORT(); }
void _Unwind_GetTextRelBase() { ABORT(); }
void _Unwind_Resume() { ABORT(); }
void _Unwind_SetGR() { ABORT(); }
void _Unwind_SetIP() { ABORT(); }
