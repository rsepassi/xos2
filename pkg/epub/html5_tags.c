#include "html5_tags.h"

#include "base/khash.h"

KHASH_MAP_INIT_STR(mHtml5Tags, Html5TagType);
typedef khash_t(mHtml5Tags) html5_tagmap_t;

static html5_tagmap_t* html5_tagmap() {
 static html5_tagmap_t* tagmap = NULL;
 if (tagmap != NULL) return tagmap;

 html5_tagmap_t* h = kh_init(mHtml5Tags);
 kh_resize(mHtml5Tags, h, Html5Tag__SENTINEL);
 for (int i = 0; i < Html5Tag__SENTINEL; ++i) {
    int ret;
    khiter_t key = kh_put(mHtml5Tags, h, html5_tagstrs[i], &ret);
    kh_val(h, key) = i;
 }

 tagmap = h;
 return tagmap;
}

Html5TagType html5_tagmap_get(const char* tag) {
  html5_tagmap_t* h = html5_tagmap();
  khiter_t iter = kh_get(mHtml5Tags, h, tag);
  if (iter == kh_end(h)) return Html5Tag_UNKNOWN;
  return kh_val(h, iter);
}

char* html5_tagstrs[Html5Tag__SENTINEL] = {
  "UNKNOWN",
  "a",
  "abbr",
  "acronym",
  "address",
  "area",
  "article",
  "aside",
  "audio",
  "b",
  "base",
  "bdi",
  "bdo",
  "big",
  "blockquote",
  "body",
  "br",
  "button",
  "canvas",
  "caption",
  "center",
  "cite",
  "code",
  "col",
  "colgroup",
  "data",
  "datalist",
  "dd",
  "del",
  "details",
  "dfn",
  "dialog",
  "dir",
  "div",
  "dl",
  "dt",
  "em",
  "embed",
  "fencedframe",
  "fieldset",
  "figcaption",
  "figure",
  "font",
  "footer",
  "form",
  "frame",
  "frameset",
  "h1",
  "h2",
  "h3",
  "h4",
  "h5",
  "h6",
  "head",
  "header",
  "hgroup",
  "hr",
  "html",
  "i",
  "iframe",
  "img",
  "input",
  "ins",
  "kbd",
  "label",
  "legend",
  "li",
  "link",
  "main",
  "map",
  "mark",
  "marquee",
  "menu",
  "meta",
  "meter",
  "nav",
  "nobr",
  "noembed",
  "noframes",
  "noscript",
  "object",
  "ol",
  "optgroup",
  "option",
  "output",
  "p",
  "param",
  "picture",
  "plaintext",
  "portal",
  "pre",
  "progress",
  "q",
  "rb",
  "rp",
  "rt",
  "rtc",
  "ruby",
  "s",
  "samp",
  "script",
  "search",
  "section",
  "select",
  "slot",
  "small",
  "source",
  "span",
  "strike",
  "strong",
  "style",
  "sub",
  "summary",
  "sup",
  "table",
  "tbody",
  "td",
  "template",
  "textarea",
  "tfoot",
  "th",
  "thead",
  "time",
  "title",
  "tr",
  "track",
  "tt",
  "u",
  "ul",
  "var",
  "video",
  "wbr",
  "xmp",
};
