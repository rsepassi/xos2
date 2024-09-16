// https://api.html-tidy.org/tidy/tidylib_api_5.8.0/
#include "tidy.h"
#include "tidybuffio.h"

#include "base/log.h"
#include "base/stdtypes.h"

#define MAX_DEPTH 4

typedef struct {
  TidyNode* stack;  // each entry is the child pointer for that level
  size_t stack_len;
  int top;  // index of first NULL node
} tidy_stack_t;

TidyNode traverse(TidyDoc tdoc, tidy_stack_t* stack) {
  // While we're not done with the root node
  if (stack->top <= 0) return 0;

  // Continue processing the children for the node at the top of the stack
  TidyNode cur = stack->stack[stack->top - 1];

  // If we've reached the end of the nodes at this level, pop the stack until
  // we find something not null.
  while (stack->top > 0 && !cur) cur = stack->stack[--stack->top - 1];

  // If cursor is still null, we're all done.
  if (!cur) return 0;

  // Otherwise, we've found our current node. Advance for this level.
  stack->stack[stack->top - 1] = tidyGetNext(cur);

  // If this is the start of a node, push to the stack before returning
  // the current node.
  if (tidyNodeGetType(cur) == TidyNode_Start)
    stack->stack[stack->top++] = tidyGetChild(cur);

  return cur;
}

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
  tidy_stack_t stack = {0};
  TidyNode stack_buf[MAX_DEPTH];
  stack.stack = stack_buf;
  stack.stack_len = MAX_DEPTH;
  stack.stack[stack.top++] = tidyGetChild(n);

  TidyNode cur;
  while ((cur = traverse(tdoc, &stack))) {
    switch (tidyNodeGetType(cur)) {
      case TidyNode_Text:
        tidyNodeGetText(tdoc, cur, &buf);
        LOG(": %.*s", buf.size - 1, buf.bp);
        tidyBufClear(&buf);
        break;
      case TidyNode_Start:
      case TidyNode_StartEnd:
        LOG("node %s", tidyNodeGetName(cur));
        for (TidyAttr attr = tidyAttrFirst(cur); attr; attr = tidyAttrNext(attr)) {
          LOG("     %s=%s", tidyAttrName(attr), tidyAttrValue(attr));
        }
        break;
    }
  }

  tidyBufFree(&buf);
  tidyRelease(tdoc);
  return 0;
}
