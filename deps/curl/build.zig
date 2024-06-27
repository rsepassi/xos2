const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const os = target.result.os.tag;

    const mbedtls = b.option([]const u8, "mbedtls", "mbedtls root");
    const brotli = b.option([]const u8, "brotli", "brotli root");
    const zlib = b.option([]const u8, "zlib", "zlib root");
    const zstd = b.option([]const u8, "zstd", "zstd root");
    const cares = b.option([]const u8, "cares", "cares root");

    const sysroot = b.option([]const u8, "sysroot", "platform sysroot");
    if (sysroot) |s| b.sysroot = s;

    const lib = b.addStaticLibrary(.{
        .name = "curl",
        .target = target,
        .optimize = optimize,
    });

    lib.defineCMacro("HAVE_CONFIG_H", null);
    lib.defineCMacro("BUILDING_LIBCURL", null);
    lib.defineCMacro("CURL_STATICLIB", null);
    lib.addIncludePath(.{ .path = "include" });
    lib.addIncludePath(.{ .path = "lib" });
    lib.addIncludePath(.{ .path = b.pathJoin(&.{ mbedtls.?, "include" }) });
    lib.addIncludePath(.{ .path = b.pathJoin(&.{ brotli.?, "include" }) });
    lib.addIncludePath(.{ .path = b.pathJoin(&.{ zlib.?, "include" }) });
    lib.addIncludePath(.{ .path = b.pathJoin(&.{ zstd.?, "include" }) });
    lib.addIncludePath(.{ .path = b.pathJoin(&.{ cares.?, "include" }) });
    lib.addCSourceFiles(.{ .files = &lib_src_files, .flags = &cflags });
    switch (os) {
        .macos => {
            lib.addFrameworkPath(.{ .path = b.pathJoin(&.{ b.sysroot.?, "System/Library/Frameworks" }) });
        },
        .freebsd => {
            lib.setLibCFile(.{ .path = b.pathJoin(&.{ b.sysroot.?, "libc.txt" }) });
        },
        else => {},
    }
    lib.linkLibC();
    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "curl",
        .target = target,
        .optimize = optimize,
        .linkage = if (os == .linux) .static else null,
        .strip = true,
    });
    exe.defineCMacro("HAVE_CONFIG_H", "1");
    exe.defineCMacro("BUILDING_CURL", null);
    exe.defineCMacro("CURL_STATICLIB", null);
    exe.addIncludePath(.{ .path = "include" });
    exe.addIncludePath(.{ .path = "lib" });
    exe.addIncludePath(.{ .path = "src" });
    exe.addCSourceFiles(.{ .files = &exe_src_files, .flags = &cflags });
    switch (os) {
        .macos => {
            exe.addIncludePath(.{ .path = b.pathJoin(&.{ b.sysroot.?, "usr/include" }) });
            exe.addLibraryPath(.{ .path = b.pathJoin(&.{ b.sysroot.?, "usr/lib" }) });
            exe.addFrameworkPath(.{ .path = b.pathJoin(&.{ b.sysroot.?, "System/Library/Frameworks" }) });
            exe.linkSystemLibrary("objc");
            exe.linkFramework("CoreFoundation");
            exe.linkFramework("SystemConfiguration");
        },
        .windows => {
            exe.linkSystemLibrary("bcrypt");
            exe.linkSystemLibrary("advapi32");
            exe.linkSystemLibrary("crypt32");
            exe.linkSystemLibrary("ws2_32");
            exe.linkSystemLibrary("iphlpapi");
        },
        .freebsd => {
            exe.setLibCFile(.{ .path = b.pathJoin(&.{ b.sysroot.?, "libc.txt" }) });
        },
        else => {},
    }

    const libprefix = switch (os) {
        .windows => "",
        else => "lib",
    };
    const libsuffix = switch (os) {
        .windows => "lib",
        else => "a",
    };

    exe.linkLibrary(lib);
    exe.addObjectFile(.{ .path = b.pathJoin(&.{
        mbedtls.?,
        b.fmt("lib/{s}mbedtls.{s}", .{ libprefix, libsuffix }),
    }) });
    exe.addObjectFile(.{ .path = b.pathJoin(&.{
        mbedtls.?,
        b.fmt("lib/{s}mbedcrypto.{s}", .{ libprefix, libsuffix }),
    }) });
    exe.addObjectFile(.{ .path = b.pathJoin(&.{
        mbedtls.?,
        b.fmt("lib/{s}mbedx509.{s}", .{ libprefix, libsuffix }),
    }) });
    exe.addObjectFile(.{ .path = b.pathJoin(&.{
        brotli.?,
        b.fmt("lib/{s}brotli.{s}", .{ libprefix, libsuffix }),
    }) });
    exe.addObjectFile(.{ .path = b.pathJoin(&.{
        zlib.?,
        b.fmt("lib/{s}z.{s}", .{ libprefix, libsuffix }),
    }) });
    exe.addObjectFile(.{ .path = b.pathJoin(&.{
        zstd.?,
        b.fmt("lib/{s}zstd.{s}", .{ libprefix, libsuffix }),
    }) });
    exe.addObjectFile(.{ .path = b.pathJoin(&.{
        cares.?,
        b.fmt("lib/{s}cares.{s}", .{ libprefix, libsuffix }),
    }) });
    exe.linkLibC();
    b.installArtifact(exe);
}

