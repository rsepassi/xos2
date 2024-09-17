#include "base/log.h"
#include "base/file.h"
#include "base/khash.h"
#include "base/str.h"
#include "base/allocator.h"
#include "base/stdtypes.h"

#include "epub.h"

#include "html5_tags.h"

#include "archive.h"
#include "archive_entry.h"

#include "tidy.h"
#include "tidybuffio.h"

KHASH_MAP_INIT_STRT(mStrToStr, str_t);

typedef khash_t(mStrToStr) smap_t;
void smap_put(smap_t* smap, str_t pathname, str_t contents) {
  int ret;
  khiter_t key = kh_put(mStrToStr, smap, pathname, &ret);
  kh_val(smap, key) = contents;
}
str_t* smap_get(smap_t* smap, str_t pathname) {
  khiter_t iter = kh_get(mStrToStr, smap, pathname);
  if (iter == kh_end(smap)) return 0;
  return &kh_val(smap, iter);
}
smap_t* smap_init() {
  return kh_init(mStrToStr);
}
void smap_deinit(smap_t* smap) {
  kh_destroy(mStrToStr, smap);
}

typedef struct {
  TidyDoc tdoc;
  TidyBuffer errbuf;
  TidyBuffer inbuf;
  TidyBuffer buf;
} xmlparser_t;

void xmlparser_init2(xmlparser_t* p, TidyOptionId opt) {
  *p = (xmlparser_t){0};
  p->tdoc = tidyCreate();
  if (opt > 0) tidyOptSetBool(p->tdoc, TidyXmlTags, 1);
  CHECK(tidySetErrorBuffer(p->tdoc, &p->errbuf) == 0);
  tidyBufInit(&p->buf);
}
void xmlparser_init(xmlparser_t* p) {
  xmlparser_init2(p, TidyXmlTags);
}
TidyNode xmlparser_parse(xmlparser_t* p, str_t in) {
  tidyBufAttach(&p->inbuf, (unsigned char*)in.bytes, in.len);
  CHECK(tidyParseBuffer(p->tdoc, &p->inbuf) < 2);
  return tidyGetRoot(p->tdoc);
}
void xmlparser_deinit(xmlparser_t* p) {
  tidyRelease(p->tdoc);
  tidyBufFree(&p->buf);
  tidyBufDetach(&p->inbuf);
}

str_t xmlparser_get_text(xmlparser_t* p, TidyNode cur) {
  tidyBufClear(&p->buf);
  tidyNodeGetText(p->tdoc, cur, &p->buf);
  return (str_t){.bytes = (const char*)p->buf.bp, .len = p->buf.size - 1};
}

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

typedef struct {
  smap_t* files;  // path -> contents
  smap_t* manifest;  // id -> path
  list_t spine;  // str_t ids
  str_t toc_id;
  epub_toc_t toc;
  // metadata, guide
} epub_t;

void epub_init(epub_t* e) {
  *e = (epub_t){0};
  e->files = smap_init();
  e->manifest = smap_init();
  e->spine = list_init(str_t, -1);
  e->toc.authors = list_init(str_t, -1);
  e->toc.nav.infos = list_init(str_t, 0);
  e->toc.nav.labels = list_init(str_t, 0);
  e->toc.nav.points = list_init(epub_navpoint_t, 16);
}

void list_str_deinit(list_t* x) {
  str_t* v;
  list_foreach(str_t, x, v, {
      free((void*)v->bytes);
  });
  list_deinit(x);
}

void list_navpoint_deinit(list_t* x) {
  epub_navpoint_t* v;
  list_foreach(epub_navpoint_t, x, v, {
    list_str_deinit(&v->labels);
    free((void*)v->content.bytes);
    list_navpoint_deinit(&v->points);
  });
  list_deinit(x);
}

void epub_deinit(epub_t* e) {
  {
    str_t k, v;
    kh_foreach(e->files, k, v, {
        free((void*)k.bytes);
        free((void*)v.bytes);
    });
    kh_foreach(e->manifest, k, v, {
        free((void*)k.bytes);
        free((void*)v.bytes);
    });
  }
  smap_deinit(e->files);
  smap_deinit(e->manifest);

  list_str_deinit(&e->spine);

  free((void*)e->toc.title.bytes);
  free((void*)e->toc_id.bytes);
  list_str_deinit(&e->toc.authors);

  list_str_deinit(&e->toc.nav.infos);
  list_str_deinit(&e->toc.nav.labels);

  list_navpoint_deinit(&e->toc.nav.points);
}

