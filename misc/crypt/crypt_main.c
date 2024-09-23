#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "base/log.h"
#include "base/stdtypes.h"

#include "argparse.h"
#include "sodium.h"

#include "crypt.h"

#define SECRET_KEY_LEN 32
#define CHUNK_LEN 4096

#define ARRAY_SIZE(x) (sizeof(x) / sizeof(x[0]))

static const char *const keygen_usages[] = {
  "crypt keygen [options]",
  NULL,
};
static const char *const keyderive_usages[] = {
  "crypt keyderive --keyfile=<str> --path=<str> [options]",
  NULL,
};

static u8* read_key(const char* keyfile) {
  FILE* f = fopen(keyfile, "rb");
  fseek(f, 0, SEEK_END);
  CHECK(ftell(f) == SECRET_KEY_LEN, "keyfile must contain exactly %d bytes", SECRET_KEY_LEN);
  fseek(f, 0, SEEK_SET);
  u8* secret_buf = sodium_malloc(SECRET_KEY_LEN);
  CHECK(fread(secret_buf, 1, SECRET_KEY_LEN, f) == SECRET_KEY_LEN, "failed to read keyfile");
  sodium_mprotect_readonly(secret_buf);
  fclose(f);
  return secret_buf;
}

static void print_bytes(u8* key, int len, int hex) {
  if (hex) {
    // Print hex encoded key
    for (int i = 0; i < len; ++i) {
      if (i && (i % 4 == 0)) fprintf(stdout, "-");
      fprintf(stdout, "%02X", key[i]);
    }
    fprintf(stdout, "\n");
  } else {
    fwrite(key, 1, len, stdout);
  }
}

static char* pw_prompt() {
  char* password = malloc(512);

  fprintf(stdout, "Enter password: ");
  fflush(stdout);

  // Disable echo for password input
  system("stty -echo");

  if (fgets(password, sizeof(password), stdin) != NULL) {
    // Remove newline character if present
    size_t len = strlen(password);
    if (len > 0 && password[len - 1] == '\n') {
        password[len - 1] = '\0';
    }
  }

  // Re-enable echo
  system("stty echo");

  // Print a newline for better formatting
  printf("\n");

  return password;
}

