import "os" for Process
import "io" for File

var Url = "https://cdn.openbsd.org/pub/OpenBSD/LibreSSL/libressl-3.9.2.tar.gz"
var Hash = "7b031dac64a59eb6ee3304f7ffb75dad33ab8c9d279c847f92c89fb846068f97"

var crypto = Fn.new { |b, args|
  Process.chdir(b.untar(b.fetch(Url, Hash)))
  var zig = b.deptool("//toolchains/zig")
  var c_srcs = CryptoSrcs

  var libcrypto = zig.buildLib(b, "crypto", {
    "flags": Defines + CryptoIncludes + CryptoArch[b.target.arch]["flags"],
    "c_flags": [
      "-std=gnu99",
      "-fno-strict-aliasing",
      "-fno-strict-overflow",
      "-fstack-protector-strong",
    ],
    "c_srcs": c_srcs + CryptoArch[b.target.arch]["srcs"] + CryptoCompatSrcs.call(b),
    "libc": true,
  })

  b.installLib(libcrypto)

}

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
  "-DHAVE_GETOPT=1",
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
  "-DHAVE_STRCASECMP=1",
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
  "-DPACKAGE=\"libressl\"",
  "-DPACKAGE_BUGREPORT=\"\"",
  "-DPACKAGE_NAME=\"libressl\"",
  "-DPACKAGE_STRING=\"libressl 3.9.2\"",
  "-DPACKAGE_TARNAME=\"libressl\"",
  "-DPACKAGE_URL=\"\"",
  "-DPACKAGE_VERSION=\"3.9.2\"",
  "-DSIZEOF_TIME_T=8",
  "-DSTDC_HEADERS=1",
  "-DVERSION=\"3.9.2\"",
  "-D_BSD_SOURCE",
  "-D_DEFAULT_SOURCE",
  "-D_FORTIFY_SOURCE=2",
  "-D_GNU_SOURCE",
  "-D_POSIX_SOURCE",
  "-D__BEGIN_HIDDEN_DECLS=",
  "-D__END_HIDDEN_DECLS=",
]

var CryptoIncludes = [
  "-Icrypto",
  "-Icrypto/asn1",
  "-Icrypto/bio",
  "-Icrypto/bn",
  "-Icrypto/bn/arch/aarch64/",
  "-Icrypto/bytestring",
  "-Icrypto/curve25519",
  "-Icrypto/dh",
  "-Icrypto/dsa",
  "-Icrypto/ec",
  "-Icrypto/ecdh",
  "-Icrypto/ecdsa",
  "-Icrypto/evp",
  "-Icrypto/hidden",
  "-Icrypto/hmac",
  "-Icrypto/lhash",
  "-Icrypto/modes",
  "-Icrypto/ocsp",
  "-Icrypto/pkcs12",
  "-Icrypto/rsa",
  "-Icrypto/sha",
  "-Icrypto/stack",
  "-Icrypto/x509",
  "-Iinclude",
  "-Iinclude/compat",
]

var CryptoArch = {
  "aarch64": {
    "flags": [
      "-Icrypto/bn-arch/aarch64",
      "-DOPENSSL_NO_ASM ",
      "-DOPENSSL_NO_HW_PADLOCK",
      "-D__ARM_ARCH_8A__=1",
    ],
    "srcs": [
      "crypto/armcap.c",
    ],
  },
  "x86_64": {
    "flags": [
      "-Icrypto/bn-arch/amd64",
      "-DOPENSSL_NO_ASM ",
    ],
    "srcs": [
    ],
  },
}

var CryptoCompatSrcs = Fn.new { |b|
  var compat = [
    "crypto/compat/syslog_r.c",
    "crypto/compat/arc4random.c",
    "crypto/compat/freezero.c",
    "crypto/compat/strtonum.c",
    "crypto/compat/timingsafe_bcmp.c",
    "crypto/compat/timingsafe_memcmp.c",
    "crypto/compat/recallocarray.c",
  ]

  var unix_srcs = [
    "crypto/crypto_lock.c",
    "crypto/bio/b_posix.c",
    "crypto/bio/bss_log.c",
    "crypto/ui/ui_openssl.c",
  ]

  var linux_srcs = [
    "crypto/compat/getprogname_linux.c",
  ]

  var win_srcs = [
    "crypto/compat/crypto_lock_win.c",
    "crypto/compat/getprogname_windows.c",
    "crypto/bio/b_win.c",
    "crypto/ui/ui_openssl_win.c",
    "crypto/compat/posix_win.c",

  ]

  if (b.target.os == "windows") return compat + win_srcs
  if (b.target.os == "linux") return compat + unix_srcs + linux_srcs

  Fiber.abort("platform unimpl")
}