void epub_parse_metadata(epub_t* e, TidyNode n) {}
void epub_parse_guide(epub_t* e, TidyNode n) {}

void epub_parse_spine(epub_t* e, TidyNode cur) {
  CHECK(!e->toc_id.bytes);
  list_clear(&e->spine);

  for (TidyAttr attr = tidyAttrFirst(cur); attr; attr = tidyAttrNext(attr)) {
    if (strcmp(tidyAttrName(attr), "toc") == 0) {
      e->toc_id = str_copy(cstr(tidyAttrValue(attr)));
      break;
    }
  }
  CHECK(e->toc_id.bytes);

  for (cur = tidyGetChild(cur); cur; cur = tidyGetNext(cur)) {
    CHECK(strcmp(tidyNodeGetName(cur), "itemref") == 0);
    for (TidyAttr attr = tidyAttrFirst(cur); attr; attr = tidyAttrNext(attr)) {
      if (strcmp(tidyAttrName(attr), "idref") == 0) {
        *list_add(str_t, &e->spine) = str_copy(cstr(tidyAttrValue(attr)));
        break;
      }
    }
  }
}

str_t epub_parse_toc_text(xmlparser_t* x, TidyNode cur) {
  cur = tidyGetChild(cur);  // X -> <text>
  cur = tidyGetChild(cur);  // <text> -> text
  return str_copy(xmlparser_get_text(x, cur));
}

void epub_parse_toc_navpoint(epub_navpoint_t* np, xmlparser_t* x, TidyNode cur, str_t tocdir) {
  np->labels = list_init(str_t, 0);
  np->points = list_init(epub_navpoint_t, 8);

  // navPoint (navLabel+, content, navPoint*)
  for (cur = tidyGetChild(cur); cur; cur = tidyGetNext(cur)) {
    const char* name = tidyNodeGetName(cur);
    if (strcmp(name, "navLabel") == 0) {
      *list_add(str_t, &np->labels) = epub_parse_toc_text(x, cur);
    } else if (strcmp(name, "content") == 0) {
      for (TidyAttr attr = tidyAttrFirst(cur); attr; attr = tidyAttrNext(attr)) {
        if (strcmp(tidyAttrName(attr), "src") == 0) {
          const char* src = tidyAttrValue(attr);
          list_t path = list_init(u8, tocdir.len + 1 + strlen(src));
          str_add(&path, tocdir);
          str_add(&path, cstr("/"));
          str_add(&path, cstr(src));
          np->content = str_from_list(path);
          break;
        }
      }
    } else if (strcmp(name, "navPoint") == 0) {
      epub_parse_toc_navpoint(
        list_add(epub_navpoint_t, &np->points),
        x,
        cur,
        tocdir);
    }
  }
}

void epub_parse_toc_nav(epub_t* e, xmlparser_t* x, TidyNode cur, str_t tocdir) {
  epub_nav_t* nav = &e->toc.nav;

  // navMap (navInfo*, navLabel*, navPoint+)
  //
  // <!ATTLIST content
  //  src    %URI;    #REQUIRED
  //
  // remaining are all <text>

  for (cur = tidyGetChild(cur); cur; cur = tidyGetNext(cur)) {
    const char* name = tidyNodeGetName(cur);
    if (strcmp(name, "navInfo") == 0) {
      *list_add(str_t, &nav->infos) = epub_parse_toc_text(x, cur);
    } else if (strcmp(name, "navLabel") == 0) {
      *list_add(str_t, &nav->labels) = epub_parse_toc_text(x, cur);
    } else if (strcmp(name, "navPoint") == 0) {
      epub_parse_toc_navpoint(
        list_add(epub_navpoint_t, &nav->points),
        x,
        cur,
        tocdir);
    }
  }
}

void epub_parse_manifest(epub_t* e, TidyNode cur, str_t basedir) {
  CHECK((cur = tidyGetChild(cur)));  // manifest->
  for (; cur; cur = tidyGetNext(cur)) {
    CHECK(strcmp(tidyNodeGetName(cur), "item") == 0);
    const char* id = 0;
    const char* href = 0;
    for (TidyAttr attr = tidyAttrFirst(cur); attr; attr = tidyAttrNext(attr)) {
      if (strcmp(tidyAttrName(attr), "href") == 0) {
        href = tidyAttrValue(attr);
      } else if (strcmp(tidyAttrName(attr), "id") == 0) {
        id = tidyAttrValue(attr);
      }
    }
    CHECK(id);
    CHECK(href);

    list_t path = list_init(u8, basedir.len + 1 + strlen(href));
    str_add(&path, basedir);
    str_add(&path, cstr("/"));
    str_add(&path, cstr(href));

    smap_put(e->manifest, str_copy(cstr(id)), str_from_list(path));
  }
}