const cflags = [_][]const u8{
    "-Qunused-arguments",
    "-Wno-pointer-bool-conversion",
};

const lib_src_files = [_][]const u8{
    "lib/altsvc.c",
    "lib/amigaos.c",
    "lib/asyn-ares.c",
    "lib/asyn-thread.c",
    "lib/base64.c",
    "lib/bufq.c",
    "lib/bufref.c",
    "lib/c-hyper.c",
    "lib/cf-h1-proxy.c",
    "lib/cf-h2-proxy.c",
    "lib/cf-haproxy.c",
    "lib/cf-https-connect.c",
    "lib/cf-socket.c",
    "lib/cfilters.c",
    "lib/conncache.c",
    "lib/connect.c",
    "lib/content_encoding.c",
    "lib/cookie.c",
    "lib/curl_addrinfo.c",
    "lib/curl_des.c",
    "lib/curl_endian.c",
    "lib/curl_fnmatch.c",
    "lib/curl_get_line.c",
    "lib/curl_gethostname.c",
    "lib/curl_gssapi.c",
    "lib/curl_memrchr.c",
    "lib/curl_multibyte.c",
    "lib/curl_ntlm_core.c",
    "lib/curl_ntlm_wb.c",
    "lib/curl_path.c",
    "lib/curl_range.c",
    "lib/curl_rtmp.c",
    "lib/curl_sasl.c",
    "lib/curl_sspi.c",
    "lib/curl_threads.c",
    "lib/curl_trc.c",
    "lib/dict.c",
    "lib/doh.c",
    "lib/dynbuf.c",
    "lib/dynhds.c",
    "lib/easy.c",
    "lib/easygetopt.c",
    "lib/easyoptions.c",
    "lib/escape.c",
    "lib/file.c",
    "lib/fileinfo.c",
    "lib/fopen.c",
    "lib/formdata.c",
    "lib/ftp.c",
    "lib/ftplistparser.c",
    "lib/getenv.c",
    "lib/getinfo.c",
    "lib/gopher.c",
    "lib/hash.c",
    "lib/headers.c",
    "lib/hmac.c",
    "lib/hostasyn.c",
    "lib/hostip.c",
    "lib/hostip4.c",
    "lib/hostip6.c",
    "lib/hostsyn.c",
    "lib/hsts.c",
    "lib/http.c",
    "lib/http1.c",
    "lib/http2.c",
    "lib/http_aws_sigv4.c",
    "lib/http_chunks.c",
    "lib/http_digest.c",
    "lib/http_negotiate.c",
    "lib/http_ntlm.c",
    "lib/http_proxy.c",
    "lib/idn.c",
    "lib/if2ip.c",
    "lib/imap.c",
    "lib/inet_ntop.c",
    "lib/inet_pton.c",
    "lib/krb5.c",
    "lib/ldap.c",
    "lib/llist.c",
    "lib/macos.c",
    "lib/md4.c",
    "lib/md5.c",
    "lib/memdebug.c",
    "lib/mime.c",
    "lib/mprintf.c",
    "lib/mqtt.c",
    "lib/multi.c",
    "lib/netrc.c",
    "lib/nonblock.c",
    "lib/noproxy.c",
    "lib/openldap.c",
    "lib/parsedate.c",
    "lib/pingpong.c",
    "lib/pop3.c",
    "lib/progress.c",
    "lib/psl.c",
    "lib/rand.c",
    "lib/rename.c",
    "lib/rtsp.c",
    "lib/select.c",
    "lib/sendf.c",
    "lib/setopt.c",
    "lib/sha256.c",
    "lib/share.c",
    "lib/slist.c",
    "lib/smb.c",
    "lib/smtp.c",
    "lib/socketpair.c",
    "lib/socks.c",
    "lib/socks_gssapi.c",
    "lib/socks_sspi.c",
    "lib/speedcheck.c",
    "lib/splay.c",
    "lib/strcase.c",
    "lib/strdup.c",
    "lib/strerror.c",
    "lib/strtok.c",
    "lib/strtoofft.c",
    "lib/system_win32.c",
    "lib/telnet.c",
    "lib/tftp.c",
    "lib/timediff.c",
    "lib/timeval.c",
    "lib/transfer.c",
    "lib/url.c",
    "lib/urlapi.c",
    "lib/vauth/cleartext.c",
    "lib/vauth/cram.c",
    "lib/vauth/digest.c",
    "lib/vauth/digest_sspi.c",
    "lib/vauth/gsasl.c",
    "lib/vauth/krb5_gssapi.c",
    "lib/vauth/krb5_sspi.c",
    "lib/vauth/ntlm.c",
    "lib/vauth/ntlm_sspi.c",
    "lib/vauth/oauth2.c",
    "lib/vauth/spnego_gssapi.c",
    "lib/vauth/spnego_sspi.c",
    "lib/vauth/vauth.c",
    "lib/version.c",
    "lib/version_win32.c",
    "lib/vquic/curl_msh3.c",
    "lib/vquic/curl_ngtcp2.c",
    "lib/vquic/curl_osslq.c",
    "lib/vquic/curl_quiche.c",
    "lib/vquic/vquic-tls.c",
    "lib/vquic/vquic.c",
    "lib/vssh/libssh.c",
    "lib/vssh/libssh2.c",
    "lib/vssh/wolfssh.c",
    "lib/vtls/bearssl.c",
    "lib/vtls/gtls.c",
    "lib/vtls/hostcheck.c",
    "lib/vtls/keylog.c",
    "lib/vtls/mbedtls.c",
    "lib/vtls/mbedtls_threadlock.c",
    "lib/vtls/openssl.c",
    "lib/vtls/rustls.c",
    "lib/vtls/schannel.c",
    "lib/vtls/schannel_verify.c",
    "lib/vtls/sectransp.c",
    "lib/vtls/vtls.c",
    "lib/vtls/wolfssl.c",
    "lib/vtls/x509asn1.c",
    "lib/warnless.c",
    "lib/ws.c",
};

