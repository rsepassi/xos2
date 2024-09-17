#include "base/log.h"
#include "base/file.h"

#include "archive.h"

#include "epub.h"

int main(int argc, char** argv) {
  CHECK(argc == 2, "pass epub");
  char* epub_fname = argv[1];
  LOG("epub=%s", epub_fname);

  // Read epub
  str_t epub_buf;
  CHECK_OK(fs_read_file(epub_fname, &epub_buf));

  // Initialize zip reader
  struct archive *a = archive_read_new();
  archive_read_support_format_zip(a);
  CHECK(archive_read_open_memory(a, epub_buf.bytes, epub_buf.len) == ARCHIVE_OK);

  // Parse epub
  epub_t epub;
  epub_init_from_archive(&epub, a);
  epub_parse_rootfile(&epub);
  epub_parse_toc(&epub);
  for (int i = 0; i < epub.spine.len; ++i) epub_parse_section(&epub, i);

  epub_deinit(&epub);
  archive_read_free(a);
  free((void*)epub_buf.bytes);
  return 0;
}

// TODO: need to ignore newlines in xhtml
