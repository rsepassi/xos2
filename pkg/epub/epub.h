#ifndef EPUB_H_
#define EPUB_H_

#include "base/str.h"
#include "base/list.h"

struct archive;

typedef struct {
  list_t labels;  // str_t
  str_t content;
  list_t points;  // epub_navpoint_t
} epub_navpoint_t;

typedef struct {
  list_t infos;  // str_t
  list_t labels;  // str_t
  list_t points;  // epub_navpoint_t
} epub_nav_t;

typedef struct {
  str_t title;
  list_t authors;  // str_t
  epub_nav_t nav;
} epub_toc_t;

typedef enum {
  EpubNode_NONE,
  EpubNodeParagraph,
  EpubNodeHeading,
  EpubNode__SENTINEL,
} EpubNodeType;

typedef struct {
  EpubNodeType type;
  list_t contents;  // u8
  union {
  } data;
} epub_node_t;

typedef struct {
  str_t title;
  list_t nodes;  // epub_node_t
} epub_section_t;

typedef struct {
  str_map_t* files;  // path -> contents
  str_t rootfile_path;

  str_map_t* manifest;  // id -> path
  list_t spine;  // str_t ids
  str_t toc_id;

  epub_toc_t toc;
  list_t sections;  // epub_section_t
  // metadata, guide
} epub_t;

// Fills in files, rootfile_path
void epub_init_from_archive(epub_t* e, struct archive* a);
// Fills in manifest, spine, toc_id
void epub_parse_rootfile(epub_t* e);
// Fills in toc
void epub_parse_toc(epub_t* e);
// Fills in sections
void epub_parse_section(epub_t* e, int i);
// Releases all associated memory
void epub_deinit(epub_t* e);

#endif