const exe_src_files = [_][]const u8{
    "src/tool_urlglob.c",
    "src/tool_stderr.c",
    "src/tool_paramhlp.c",
    "src/tool_cb_dbg.c",
    "src/tool_writeout.c",
    "src/tool_xattr.c",
    "src/tool_getpass.c",
    "src/tool_msgs.c",
    "src/tool_operate.c",
    "src/tool_bname.c",
    "src/tool_cb_hdr.c",
    "src/tool_easysrc.c",
    "src/tool_cb_wrt.c",
    "src/tool_progress.c",
    "src/tool_util.c",
    "src/tool_parsecfg.c",
    "src/tool_getparam.c",
    "src/tool_cb_see.c",
    "src/tool_cb_rea.c",
    "src/tool_doswin.c",
    "src/tool_formparse.c",
    "src/tool_strdup.c",
    "src/tool_hugehelp.c",
    "src/tool_sleep.c",
    "src/tool_dirhie.c",
    "src/tool_listhelp.c",
    "src/tool_libinfo.c",
    "src/tool_filetime.c",
    "src/tool_cb_prg.c",
    "src/tool_findfile.c",
    "src/tool_binmode.c",
    "src/tool_writeout_json.c",
    "src/tool_helpers.c",
    "src/var.c",
    "src/tool_help.c",
    "src/tool_vms.c",
    "src/tool_main.c",
    "src/tool_cfgable.c",
    "src/tool_operhlp.c",
    "src/tool_setopt.c",
    "src/slist_wc.c",
    "src/tool_ipfs.c",
    "lib/base64.c",
    "lib/dynbuf.c",
    // "lib/curl_multibyte.c",
    // "lib/nonblock.c",
    // "lib/strtoofft.c",
    // "lib/timediff.c",
    // "lib/version_win32.c",
    // "lib/warnless.c",
};