static inline void pindent(int indent) {
  for (int j = 0; j < indent; ++j) printf(" ");
}

void epub_print_navpoint(epub_navpoint_t* np, int indent) {
  str_t* v;
  list_foreach(str_t, &np->labels, v, {
    if (__i > 0) {
      printf(" %.*s", (int)v->len, v->bytes);
    } else {
      pindent(indent);
      printf("%.*s", (int)v->len, v->bytes);
    }
  });
  printf("\n");
  pindent(indent + 2);
  printf("%.*s\n", (int)np->content.len, np->content.bytes);

  epub_navpoint_t* c;
  list_foreach(epub_navpoint_t, &np->points, c, {
    epub_print_navpoint(c, indent + 4);
  });
}

void epub_parse_toc(epub_t* e) {
  str_t* toc_path = smap_get(e->manifest, e->toc_id);
  CHECK(toc_path, "no toc");
  str_t tocdir = fs_dirname(*toc_path);
  str_t* toc_contents = smap_get(e->files, *toc_path);
  CHECK(toc_contents, "%.*s not found", (int)toc_path->len, toc_path->bytes);
  LOG("toc %.*s len=%d", (int)e->toc_id.len, e->toc_id.bytes, (int)toc_contents->len);

  // ncx (head, docTitle, docAuthor*, navMap, pageList?, navList*)
  xmlparser_t x;
  xmlparser_init(&x);
  TidyNode root = xmlparser_parse(&x, *toc_contents);
  TidyNode cur = tidyGetChild(root);
  CHECK((cur = tidyGetNext(cur)));  // xml
  CHECK((cur = tidyGetChild(cur)));  // ncx ->
  for (; cur; cur = tidyGetNext(cur)) {
    const char* name = tidyNodeGetName(cur);
    if (strcmp(name, "docTitle") == 0) {
      CHECK(!e->toc.title.bytes);
      e->toc.title = epub_parse_toc_text(&x, cur);
    } else if (strcmp(name, "docAuthor") == 0) {
      *list_add(str_t, &e->toc.authors) = epub_parse_toc_text(&x, cur);
    } else if (strcmp(name, "navMap") == 0) {
      epub_parse_toc_nav(e, &x, cur, tocdir);
    }
  }
  LOG("toc title=%.*s", (int)e->toc.title.len, e->toc.title.bytes);
  {
    str_t* author;
    list_foreach(str_t, &e->toc.authors, author, {
      LOG("toc author=%.*s", (int)author->len, author->bytes);
    });
  }

  {
    LOG("toc nav:");
    str_t* v;
    list_foreach(str_t, &e->toc.nav.infos, v, {
        LOG("info=%.*s", (int)v->len, v->bytes);
    });
    list_foreach(str_t, &e->toc.nav.labels, v, {
        LOG("label=%.*s", (int)v->len, v->bytes);
    });
    epub_navpoint_t* np;
    list_foreach(epub_navpoint_t, &e->toc.nav.points, np, {
        epub_print_navpoint(np, 0);
    });
  }

  xmlparser_deinit(&x);
}

typedef enum {
  EpubNodeParagraph,
  EpubNodeHeading,
  EpubNodeTable,
} EpubNodeType;

typedef struct {
  EpubNodeType type;
  str_t contents;
  str_t id;
  union {
  } data;
} epub_node_t;

typedef struct {
  str_t title;
  list_t nodes;  // epub_node_t
} epub_section_t;