var CryptoSrcs = [
  "crypto/dsa/dsa_ossl.c",
  "crypto/dsa/dsa_lib.c",
  "crypto/dsa/dsa_ameth.c",
  "crypto/dsa/dsa_gen.c",
  "crypto/dsa/dsa_key.c",
  "crypto/dsa/dsa_pmeth.c",
  "crypto/dsa/dsa_prn.c",
  "crypto/dsa/dsa_err.c",
  "crypto/dsa/dsa_meth.c",
  "crypto/dsa/dsa_asn1.c",
  "crypto/asn1/a_strnid.c",
  "crypto/asn1/a_strex.c",
  "crypto/asn1/x_algor.c",
  "crypto/asn1/asn_mime.c",
  "crypto/asn1/a_time_posix.c",
  "crypto/asn1/asn1_lib.c",
  "crypto/asn1/tasn_new.c",
  "crypto/asn1/p8_pkey.c",
  "crypto/asn1/x_pubkey.c",
  "crypto/asn1/a_bitstr.c",
  "crypto/asn1/asn_moid.c",
  "crypto/asn1/tasn_typ.c",
  "crypto/asn1/x_info.c",
  "crypto/asn1/x_x509.c",
  "crypto/asn1/x_spki.c",
  "crypto/asn1/tasn_fre.c",
  "crypto/asn1/asn1_gen.c",
  "crypto/asn1/x_name.c",
  "crypto/asn1/p5_pbe.c",
  "crypto/asn1/x_long.c",
  "crypto/asn1/a_pubkey.c",
  "crypto/asn1/a_string.c",
  "crypto/asn1/t_x509a.c",
  "crypto/asn1/asn1_old_lib.c",
  "crypto/asn1/a_print.c",
  "crypto/asn1/tasn_dec.c",
  "crypto/asn1/x_attrib.c",
  "crypto/asn1/a_mbstr.c",
  "crypto/asn1/x_pkey.c",
  "crypto/asn1/tasn_enc.c",
  "crypto/asn1/t_x509.c",
  "crypto/asn1/tasn_prn.c",
  "crypto/asn1/bio_asn1.c",
  "crypto/asn1/a_type.c",
  "crypto/asn1/a_time_tm.c",
  "crypto/asn1/x_exten.c",
  "crypto/asn1/asn1_item.c",
  "crypto/asn1/a_time.c",
  "crypto/asn1/x_sig.c",
  "crypto/asn1/a_enum.c",
  "crypto/asn1/t_crl.c",
  "crypto/asn1/asn1_err.c",
  "crypto/asn1/a_object.c",
  "crypto/asn1/bio_ndef.c",
  "crypto/asn1/t_req.c",
  "crypto/asn1/a_pkey.c",
  "crypto/asn1/x_x509a.c",
  "crypto/asn1/x_bignum.c",
  "crypto/asn1/p5_pbev2.c",
  "crypto/asn1/x_req.c",
  "crypto/asn1/tasn_utl.c",
  "crypto/asn1/asn1_old.c",
  "crypto/asn1/a_utf8.c",
  "crypto/asn1/a_int.c",
  "crypto/asn1/t_spki.c",
  "crypto/asn1/asn1_par.c",
  "crypto/asn1/a_octet.c",
  "crypto/asn1/x_crl.c",
  "crypto/asn1/asn1_types.c",
  "crypto/asn1/x_val.c",
  "crypto/cryptlib.c",
  "crypto/crypto_init.c",
  "crypto/txt_db/txt_db.c",
  "crypto/pkcs12/p12_attr.c",
  "crypto/pkcs12/p12_key.c",
  "crypto/pkcs12/p12_init.c",
  "crypto/pkcs12/pk12err.c",
  "crypto/pkcs12/p12_decr.c",
  "crypto/pkcs12/p12_asn.c",
  "crypto/pkcs12/p12_crt.c",
  "crypto/pkcs12/p12_p8e.c",
  "crypto/pkcs12/p12_npas.c",
  "crypto/pkcs12/p12_kiss.c",
  "crypto/pkcs12/p12_utl.c",
  "crypto/pkcs12/p12_sbag.c",
  "crypto/pkcs12/p12_p8d.c",
  "crypto/pkcs12/p12_add.c",
  "crypto/pkcs12/p12_mutl.c",
  "crypto/err/err_prn.c",
  "crypto/err/err.c",
  "crypto/err/err_all.c",
  "crypto/md5/md5.c",
  "crypto/hmac/hm_pmeth.c",
  "crypto/hmac/hm_ameth.c",
  "crypto/hmac/hmac.c",
  "crypto/cmac/cmac.c",
  "crypto/cmac/cm_ameth.c",
  "crypto/cmac/cm_pmeth.c",
  "crypto/engine/engine_stubs.c",
  "crypto/kdf/hkdf_evp.c",
  "crypto/kdf/kdf_err.c",
  "crypto/mem_dbg.c",
  "crypto/cast/c_cfb64.c",
  "crypto/cast/c_ofb64.c",
  "crypto/cast/c_skey.c",
  "crypto/cast/c_enc.c",
  "crypto/cast/c_ecb.c",
  "crypto/curve25519/curve25519-generic.c",
  "crypto/curve25519/curve25519.c",
  "crypto/stack/stack.c",
  "crypto/pem/pem_err.c",
  "crypto/pem/pem_xaux.c",
  "crypto/pem/pem_pkey.c",
  "crypto/pem/pem_pk8.c",
  "crypto/pem/pem_x509.c",
  "crypto/pem/pem_lib.c",
  "crypto/pem/pvkfmt.c",
  "crypto/pem/pem_info.c",
  "crypto/pem/pem_all.c",
  "crypto/pem/pem_oth.c",
  "crypto/pem/pem_sign.c",
  "crypto/hkdf/hkdf.c",
  "crypto/ec/ec_kmeth.c",
  "crypto/ec/ec_asn1.c",
  "crypto/ec/eck_prn.c",
  "crypto/ec/ecx_methods.c",
  "crypto/ec/ecp_oct.c",
  "crypto/ec/ec_oct.c",
  "crypto/ec/ec_cvt.c",
  "crypto/ec/ec_err.c",
  "crypto/ec/ec_ameth.c",
  "crypto/ec/ec_check.c",
  "crypto/ec/ec_mult.c",
  "crypto/ec/ec_key.c",
  "crypto/ec/ec_print.c",
  "crypto/ec/ec_lib.c",
  "crypto/ec/ecp_smpl.c",
  "crypto/ec/ec_pmeth.c",
  "crypto/ec/ec_curve.c",
  "crypto/ec/ecp_mont.c",
  "crypto/whrlpool/wp_block.c",
  "crypto/whrlpool/wp_dgst.c",
  "crypto/sha/sha3.c",
  "crypto/sha/sha1.c",
  "crypto/sha/sha256.c",
  "crypto/sha/sha512.c",
  "crypto/pkcs7/pk7_smime.c",
  "crypto/pkcs7/pk7_attr.c",
  "crypto/pkcs7/pkcs7err.c",
  "crypto/pkcs7/pk7_lib.c",
  "crypto/pkcs7/pk7_asn1.c",
  "crypto/pkcs7/pk7_doit.c",
  "crypto/pkcs7/pk7_mime.c",
  "crypto/ui/ui_err.c",
  "crypto/ui/ui_openssl.c",
  "crypto/ui/ui_util.c",
  "crypto/ui/ui_null.c",
  "crypto/ui/ui_lib.c",
  "crypto/o_str.c",
  "crypto/bio/bss_mem.c",
  "crypto/bio/bss_bio.c",
  "crypto/bio/bio_lib.c",
  "crypto/bio/bss_acpt.c",
  "crypto/bio/bf_buff.c",
  "crypto/bio/bss_conn.c",
  "crypto/bio/bf_nbio.c",
  "crypto/bio/bio_meth.c",
  "crypto/bio/b_posix.c",
  "crypto/bio/bio_cb.c",
  "crypto/bio/bss_log.c",
  "crypto/bio/bss_sock.c",
  "crypto/bio/b_print.c",
  "crypto/bio/b_sock.c",
  "crypto/bio/b_dump.c",
  "crypto/bio/bss_null.c",
  "crypto/bio/bf_null.c",
  "crypto/bio/bss_fd.c",
  "crypto/bio/bss_file.c",
  "crypto/bio/bss_dgram.c",
  "crypto/bio/bio_err.c",
  "crypto/ts/ts_req_print.c",
  "crypto/ts/ts_err.c",
  "crypto/ts/ts_rsp_print.c",
  "crypto/ts/ts_req_utils.c",
  "crypto/ts/ts_lib.c",
  "crypto/ts/ts_asn1.c",
  "crypto/ts/ts_conf.c",
  "crypto/ts/ts_verify_ctx.c",
  "crypto/ts/ts_rsp_sign.c",
  "crypto/ts/ts_rsp_utils.c",
  "crypto/ts/ts_rsp_verify.c",
  "crypto/rsa/rsa_pmeth.c",
  "crypto/rsa/rsa_blinding.c",
  "crypto/rsa/rsa_oaep.c",
  "crypto/rsa/rsa_pss.c",
  "crypto/rsa/rsa_gen.c",
  "crypto/rsa/rsa_asn1.c",
  "crypto/rsa/rsa_lib.c",
  "crypto/rsa/rsa_chk.c",
  "crypto/rsa/rsa_x931.c",
  "crypto/rsa/rsa_pk1.c",
  "crypto/rsa/rsa_eay.c",
  "crypto/rsa/rsa_meth.c",
  "crypto/rsa/rsa_err.c",
  "crypto/rsa/rsa_prn.c",
  "crypto/rsa/rsa_none.c",
  "crypto/rsa/rsa_saos.c",
  "crypto/rsa/rsa_sign.c",
  "crypto/rsa/rsa_ameth.c",
  "crypto/bytestring/bs_ber.c",
  "crypto/bytestring/bs_cbb.c",
  "crypto/bytestring/bs_cbs.c",
  "crypto/poly1305/poly1305.c",
  "crypto/idea/i_ofb64.c",
  "crypto/idea/i_cfb64.c",
  "crypto/idea/i_skey.c",
  "crypto/idea/i_ecb.c",
  "crypto/idea/i_cbc.c",
  "crypto/bf/bf_ecb.c",
  "crypto/bf/bf_ofb64.c",
  "crypto/bf/bf_skey.c",
  "crypto/bf/bf_enc.c",
  "crypto/bf/bf_cfb64.c",
  "crypto/rc4/rc4_enc.c",
  "crypto/rc4/rc4_skey.c",
  "crypto/ecdsa/ecdsa.c",
  "crypto/mem_clr.c",
  "crypto/ripemd/ripemd.c",
  "crypto/aes/aes_ctr.c",
  "crypto/aes/aes_cfb.c",
  "crypto/aes/aes_ecb.c",
  "crypto/aes/aes_wrap.c",
  "crypto/aes/aes_ofb.c",
  "crypto/aes/aes_core.c",
  "crypto/aes/aes_cbc.c",
  "crypto/aes/aes_ige.c",
  "crypto/ocsp/ocsp_err.c",
  "crypto/ocsp/ocsp_prn.c",
  "crypto/ocsp/ocsp_srv.c",
  "crypto/ocsp/ocsp_cl.c",
  "crypto/ocsp/ocsp_ext.c",
  "crypto/ocsp/ocsp_vfy.c",
  "crypto/ocsp/ocsp_lib.c",
  "crypto/ocsp/ocsp_ht.c",
  "crypto/ocsp/ocsp_asn.c",
  "crypto/rand/randfile.c",
  "crypto/rand/rand_err.c",
  "crypto/rand/rand_lib.c",
  "crypto/sm3/sm3.c",
  "crypto/malloc-wrapper.c",
  "crypto/ct/ct_err.c",
  "crypto/ct/ct_policy.c",
  "crypto/ct/ct_log.c",
  "crypto/ct/ct_x509v3.c",
  "crypto/ct/ct_sct_ctx.c",
  "crypto/ct/ct_vfy.c",
  "crypto/ct/ct_sct.c",
  "crypto/ct/ct_prn.c",
  "crypto/ct/ct_b64.c",
  "crypto/ct/ct_oct.c",
  "crypto/evp/p_legacy.c",
  "crypto/evp/m_md4.c",
  "crypto/evp/m_sigver.c",
  "crypto/evp/bio_b64.c",
  "crypto/evp/evp_pkey.c",
  "crypto/evp/e_rc4.c",
  "crypto/evp/evp_err.c",
  "crypto/evp/m_sha1.c",
  "crypto/evp/m_null.c",
  "crypto/evp/e_xcbc_d.c",
  "crypto/evp/e_camellia.c",
  "crypto/evp/e_chacha.c",
  "crypto/evp/e_idea.c",
  "crypto/evp/e_cast.c",
  "crypto/evp/e_chacha20poly1305.c",
  "crypto/evp/e_null.c",
  "crypto/evp/m_ripemd.c",
  "crypto/evp/e_bf.c",
  "crypto/evp/m_sm3.c",
  "crypto/evp/p_verify.c",
  "crypto/evp/evp_encode.c",
  "crypto/evp/bio_enc.c",
  "crypto/evp/e_des.c",
  "crypto/evp/m_md5.c",
  "crypto/evp/p_sign.c",
  "crypto/evp/evp_cipher.c",
  "crypto/evp/evp_key.c",
  "crypto/evp/e_aes.c",
  "crypto/evp/e_rc2.c",
  "crypto/evp/p_lib.c",
  "crypto/evp/pmeth_gn.c",
  "crypto/evp/evp_digest.c",
  "crypto/evp/m_md5_sha1.c",
  "crypto/evp/pmeth_fn.c",
  "crypto/evp/evp_pbe.c",
  "crypto/evp/e_sm4.c",
  "crypto/evp/m_wp.c",
  "crypto/evp/bio_md.c",
  "crypto/evp/e_des3.c",
  "crypto/evp/evp_aead.c",
  "crypto/evp/evp_names.c",
  "crypto/evp/m_sha3.c",
  "crypto/evp/pmeth_lib.c",
  "crypto/ex_data.c",
  "crypto/camellia/cmll_ctr.c",
  "crypto/camellia/cmll_ecb.c",
  "crypto/camellia/cmll_ofb.c",
  "crypto/camellia/cmll_cfb.c",
  "crypto/camellia/cmll_misc.c",
  "crypto/camellia/camellia.c",
  "crypto/camellia/cmll_cbc.c",
  "crypto/dh/dh_gen.c",
  "crypto/dh/dh_asn1.c",
  "crypto/dh/dh_check.c",
  "crypto/dh/dh_err.c",
  "crypto/dh/dh_lib.c",
  "crypto/dh/dh_ameth.c",
  "crypto/dh/dh_pmeth.c",
  "crypto/dh/dh_key.c",
  "crypto/modes/ccm128.c",
  "crypto/modes/ofb128.c",
  "crypto/modes/cbc128.c",
  "crypto/modes/ctr128.c",
  "crypto/modes/gcm128.c",
  "crypto/modes/xts128.c",
  "crypto/modes/cfb128.c",
  "crypto/chacha/chacha.c",
  "crypto/bn/bn_print.c",
  "crypto/bn/bn_mont.c",
  "crypto/bn/bn_prime.c",
  "crypto/bn/bn_exp.c",
  "crypto/bn/bn_mod.c",
  "crypto/bn/bn_gcd.c",
  "crypto/bn/bn_sqr.c",
  "crypto/bn/bn_small_primes.c",
  "crypto/bn/bn_err.c",
  "crypto/bn/bn_shift.c",
  "crypto/bn/bn_const.c",
  "crypto/bn/bn_div.c",
  "crypto/bn/bn_mod_sqrt.c",
  "crypto/bn/bn_isqrt.c",
  "crypto/bn/bn_mul.c",
  "crypto/bn/bn_bpsw.c",
  "crypto/bn/bn_recp.c",
  "crypto/bn/bn_convert.c",
  "crypto/bn/bn_rand.c",
  "crypto/bn/bn_kron.c",
  "crypto/bn/bn_lib.c",
  "crypto/bn/bn_word.c",
  "crypto/bn/bn_ctx.c",
  "crypto/bn/bn_add.c",
  "crypto/bn/bn_primitives.c",
  "crypto/conf/conf_lib.c",
  "crypto/conf/conf_mod.c",
  "crypto/conf/conf_sap.c",
  "crypto/conf/conf_def.c",
  "crypto/conf/conf_mall.c",
  "crypto/conf/conf_err.c",
  "crypto/conf/conf_api.c",
  "crypto/objects/obj_err.c",
  "crypto/objects/obj_xref.c",
  "crypto/objects/obj_lib.c",
  "crypto/objects/obj_dat.c",
  "crypto/des/ecb_enc.c",
  "crypto/des/qud_cksm.c",
  "crypto/des/cfb64enc.c",
  "crypto/des/cbc_enc.c",
  "crypto/des/pcbc_enc.c",
  "crypto/des/set_key.c",
  "crypto/des/str2key.c",
  "crypto/des/cfb64ede.c",
  "crypto/des/ecb3_enc.c",
  "crypto/des/ofb64enc.c",
  "crypto/des/xcbc_enc.c",
  "crypto/des/fcrypt.c",
  "crypto/des/ofb64ede.c",
  "crypto/des/ofb_enc.c",
  "crypto/des/des_enc.c",
  "crypto/des/enc_writ.c",
  "crypto/des/cfb_enc.c",
  "crypto/des/ncbc_enc.c",
  "crypto/des/enc_read.c",
  "crypto/des/fcrypt_b.c",
  "crypto/des/cbc_cksm.c",
  "crypto/des/ede_cbcm_enc.c",
  "crypto/cpt_err.c",
  "crypto/buffer/buf_err.c",
  "crypto/buffer/buffer.c",
  "crypto/o_fips.c",
  "crypto/lhash/lhash.c",
  "crypto/cversion.c",
  "crypto/empty.c",
  "crypto/x509/x509_r2x.c",
  "crypto/x509/x509_issuer_cache.c",
  "crypto/x509/x509_info.c",
  "crypto/x509/x509_trs.c",
  "crypto/x509/by_file.c",
  "crypto/x509/x509_purp.c",
  "crypto/x509/x509_ext.c",
  "crypto/x509/x509_crld.c",
  "crypto/x509/x509_vfy.c",
  "crypto/x509/x509_req.c",
  "crypto/x509/x509spki.c",
  "crypto/x509/x509_err.c",
  "crypto/x509/x509_pmaps.c",
  "crypto/x509/x509_policy.c",
  "crypto/x509/x509_utl.c",
  "crypto/x509/x509_cpols.c",
  "crypto/x509/x509_lu.c",
  "crypto/x509/x509_pcons.c",
  "crypto/x509/x509_d2.c",
  "crypto/x509/x509_prn.c",
  "crypto/x509/x509_conf.c",
  "crypto/x509/x509_cmp.c",
  "crypto/x509/x509_extku.c",
  "crypto/x509/x509_int.c",
  "crypto/x509/x509_att.c",
  "crypto/x509/x509_def.c",
  "crypto/x509/x509type.c",
  "crypto/x509/x509_v3.c",
  "crypto/x509/x509_constraints.c",
  "crypto/x509/x509_akey.c",
  "crypto/x509/x509_bitst.c",
  "crypto/x509/x509_ocsp.c",
  "crypto/x509/x509cset.c",
  "crypto/x509/x509_bcons.c",
  "crypto/x509/x509_verify.c",
  "crypto/x509/x509_addr.c",
  "crypto/x509/x509_set.c",
  "crypto/x509/x509_alt.c",
  "crypto/x509/x509rset.c",
  "crypto/x509/by_dir.c",
  "crypto/x509/x509_asid.c",
  "crypto/x509/x509name.c",
  "crypto/x509/x_all.c",
  "crypto/x509/x509_txt.c",
  "crypto/x509/x509_akeya.c",
  "crypto/x509/by_mem.c",
  "crypto/x509/x509_genn.c",
  "crypto/x509/x509_skey.c",
  "crypto/x509/x509_vpm.c",
  "crypto/x509/x509_ncons.c",
  "crypto/x509/x509_lib.c",
  "crypto/x509/x509_ia5.c",
  "crypto/x509/x509_obj.c",
  "crypto/x509/x509_pku.c",
  "crypto/md4/md4.c",
  "crypto/cms/cms_err.c",
  "crypto/cms/cms_io.c",
  "crypto/cms/cms_smime.c",
  "crypto/cms/cms_pwri.c",
  "crypto/cms/cms_kari.c",
  "crypto/cms/cms_ess.c",
  "crypto/cms/cms_asn1.c",
  "crypto/cms/cms_att.c",
  "crypto/cms/cms_sd.c",
  "crypto/cms/cms_enc.c",
  "crypto/cms/cms_env.c",
  "crypto/cms/cms_dd.c",
  "crypto/cms/cms_lib.c",
  "crypto/rc2/rc2ofb64.c",
  "crypto/rc2/rc2_skey.c",
  "crypto/rc2/rc2_ecb.c",
  "crypto/rc2/rc2_cbc.c",
  "crypto/rc2/rc2cfb64.c",
  "crypto/ecdh/ecdh.c",
  "crypto/sm4/sm4.c",
  "crypto/o_init.c",
  "crypto/crypto_lock.c",
]