static int cmd_pwcat(int argc, const char** argv) {
  char* path = NULL;
  char* pw = NULL;
  struct argparse_option options[] = {
    OPT_HELP(),
    OPT_STRING('f', "file", &path, "file to read", NULL, 0, 0),
    OPT_STRING('p', "pass", &pw, "password (will prompt if not provided)", NULL, 0, 0),
    OPT_END(),
  };
  struct argparse argparse;
  static const char *const usages[] = {
    "crypt pwcat --file=<str>",
    "crypt pwcat --file=<str> --pass=<str>",
    NULL,
  };
  argparse_init(&argparse, options, usages, 0);
  argc = argparse_parse(&argparse, argc, argv);
  if (path == NULL) {
    argparse_usage(&argparse);
    return -1;
  }


  if (pw == NULL) pw = pw_prompt();
  size_t pwlen = strlen(pw);
  u8* pw_buf = sodium_malloc(pwlen);
  memcpy(pw_buf, pw, pwlen);
  sodium_mprotect_readonly(pw_buf);
  sodium_memzero(pw, pwlen);

  CHECK(pwlen >= crypto_pwhash_PASSWD_MIN &&
      pwlen <= crypto_pwhash_PASSWD_MAX,
      "password must have length between %d and %d",
      crypto_pwhash_PASSWD_MIN,
      crypto_pwhash_PASSWD_MAX);

  FILE* f = fopen(path, "rb");
  CHECK(f);

  // Read our header
  // secretstream header: u8[crypto_secretstream_xchacha20poly1305_HEADERBYTES]
  // algo: u8
  // opslimit: u8
  // memlimit: u64
  // salt: u8[crypto_pwhash_SALTBYTES]
  // pwauth: u8[1 + crypto_secretstream_xchacha20poly1305_ABYTES]
  u8 header[crypto_secretstream_xchacha20poly1305_HEADERBYTES];
  u8 pwheader[1 + 1 + 8 + crypto_pwhash_SALTBYTES];
  u8 pwauth[1 + crypto_secretstream_xchacha20poly1305_ABYTES];

  fread(header, 1, crypto_secretstream_xchacha20poly1305_HEADERBYTES, f);
  fread(pwheader, 1, 1 + 1 + 8 + crypto_pwhash_SALTBYTES, f);
  fread(pwauth, 1, 1 + crypto_secretstream_xchacha20poly1305_ABYTES, f);
  sodium_mprotect_readonly(pwheader);
  sodium_mprotect_readonly(header);

  u8 algo = pwheader[0];
  u8 opslimit = pwheader[1];
  u64 memlimit = *(u64*)(&pwheader[2]);
  u8* salt_buf = &pwheader[10];

  // Rederive our encryption key
  u8* key_buf = sodium_malloc(crypto_secretstream_xchacha20poly1305_KEYBYTES);
  CHECK(crypto_pwhash(key_buf, crypto_secretstream_xchacha20poly1305_KEYBYTES,
        (const char*)pw_buf, pwlen, salt_buf,
        opslimit,
        memlimit,
        algo) == 0,
      "unable to derive a key from the password");
  sodium_mprotect_readonly(key_buf);
  sodium_free(pw_buf);

  // Streaming decrypt
  crypto_secretstream_xchacha20poly1305_state state;
  CHECK(crypto_secretstream_xchacha20poly1305_init_pull(&state, header, key_buf) == 0, "invalid header ");
  sodium_free(key_buf);

  u8 pwauth_check[1];
  CHECK(crypto_secretstream_xchacha20poly1305_pull(&state,
        pwauth_check, NULL,
        NULL,
        pwauth, sizeof(pwauth),
        pwheader, sizeof(pwheader)) == 0, "invalid decryption");

  // Read chunk -> decrypt -> print
  u8 msg_buf[CHUNK_LEN];
  u8 read_buf[CHUNK_LEN + crypto_secretstream_xchacha20poly1305_ABYTES];
  u64 read_size = CHUNK_LEN + crypto_secretstream_xchacha20poly1305_ABYTES;
  u8 tag;

  int len = read_size;
  while (tag != crypto_secretstream_xchacha20poly1305_TAG_FINAL &&
      len >= read_size) {
    len = fread(read_buf, 1, read_size, f);
    if (len < read_size) CHECK(ferror(f) == 0);
    CHECK(crypto_secretstream_xchacha20poly1305_pull(&state, msg_buf, NULL, &tag, read_buf, len, NULL, 0) == 0, "invalid decryption");
    fwrite(msg_buf, 1, len - crypto_secretstream_xchacha20poly1305_ABYTES, stdout);
  }
  fclose(f);
}