void epub_parse_xhtml_nodes(epub_section_t* section, xmlparser_t* x, TidyNode cur) {
  // TODO
  if (tidyNodeGetType(cur) == TidyNode_Text) {
    epub_node_t* p = list_add(epub_node_t, &section->nodes);
    p->type = EpubNodeParagraph;
    p->contents = xmlparser_get_text(x, cur);  // TODO: copy?
    return;
  }

  cur = tidyGetChild(cur);
  CHECK(cur);
  for (; cur; cur = tidyGetNext(cur)) {
      const char* name = tidyNodeGetName(cur);
      CHECK(name);
      Html5TagType type = html5_tagmap_get(name);

      switch (type) {
        // Section elements
        case Html5Tag_hgroup:
        case Html5Tag_address:
        case Html5Tag_article:
        case Html5Tag_aside:
        case Html5Tag_header:
        case Html5Tag_footer:
        case Html5Tag_main:
        case Html5Tag_nav:
        case Html5Tag_div:
        case Html5Tag_section:
        case Html5Tag_marquee:
          LOG("tag=section");
          epub_parse_xhtml_nodes(section, x, cur);
          break;

        // Headers
        case Html5Tag_h1:
        case Html5Tag_h2:
        case Html5Tag_h3:
        case Html5Tag_h4:
        case Html5Tag_h5:
        case Html5Tag_h6:
          LOG("tag=header");
          break;

        // Paragraphs
        case Html5Tag_p:
        case Html5Tag_blockquote:
        case Html5Tag_pre:
        case Html5Tag_plaintext:
          LOG("tag=paragraph");
          break;

        // Lists
        case Html5Tag_ul:
        case Html5Tag_ol:
        case Html5Tag_li:
        case Html5Tag_menu:
        case Html5Tag_dir:
          LOG("tag=list");
          break;

        // Inline
        case Html5Tag_a:
        case Html5Tag_abbr:
        case Html5Tag_b:
        case Html5Tag_br:
        case Html5Tag_cite:
        case Html5Tag_code:
        case Html5Tag_dfn:
        case Html5Tag_em:
        case Html5Tag_i:
        case Html5Tag_kbd:
        case Html5Tag_mark:
        case Html5Tag_q:
        case Html5Tag_s:
        case Html5Tag_samp:
        case Html5Tag_small:
        case Html5Tag_span:
        case Html5Tag_strong:
        case Html5Tag_sub:
        case Html5Tag_sup:
        case Html5Tag_u:
        case Html5Tag_var:
        case Html5Tag_wbr:
        case Html5Tag_acronym:
        case Html5Tag_big:
        case Html5Tag_center:
        case Html5Tag_nobr:
        case Html5Tag_strike:
        case Html5Tag_tt:
        case Html5Tag_xmp:
          LOG("tag=inline");
          break;

        // Table
        case Html5Tag_caption:
        case Html5Tag_col:
        case Html5Tag_colgroup:
        case Html5Tag_table:
        case Html5Tag_tbody:
        case Html5Tag_td:
        case Html5Tag_tfoot:
        case Html5Tag_th:
        case Html5Tag_tr:
        case Html5Tag_thead:
          LOG("tag=table");
          break;

        // Ignore
        default:
          LOG("tag skip = %s", html5_tagstrs[type]);
          break;
      }
  }
  LOG("-- end parse nodes");
}

void epub_parse_xhtml(str_t contents) {
  // TODO
  xmlparser_t p;
  xmlparser_init2(&p, 0);
  xmlparser_parse(&p, contents);

  epub_section_t section;

  TidyNode cur;
  TidyNode head = tidyGetHead(p.tdoc);
  if (head) {
    for (cur = tidyGetChild(head); cur; cur = tidyGetNext(cur)) {
      const char* name = tidyNodeGetName(cur);
      if (strcmp(name, "title") == 0) {
        section.title = str_copy(xmlparser_get_text(&p, tidyGetChild(cur)));
        break;
      }
    }
  }
  LOG("title=%.*s", (int)section.title.len, section.title.bytes);

  TidyNode body = tidyGetBody(p.tdoc);
  CHECK(body);
  epub_parse_xhtml_nodes(&section, &p, body);

  xmlparser_deinit(&p);
  LOG("-- end parse xhtml");
}

list_t read_entry(struct archive* a) {
  list_t contents = list_init(u8, 0);
  size_t bytes_read = 1;
  while (bytes_read > 0) {
    u32 chunk_size = 128;
    u8* buf = list_addn(u8, &contents, chunk_size);
    bytes_read = archive_read_data(a, buf, chunk_size);
    contents.len -= (chunk_size - bytes_read);
  }
  return contents;
}

