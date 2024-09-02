#ifndef BASE_STR_H_
#define BASE_STR_H_

typedef struct {
  size_t len;
  const char* bytes;
} str_t;


#define str_init(s, l) ((str_t){.bytes = s, .len = l})
#define cstr(x) ((str_t){.bytes = x, .len = strlen(x)})

typedef struct list_s list_t;
inline str_t str_from_list(list_t l) {
  return (str_t){.bytes = l.base, .len = l.len};
}

#define str_append(list, s, len) do {\
    size_t l = (len); \
    memcpy(list_addn(uint8_t, (list), l), (s), l); \
  } while (0)

#endif