static int cmd_pwprotect(int argc, const char** argv) {
  char* path = NULL;
  char* pw = NULL;
  struct argparse_option options[] = {
    OPT_HELP(),
    OPT_STRING('f', "file", &path, "file to protect", NULL, 0, 0),
    OPT_STRING('p', "pass", &pw, "password (will prompt if not provided)", NULL, 0, 0),
    OPT_END(),
  };
  struct argparse argparse;
  static const char *const usages[] = {
    "crypt pwprotect --file=<str>",
    "crypt pwprotect --file=<str> --pass=<str>",
    NULL,
  };
  argparse_init(&argparse, options, usages, 0);
  argc = argparse_parse(&argparse, argc, argv);
  if (path == NULL) {
    argparse_usage(&argparse);
    return -1;
  }

  if (pw == NULL) pw = pw_prompt();
  size_t pwlen = strlen(pw);
  u8* pw_buf = sodium_malloc(pwlen);
  memcpy(pw_buf, pw, pwlen);
  sodium_mprotect_readonly(pw_buf);
  sodium_memzero(pw, pwlen);

  CHECK(pwlen >= crypto_pwhash_PASSWD_MIN &&
      pwlen <= crypto_pwhash_PASSWD_MAX,
      "password must have length between %d and %d",
      crypto_pwhash_PASSWD_MIN,
      crypto_pwhash_PASSWD_MAX);

  // Generate our salt
  u8* salt_buf = sodium_malloc(crypto_pwhash_SALTBYTES);
  randombytes_buf(salt_buf, crypto_pwhash_SALTBYTES);
  sodium_mprotect_readonly(salt_buf);

  // Derive an encryption key
  u8* key_buf = sodium_malloc(crypto_secretstream_xchacha20poly1305_KEYBYTES);

  u8 opslimit = 3;
  u64 memlimit = (1 << 20) * 16;
  u8 algo = crypto_pwhash_ALG_ARGON2ID13;
  CHECK(crypto_pwhash(key_buf, crypto_secretstream_xchacha20poly1305_KEYBYTES,
        (const char*)pw_buf, pwlen, salt_buf,
        opslimit,
        memlimit,
        algo) == 0,
      "unable to derive a key from the password");
  sodium_mprotect_readonly(key_buf);
  sodium_free(pw_buf);

  list_t tmp_path = list_init(u8, strlen(path) + 5);
  str_add(&tmp_path, cstr(path));
  str_add(&tmp_path, cstr(".tmp"));
  *list_add(u8, &tmp_path) = 0;

  // Streaming encrypt
  FILE* fin = fopen(path, "rb");
  CHECK(fin);
  FILE* fout = fopen((const char*)tmp_path.base, "wb");
  CHECK(fout);

  u8 header[crypto_secretstream_xchacha20poly1305_HEADERBYTES];
  crypto_secretstream_xchacha20poly1305_state state;
  crypto_secretstream_xchacha20poly1305_init_push(&state, header, key_buf);
  sodium_free(key_buf);

  // Construct and write our header
  // secretstream header: u8[crypto_secretstream_xchacha20poly1305_HEADERBYTES]
  // algo: u8
  // opslimit: u8
  // memlimit: u64
  // salt: u8[crypto_pwhash_SALTBYTES]
  // pwauth: u8[1 + crypto_secretstream_xchacha20poly1305_ABYTES]
  u8 pwheader[1 + 1 + 8 + crypto_pwhash_SALTBYTES];
  pwheader[0] = algo;
  pwheader[1] = opslimit;
  *(u64*)(&pwheader[2]) = memlimit;
  memcpy(&pwheader[10], salt_buf, crypto_pwhash_SALTBYTES);
  sodium_free(salt_buf);

  u8 pwauth[1 + crypto_secretstream_xchacha20poly1305_ABYTES];
  crypto_secretstream_xchacha20poly1305_push(&state, pwauth, NULL,
      "x", 1, pwheader, sizeof(pwheader), 0);

  fwrite(header, 1, crypto_secretstream_xchacha20poly1305_HEADERBYTES, fout);
  fwrite(pwheader, 1, sizeof(pwheader), fout);
  fwrite(pwauth, 1, 1 + crypto_secretstream_xchacha20poly1305_ABYTES, fout);

  // Read chunk -> encrypt -> write chunk
  u8 read_buf[CHUNK_LEN];
  u8 msg_buf[CHUNK_LEN + crypto_secretstream_xchacha20poly1305_ABYTES];
  int len = CHUNK_LEN;
  while (len >= CHUNK_LEN) {
    len = fread(read_buf, 1, CHUNK_LEN, fin);
    if (len < CHUNK_LEN) CHECK(ferror(fin) == 0);
    crypto_secretstream_xchacha20poly1305_push(&state, msg_buf, NULL,
        read_buf, len, NULL, 0,
        len < CHUNK_LEN ? crypto_secretstream_xchacha20poly1305_TAG_FINAL : 0);
    fwrite(msg_buf, 1, len + crypto_secretstream_xchacha20poly1305_ABYTES, fout);
  }

  fclose(fin);
  fclose(fout);

  CHECK(rename((const char*)tmp_path.base, path) == 0);
  list_deinit(&tmp_path);
}

static int cmd_keypairgen(int argc, const char** argv) {
  char* keyfile = NULL;
  char* path = NULL;
  int hex = 0;
  struct argparse_option options[] = {
    OPT_HELP(),
    OPT_STRING('k', "keyfile", &keyfile, "keyfile", NULL, 0, 0),
    OPT_STRING('p', "path", &path, "derivation path", NULL, 0, 0),
    OPT_BOOLEAN('x', "hex", &hex, "output as hex", NULL, 0, 0),
    OPT_END(),
  };
  struct argparse argparse;
  static const char *const usages[] = {
    "crypt keypairgen --keyfile=<str> --path=<str> [options]",
    NULL,
  };
  argparse_init(&argparse, options, usages, 0);
  argc = argparse_parse(&argparse, argc, argv);
  if (keyfile == NULL || path == NULL) {
    argparse_usage(&argparse);
    return -1;
  }

  u8* secret_buf = read_key(keyfile);

  CHECK(crypto_kdf_hkdf_sha256_KEYBYTES == SECRET_KEY_LEN);
  u8* seed_buf = sodium_malloc(crypto_box_SEEDBYTES);
  CHECK(crypto_kdf_hkdf_sha256_expand(
        seed_buf, crypto_box_SEEDBYTES,
        path, strlen(path),
        secret_buf) == 0, "derivation failed");
  sodium_mprotect_readonly(seed_buf);
  sodium_free((void*)secret_buf);

  u8 pk[crypto_box_PUBLICKEYBYTES];
  u8 sk[crypto_box_SECRETKEYBYTES];
  CHECK(crypto_box_seed_keypair(pk, sk, seed_buf) == 0, "keypair generation failed");
  sodium_free((void*)seed_buf);

  printf("pub:");
  print_bytes(pk, crypto_box_PUBLICKEYBYTES, hex);
  if (!hex) printf("\n");
  printf("sec:");
  print_bytes(sk, crypto_box_SECRETKEYBYTES, hex);
  if (!hex) printf("\n");
}

