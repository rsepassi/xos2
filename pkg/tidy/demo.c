// https://api.html-tidy.org/tidy/tidylib_api_5.8.0/
#include "tidy.h"
#include "tidybuffio.h"

#include "base/log.h"
#include "base/stdtypes.h"

#define MAX_DEPTH 4

int main(int argc, char** argv) {
  char* input = "<foobar big=z><foo/><contents attr=7>Hi</contents><meta><a>Bye</a><b/></meta></foobar>";
  TidyDoc tdoc = tidyCreate();
  tidyOptSetBool(tdoc, TidyXmlTags, 1);

  TidyBuffer errbuf = {0};
  CHECK(tidySetErrorBuffer(tdoc, &errbuf) == 0);
  CHECK(tidyParseString(tdoc, input) < 2);

  TidyNode n = tidyGetRoot(tdoc);
  TidyBuffer buf = {0};
  tidyBufInit(&buf);

  // Iterative depth-first traversal of node n
  TidyNode stack[MAX_DEPTH];  // each entry is the child pointer for that level
  int stack_top = 0;
  stack[stack_top] = tidyGetChild(n);

  // While we're not done with the root node
  while (stack_top >= 0) {
stack_start:;
    // Continue processing the children for the node at the top of the stack
    TidyNode cur = stack[stack_top];
    for (; cur; cur = tidyGetNext(cur)) {
      TidyNodeType type = tidyNodeGetType(cur);
      switch (type) {
        case TidyNode_Text:
          tidyNodeGetText(tdoc, cur, &buf);
          LOG(": %.*s", buf.size - 1, buf.bp);
          tidyBufClear(&buf);
          break;
        case TidyNode_Start:
        case TidyNode_StartEnd:
          LOG("< %s", tidyNodeGetName(cur));
          for (TidyAttr attr = tidyAttrFirst(n); attr; attr = tidyAttrNext(attr)) {
            LOG("     %s=%s", tidyAttrName(attr), tidyAttrValue(attr));
          }
          if (type == TidyNode_Start) {
            // We have a new node to descend into
            // Advance the pointer to the next child for the current level
            stack[stack_top] = tidyGetNext(cur);
            // Push the new node onto the top of the stack
            stack[++stack_top] = tidyGetChild(cur);
            goto stack_start;
          } else {
            LOG(">");
          }
          break;
        default:
          LOG("node skip %s %d", tidyNodeGetName(cur), type);
      }
    }

    // We've made it to the end of the children at this level. Pop the stack.
    if (--stack_top >= 0) LOG(">");
  }

  tidyBufFree(&buf);
  tidyRelease(tdoc);
  return 0;
}
