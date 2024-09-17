#ifndef HTML5_TAGS_H_
#define HTML5_TAGS_H_

typedef enum {
  Html5Tag_UNKNOWN = 0,
  Html5Tag_a,
  Html5Tag_abbr,
  Html5Tag_acronym,
  Html5Tag_address,
  Html5Tag_area,
  Html5Tag_article,
  Html5Tag_aside,
  Html5Tag_audio,
  Html5Tag_b,
  Html5Tag_base,
  Html5Tag_bdi,
  Html5Tag_bdo,
  Html5Tag_big,
  Html5Tag_blockquote,
  Html5Tag_body,
  Html5Tag_br,
  Html5Tag_button,
  Html5Tag_canvas,
  Html5Tag_caption,
  Html5Tag_center,
  Html5Tag_cite,
  Html5Tag_code,
  Html5Tag_col,
  Html5Tag_colgroup,
  Html5Tag_data,
  Html5Tag_datalist,
  Html5Tag_dd,
  Html5Tag_del,
  Html5Tag_details,
  Html5Tag_dfn,
  Html5Tag_dialog,
  Html5Tag_dir,
  Html5Tag_div,
  Html5Tag_dl,
  Html5Tag_dt,
  Html5Tag_em,
  Html5Tag_embed,
  Html5Tag_fencedframe,
  Html5Tag_fieldset,
  Html5Tag_figcaption,
  Html5Tag_figure,
  Html5Tag_font,
  Html5Tag_footer,
  Html5Tag_form,
  Html5Tag_frame,
  Html5Tag_frameset,
  Html5Tag_h1,
  Html5Tag_h2,
  Html5Tag_h3,
  Html5Tag_h4,
  Html5Tag_h5,
  Html5Tag_h6,
  Html5Tag_head,
  Html5Tag_header,
  Html5Tag_hgroup,
  Html5Tag_hr,
  Html5Tag_html,
  Html5Tag_i,
  Html5Tag_iframe,
  Html5Tag_img,
  Html5Tag_input,
  Html5Tag_ins,
  Html5Tag_kbd,
  Html5Tag_label,
  Html5Tag_legend,
  Html5Tag_li,
  Html5Tag_link,
  Html5Tag_main,
  Html5Tag_map,
  Html5Tag_mark,
  Html5Tag_marquee,
  Html5Tag_menu,
  Html5Tag_meta,
  Html5Tag_meter,
  Html5Tag_nav,
  Html5Tag_nobr,
  Html5Tag_noembed,
  Html5Tag_noframes,
  Html5Tag_noscript,
  Html5Tag_object,
  Html5Tag_ol,
  Html5Tag_optgroup,
  Html5Tag_option,
  Html5Tag_output,
  Html5Tag_p,
  Html5Tag_param,
  Html5Tag_picture,
  Html5Tag_plaintext,
  Html5Tag_portal,
  Html5Tag_pre,
  Html5Tag_progress,
  Html5Tag_q,
  Html5Tag_rb,
  Html5Tag_rp,
  Html5Tag_rt,
  Html5Tag_rtc,
  Html5Tag_ruby,
  Html5Tag_s,
  Html5Tag_samp,
  Html5Tag_script,
  Html5Tag_search,
  Html5Tag_section,
  Html5Tag_select,
  Html5Tag_slot,
  Html5Tag_small,
  Html5Tag_source,
  Html5Tag_span,
  Html5Tag_strike,
  Html5Tag_strong,
  Html5Tag_style,
  Html5Tag_sub,
  Html5Tag_summary,
  Html5Tag_sup,
  Html5Tag_table,
  Html5Tag_tbody,
  Html5Tag_td,
  Html5Tag_template,
  Html5Tag_textarea,
  Html5Tag_tfoot,
  Html5Tag_th,
  Html5Tag_thead,
  Html5Tag_time,
  Html5Tag_title,
  Html5Tag_tr,
  Html5Tag_track,
  Html5Tag_tt,
  Html5Tag_u,
  Html5Tag_ul,
  Html5Tag_var,
  Html5Tag_video,
  Html5Tag_wbr,
  Html5Tag_xmp,
  Html5Tag__SENTINEL,
} Html5TagType;

extern char* html5_tagstrs[Html5Tag__SENTINEL];

Html5TagType html5_tagmap_get(const char*);

#endif