static int cmd_keyderive(int argc, const char** argv) {
  char* keyfile = NULL;
  char* path = NULL;
  int keylen = SECRET_KEY_LEN;
  int hex = 0;
  struct argparse_option options[] = {
    OPT_HELP(),
    OPT_STRING('k', "keyfile", &keyfile, "keyfile", NULL, 0, 0),
    OPT_STRING('p', "path", &path, "derivation path", NULL, 0, 0),
    OPT_BOOLEAN('n', "len", &keylen, "derived key length (defaults to key len)", NULL, 0, 0),
    OPT_BOOLEAN('x', "hex", &hex, "output as hex", NULL, 0, 0),
    OPT_END(),
  };
  struct argparse argparse;
  argparse_init(&argparse, options, keyderive_usages, 0);
  argc = argparse_parse(&argparse, argc, argv);
  if (keyfile == NULL || path == NULL) {
    argparse_usage(&argparse);
    return -1;
  }

  u8* secret_buf = read_key(keyfile);

  CHECK(crypto_kdf_hkdf_sha256_KEYBYTES == SECRET_KEY_LEN);
  u8* derived_buf = sodium_malloc(keylen);
  CHECK(crypto_kdf_hkdf_sha256_expand(
        derived_buf, keylen,
        path, strlen(path),
        secret_buf) == 0, "derivation failed");
  sodium_mprotect_readonly(derived_buf);
  sodium_free((void*)secret_buf);

  print_bytes(derived_buf, keylen, hex);

  sodium_free((void*)derived_buf);
}


static int cmd_keygen(int argc, const char** argv) {
  int hex = 0;
  struct argparse_option options[] = {
    OPT_HELP(),
    OPT_BOOLEAN('x', "hex", &hex, "as hex", NULL, 0, 0),
    OPT_END(),
  };
  struct argparse argparse;
  argparse_init(&argparse, options, keygen_usages, 0);
  argc = argparse_parse(&argparse, argc, argv);

  // Generate a secret key
  u8* secret_buf = sodium_malloc(SECRET_KEY_LEN);
  randombytes_buf(secret_buf, SECRET_KEY_LEN);
  sodium_mprotect_readonly(secret_buf);

  print_bytes(secret_buf, SECRET_KEY_LEN, hex);
  sodium_free((void*)secret_buf);
  return 0;
}

static const char *const usages[] = {
  "crypt [cmd] [options] [args]\ncmd = { keygen, keypairgen, keyderive, pwprotect, pwcat }",
  NULL,
};

static struct {
  const char *cmd;
  int (*fn) (int, const char **);
} commands[] = {
  {"keygen", cmd_keygen},
  {"keypairgen", cmd_keypairgen},
  {"keyderive", cmd_keyderive},
  {"pwprotect", cmd_pwprotect},
  {"pwcat", cmd_pwcat},
};

int main(int argc, const char** argv) {
  struct argparse argparse;
  struct argparse_option options[] = {
    OPT_HELP(),
    OPT_END(),
  };
  argparse_init(&argparse, options, usages, ARGPARSE_STOP_AT_NON_OPTION);
  argc = argparse_parse(&argparse, argc, argv);
  if (argc < 1) {
    argparse_usage(&argparse);
    return -1;
  }

  for (int i = 0; i < ARRAY_SIZE(commands); i++) {
    if (!strcmp(commands[i].cmd, argv[0])) {
      CHECK(sodium_init() == 0, "could not initialize libsodium");
      return commands[i].fn(argc, argv);
    }
  }

  argparse_usage(&argparse);
  return -1;
}
