var Url = "https://cdn.openbsd.org/pub/OpenBSD/LibreSSL/libressl-3.7.3.tar.gz"
var Hash = "7948c856a90c825bd7268b6f85674a8dcd254bae42e221781b24e3f8dc335db3"

var FetchSrc = Fn.new { |b| b.untar(b.fetch(Url, Hash)) }

var Cflags = [
  "-std=gnu99",
  "-fno-strict-aliasing",
  "-fno-strict-overflow",
  "-fstack-protector-strong",
]

var Defines = [
  "-DHAS_GNU_WARNING_LONG=1",
  "-DHAVE_ACCEPT4=1",
  "-DHAVE_ARPA_NAMESER_H=1",
  "-DHAVE_ASPRINTF=1",
  "-DHAVE_CLOCK_GETTIME=1",
  "-DHAVE_DLFCN_H=1",
  "-DHAVE_DL_ITERATE_PHDR=1",
  "-DHAVE_ENDIAN_H=1",
  "-DHAVE_ERR_H=1",
  "-DHAVE_EXPLICIT_BZERO=1",
  "-DHAVE_GETAUXVAL=1",
  "-DHAVE_GETAUXVAL=1",
  "-DHAVE_GNU_STACK",
  "-DHAVE_INTTYPES_H=1",
  "-DHAVE_MEMMEM=1",
  "-DHAVE_NETDB_H=1",
  "-DHAVE_NETINET_IN_H=1",
  "-DHAVE_NETINET_IP_H=1",
  "-DHAVE_PIPE2=1",
  "-DHAVE_POLL=1",
  "-DHAVE_REALLOCARRAY=1",
  "-DHAVE_RESOLV_H=1",
  "-DHAVE_SOCKETPAIR=1",
  "-DHAVE_STDINT_H=1",
  "-DHAVE_STDIO_H=1",
  "-DHAVE_STDLIB_H=1",
  "-DHAVE_STRINGS_H=1",
  "-DHAVE_STRING_H=1",
  "-DHAVE_STRLCAT=1",
  "-DHAVE_STRLCPY=1",
  "-DHAVE_STRNDUP=1",
  "-DHAVE_STRNLEN=1",
  "-DHAVE_STRSEP=1",
  "-DHAVE_SYMLINK=1",
  "-DHAVE_SYSLOG=1",
  "-DHAVE_SYS_STAT_H=1",
  "-DHAVE_SYS_TYPES_H=1",
  "-DHAVE_SYS_TYPES_H=1",
  "-DHAVE_TIMEGM=1",
  "-DHAVE_UNISTD_H=1",
  "-DHAVE_VA_COPY=1",
  "-DHAVE___VA_COPY=1",
  "-DLIBRESSL_CRYPTO_INTERNAL",
  "-DLIBRESSL_INTERNAL",
  "-DOPENSSLDIR=\"/etc/ssl\"",
  "-DOPENSSL_NO_ASM",
  "-DOPENSSL_NO_HW_PADLOCK",
  "-DPACKAGE=\"libressl\"",
  "-DPACKAGE_BUGREPORT=\"\"",
  "-DPACKAGE_NAME=\"libressl\"",
  "-DPACKAGE_STRING=\"libressl 3.7.3\"",
  "-DPACKAGE_TARNAME=\"libressl\"",
  "-DPACKAGE_URL=\"\"",
  "-DPACKAGE_VERSION=\"3.7.3\"",
  "-DSIZEOF_TIME_T=8",
  "-DSTDC_HEADERS=1",
  "-DVERSION=\"3.7.3\"",
  "-D_BSD_SOURCE",
  "-D_DEFAULT_SOURCE",
  "-D_FORTIFY_SOURCE=2",
  "-D_GNU_SOURCE",
  "-D_POSIX_SOURCE",
  "-D__BEGIN_HIDDEN_DECLS=",
  "-D__END_HIDDEN_DECLS=",
]

// CC="zig cc -target x86_64-linux-musl -lc" ./configure \
// --prefix=$PWD/xos \
// --host=x86_64-pc-linux-musl \
// --disable-asm \
// --disable-nc \
// --disable-tests \
// --disable-shared \
// --disable-dependency-tracking \
// --disable-silent-rules