int main(int argc, char** argv) {
  CHECK(argc == 2, "pass epub");
  char* epub_fname = argv[1];
  LOG("epub=%s", epub_fname);

  str_t epub_buf;
  CHECK_OK(fs_read_file(epub_fname, &epub_buf));

  struct archive *a = archive_read_new();
  archive_read_support_format_zip(a);
  CHECK(archive_read_open_memory(a, epub_buf.bytes, epub_buf.len) == ARCHIVE_OK);

  struct {
    bool container_found;
    bool mimetype_found;
    str_t rootfile_path;
  } read_state = {0};

  epub_t epub;
  epub_init(&epub);
  smap_t* files = epub.files;

  struct archive_entry* entry;
  while (archive_read_next_header(a, &entry) == ARCHIVE_OK) {
    const char* pathname = archive_entry_pathname(entry);
    if (strcmp(pathname, "mimetype") == 0) {
      read_state.mimetype_found = true;
      list_t contents = read_entry(a);
      LOG("mimetype=%.*s", (int)contents.len, contents.base);
      char* expected_mimetype = "application/epub+zip";
      CHECK(strncmp(expected_mimetype, (const char*)contents.base, contents.len) == 0);
      list_deinit(&contents);
    } else if (strcmp(pathname, "META-INF/container.xml") == 0) {
      read_state.container_found = true;
      list_t contents = read_entry(a);

      xmlparser_t xmlparser;
      xmlparser_init(&xmlparser);
      TidyNode root = xmlparser_parse(&xmlparser, str_from_list(contents));
      TidyNode cur = tidyGetChild(root);
      CHECK((cur = tidyGetNext(cur)));   // xml declaration
      CHECK((cur = tidyGetChild(cur)));  // container -> rootfiles
      CHECK((cur = tidyGetChild(cur)));  // rootfiles -> rootfile
      CHECK(strcmp(tidyNodeGetName(cur), "rootfile") == 0);
      for (TidyAttr attr = tidyAttrFirst(cur); attr; attr = tidyAttrNext(attr)) {
        if (strcmp(tidyAttrName(attr), "full-path") == 0) {
          const char* rootfile_path = tidyAttrValue(attr);
          read_state.rootfile_path = str_copy(cstr(rootfile_path));
          LOG("rootfile=%.*s", (int)read_state.rootfile_path.len, read_state.rootfile_path.bytes);
        }
      }
      xmlparser_deinit(&xmlparser);
      list_deinit(&contents);
    } else {
      list_t contents = read_entry(a);
      smap_put(files, str_copy(cstr(pathname)), str_from_list(contents));
    }
  }

  CHECK(read_state.mimetype_found);
  CHECK(read_state.container_found);

  str_t* rootfile = smap_get(files, read_state.rootfile_path);
  CHECK(rootfile);

  {
    str_t basedir = fs_dirname(read_state.rootfile_path);
    LOG("basedir=%.*s", (int)basedir.len, basedir.bytes);

    xmlparser_t xmlparser;
    xmlparser_init(&xmlparser);
    TidyNode root = xmlparser_parse(&xmlparser, *rootfile);
    TidyNode cur = tidyGetChild(root);
    CHECK((cur = tidyGetNext(cur)));   // xml declaration
    CHECK(strcmp(tidyNodeGetName(cur), "package") == 0);
    CHECK((cur = tidyGetChild(cur)));  // package ->
    for (; cur; cur = tidyGetNext(cur)) {
      const char* name = tidyNodeGetName(cur);
      if (strcmp(name, "metadata") == 0) {
        epub_parse_metadata(&epub, cur);
      } else if (strcmp(name, "manifest") == 0) {
        epub_parse_manifest(&epub, cur, basedir);
      } else if (strcmp(name, "spine") == 0) {
        epub_parse_spine(&epub, cur);
      } else if (strcmp(name, "guide") == 0) {
        epub_parse_guide(&epub, cur);
      }
    }
    epub_parse_toc(&epub);

    xmlparser_deinit(&xmlparser);
    LOG("files n=%d", (int)files->size);
    LOG("manifest n=%d", (int)epub.manifest->size);
    LOG("spine n=%d", (int)epub.spine.len);

    str_t* id;
    list_foreach(str_t, &epub.spine, id, {
      str_t* path = smap_get(epub.manifest, *id);
      CHECK(path);
      str_t* contents = smap_get(files, *path);
      CHECK(contents, "%.*s not found", (int)path->len, path->bytes);
      LOG("%.*s len=%d", (int)id->len, id->bytes, (int)contents->len);

      // TODO: rm
      if (__i == 5) {
        LOG("--> contents");
        epub_parse_xhtml(*contents);
      }

    });
  }

  free((void*)read_state.rootfile_path.bytes);
  epub_deinit(&epub);
  archive_read_free(a);
  free((void*)epub_buf.bytes);
  return 0;
}
