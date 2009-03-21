(*
 * This file is part of Bisect.
 * Copyright (C) 2008-2009 Xavier Clerc.
 *
 * Bisect is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * Bisect is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *)

let version = "1.0-alpha"

let (++) x y =
  if ((x > 0) && (y > 0) && (x > max_int - y)) then
    max_int
  else if ((x < 0) && (y < 0) && (x < min_int - y)) then
    min_int
  else
    x + y

type stat = { mutable count : int; mutable total : int }
type stats = (Common.point_kind * stat) list
let make_stats () =
  List.map (fun x -> (x, { count = 0; total = 0 })) Common.all_point_kinds
let update_stats s k p =
  let r = List.assoc k s in
  if p then r.count <- r.count ++ 1;
  r.total <- r.total ++ 1
let summarize_stats s =
  List.fold_left
    (fun (c, t) (_, r) ->
      ((c ++ r.count), (t ++ r.total)))
    (0, 0)
    s
let add_stats s1 s2 =
  List.map2
    (fun (k1, r1) (k2, r2) ->
      assert (k1 = k2);
      (k1, { count = r1.count ++ r2.count; total = r1.total ++ r2.total }))
    s1
    s2
let sum_stats l = List.fold_left add_stats (make_stats ()) l
let html_of_stats tab s =
  tab ^ "<table class=\"simple\">\n" ^
  tab ^ "  <tr><th>kind</th><th width=\"16px\">&nbsp;</th><th>coverage</th></tr>\n" ^
  tab ^ (String.concat
           ("\n" ^ tab)
           (List.map
              (fun (k, r) ->
                Printf.sprintf "  <tr><td>%s</td><td width=\"16px\">&nbsp;</td><td>%d / %d (%s %%)</td></tr>"
                  (Common.string_of_point_kind k)
                  r.count
                  r.total
                  (if r.total <> 0 then
                    string_of_int ((r.count * 100) / r.total)
                  else
                    "-"))
              s)) ^ "\n" ^
  tab ^ "</table>\n"

let try_close_out oc =
  try close_out oc with _ -> ()

let try_close_in ic =
  try close_in ic with _ -> ()

let open_both in_file out_file =
  let in_channel = open_in in_file in
  try
    let out_channel = open_out out_file in
    (in_channel, out_channel)
  with e ->
    try_close_in in_channel;
    raise e

let output_css filename =
  let channel = open_out filename in
  (try
    let output_strings = List.iter (output_string channel) in
    output_strings
      [ "body {\n";
        "    background: white;\n";
        "    white-space: nowrap;\n";
        "}\n";
        "\n";
        ".footer {\n";
        "    font-size: smaller;\n";
        "    text-align: center;\n";
        "}\n";
        "\n";
        ".codeSep {\n";
        "    border: none 0;\n";
        "    border-top: 1px solid gray;\n";
        "    height: 1px;\n";
        "}\n";
        "\n";
        ".indexSep {\n";
        "    border: none 0;\n";
        "    border-top: 1px solid gray;\n";
        "    height: 1px;\n";
        "    width: 75%;\n";
        "}\n";
        "\n";
        ".lineNone { white-space: nowrap; background: white; }\n";
        ".lineAllVisited { white-space: nowrap; background: green; }\n";
        ".lineAllUnvisited { white-space: nowrap; background: red; }\n";
        ".lineMixed { white-space: nowrap; background: yellow; }\n";
        "\n";
        "table.simple {\n";
        "    border-width: 1px;\n";
        "    border-spacing: 0px;\n";
        "    border-top-style: solid;\n";
        "    border-bottom-style: solid;\n";
        "    border-color: black;\n";
        "}\n";
        "\n";
        "table.simple th {\n";
        "    border-width: 1px;\n";
        "    border-spacing: 0px;\n";
        "    border-bottom-style: solid;\n";
        "    border-color: black;\n";
        "    text-align: center;\n";
        "    font-weight: bold;\n";
        "}\n";
        "\n";
        "table.simple td {\n";
        "    border-width: 1px;\n";
        "    border-spacing: 0px;\n";
        "    border-style: none;\n";
        "}\n";
        "\n";
        "table.gauge {\n";
        "    border-width: 0px;\n";
        "    border-spacing: 0px;\n";
        "    padding: 0px;\n";
        "    border-style: none;\n";
        "    border-collapse: collapse;\n";
        "}\n";
        "\n";
        "table.gauge td {\n";
        "    border-width: 0px;\n";
        "    border-spacing: 0px;\n";
        "    padding: 0px;\n";
        "    border-style: none;\n";
        "    border-collapse: collapse;\n";
        "}\n";
        "\n";
        ".gaugeOK { background: green; }\n";
        ".gaugeKO { background: red; }\n";
        "\n" ]
  with e ->
    try_close_out channel;
    raise e);
  try_close_out channel

let html_footer =
  let now = Unix.localtime (Unix.time ()) in
  Printf.sprintf "Generated by <a href=\"http://bisect.x9c.fr\">Bisect</a> on %d-%02d-%02d %02d:%02d:%02d" (1900 + now.Unix.tm_year) (1 + now.Unix.tm_mon) now.Unix.tm_mday now.Unix.tm_hour now.Unix.tm_min now.Unix.tm_sec

let output_html_index verbose filename l =
  verbose "Writing index file ...";
  let channel = open_out filename in
  (try
    let output_strings = List.iter (output_string channel) in
    let stats = List.fold_left (fun acc (_, _, s) -> add_stats acc s) (make_stats ()) l in
    output_strings
      [  "<html>\n";
         "  <head>\n";
         "    <title>Bisect report</title>\n";
         "    <link rel=\"stylesheet\" type=\"text/css\" href=\"style.css\">\n";
         "  </head>\n";
         "  <body>\n";
         "    <h1>Bisect report</h1>\n";
         "    <hr class=\"indexSep\"/>\n";
         "    <center>\n";
         "    <h3>Overall statistics</h3\n";
         (html_of_stats "    " stats);
         "    <br/>\n";
         "    </center>\n";
         "    <hr class=\"indexSep\"/>\n";
         "    <center>\n";
         "    <br/>\n";
         "    <h3>Per-file coverage</h3\n";
         "      <table class=\"simple\">\n";
         "        <tr>\n";
         "          <th>coverage</th>\n";
         "          <th width=\"16px\">&nbsp;</th>\n";
         "          <th>file</th>\n";
         "        </tr>\n" ];
    List.iter
      (fun (in_file, out_file, stats) ->
        let a, b = summarize_stats stats in
        let x = if b = 0 then 100 else (100 * a) / b in
        let y = 100 - x in
        output_strings
          [ "        <tr>\n";
            "          <td>\n";
            "            <table class=\"gauge\">\n";
            "              <tr>\n";
            "                <td class=\"gaugeOK\" width=\"";
            (string_of_int x);
            "px\"/>\n";
            "                <td class=\"gaugeKO\" width=\"";
            (string_of_int y);
            "px\"/>\n";
            "                <td>&nbsp;";
            (if b = 0 then "-" else string_of_int x);
            "%</td>\n";
            "              </tr>\n";
            "            </table>\n";
            "          </td>\n";
            "          <td width=\"16px\">&nbsp;</td>\n";
            "          <td><a href=\"";
            out_file;
            "\">";
            in_file;
            "</a></td>";
            "\n";
            "        </tr>\n" ])
      l;
    output_strings
      [ "      </table>\n";
        "    </center>\n";
        "    <br/>\n";
        "    <br/>\n";
        "    <hr class=\"indexSep\"/>\n";
        ("    <p class=\"footer\">" ^ html_footer ^ "</p>\n");
        "  </body>\n";
        "</html>\n" ]
  with e ->
    try_close_out channel;
    raise e);
  try_close_out channel

(* split p [e1; ...; en] returns ([e1; ...; e(i-1)], [ei; ...; en])
   where i is the lowest index such that (p ei) evaluates to false *)
let split p l =
  let rec spl acc = function
    | hd :: tl ->
        if (p hd) then
          spl (hd :: acc) tl
        else
          (List.rev acc), (hd :: tl)
    | [] -> (List.rev acc), [] in
  spl [] l

let html_of_line tab_size line offset points =
  let buff = Buffer.create (String.length line) in
  let ofs = ref offset in
  let pts = ref points in
  let marker n =
    Buffer.add_string buff "(*[";
    Buffer.add_string buff (string_of_int n);
    Buffer.add_string buff "]*)" in
  let marker_if_any () =
    match !pts with
    | (o, n) :: tl when o = !ofs ->
        marker n;
        pts := tl
    | _ -> () in
  String.iter
    (fun ch ->
      marker_if_any ();
      (match ch with
      | '<' -> Buffer.add_string buff "&lt;"
      | '>' -> Buffer.add_string buff "&gt;"
      | ' ' -> Buffer.add_string buff "&nbsp;"
      | '\"' -> Buffer.add_string buff "&quot;"
      | '&' -> Buffer.add_string buff "&amp;"
      | '\t' -> for i = 1 to tab_size do Buffer.add_string buff "&nbsp;" done
      | _ -> Buffer.add_char buff ch);
      incr ofs)
    line;
  List.iter (fun (_, n) -> marker n) !pts;
  Buffer.contents buff

let output_html verbose tab_size in_file out_file visited =
  verbose (Printf.sprintf "Processing file '%s' ..." in_file);
  let cmp_content = Common.read_points in_file in
  verbose (Printf.sprintf "... file has %d points" (List.length cmp_content));
  let len = Array.length visited in
  let stats = make_stats () in
  let pts = ref (List.map
                    (fun (ofs, pt, k) ->
                      let nb = if pt < len then visited.(pt) else 0 in
                      update_stats stats k (nb > 0);
                      (ofs, nb))
                    cmp_content) in
  let in_channel, out_channel = open_both in_file out_file in
  (try
    let output_strings = List.iter (output_string out_channel) in
    output_strings
      [ "<html>\n";
        "  <head>\n";
        "    <title>Bisect report</title>\n";
        "    <link rel=\"stylesheet\" type=\"text/css\" href=\"style.css\">\n";
        "  </head>\n";
        "  <body>\n";
        "    <h3>File: ";
        in_file;
        " (<a href=\"index.html\">return to index</a>)</h3>\n";
        "    <hr class=\"codeSep\"/>\n";
        "    <h4>Statistics:</h4>\n";
        (html_of_stats "    " stats);
        "    <hr class=\"codeSep\"/>\n";
        "    <h4>Source:</h4>\n";
        "    <code>\n" ];
    let line_no = ref 0 in
    (try
      while true do
        incr line_no;
        let start_ofs = pos_in in_channel in
        let line = input_line in_channel in
        let end_ofs = pos_in in_channel in
        let before, after = split (fun (o, _) -> o < end_ofs) !pts in
        let line' = html_of_line tab_size line start_ofs before in
        let visited, unvisited =
          List.fold_left
            (fun (v, u) (_, nb) ->
              ((v || (nb > 0)), (u || (nb = 0))))
            (false, false)
            before in
        let cls = match visited, unvisited with
        | false, false -> "lineNone"
        | true, false -> "lineAllVisited"
        | false, true -> "lineAllUnvisited"
        | true, true -> "lineMixed" in
        output_strings
          [ ("      <div class=\"" ^ cls ^ "\">");
            (Printf.sprintf "%06d| " !line_no);
            (if line' = "" then "&nbsp;" else line');
            "</div>\n" ];
        pts := after
      done
    with End_of_file -> ());
    output_strings
      [ "    </code>\n";
        "    <hr class=\"codeSep\"/>\n";
        ("    <p class=\"footer\">" ^ html_footer ^ "</p>\n");
        "  </body>\n";
        "</html>\n" ];
  with e ->
    try_close_in in_channel;
    try_close_out out_channel;
    raise e);
  try_close_in in_channel;
  try_close_out out_channel;
  stats

let rec (+|) x y =
  let lx = Array.length x in
  let ly = Array.length y in
  if lx >= ly then begin
    let z = Array.copy x in
    for i = 0 to (pred ly) do
      z.(i) <- x.(i) ++ y.(i)
    done;
    z
  end else
    y +| x

let rec mkdirs dir =
  match Filename.dirname dir with
  | "." | "/" | "\\" ->
    if not (Sys.file_exists dir) then
      Unix.mkdir dir 0o755
  | parent ->
      mkdirs parent;
      if not (Sys.file_exists dir) then
        Unix.mkdir dir 0o755

type output_kind = No_output | Html_output of string

let main () =
  let output = ref No_output in
  let data = Hashtbl.create 32 in
  let verbose = ref false in
  let tab_size = ref 8 in
  Arg.parse
    [ ("-version",
       Arg.Unit (fun () -> print_endline version; exit 0),
       " Print version and exit") ;
      ("-verbose",
       Arg.Set verbose,
       " Set verbose mode") ;
      ("-tab-size",
       Arg.Set_int tab_size,
       "<int>  Set tabulation size in output") ;
      ("-html",
       Arg.String (fun s -> output := Html_output s),
       "<dir>  Output html files in given directory") ]
    (fun s ->
      List.iter
        (fun (k, arr) ->
          let arr' = try (Hashtbl.find data k) +| arr with Not_found -> arr in
          Hashtbl.replace data k arr')
        (Common.read_runtime_data s))
    "Usage: bisect <options> <files>\nOptions are:";
  let verbose = if !verbose then print_endline else ignore in
  match !output with
  | No_output -> prerr_endline " *** warning: no output requested"
  | Html_output dir ->
      mkdirs dir;
      if (Hashtbl.length data) = 0 then
        prerr_endline " *** warning: no input file"
      else
        let files = Hashtbl.fold
            (fun in_file visited acc ->
              let l = List.length acc in
              let basename = Printf.sprintf "file%04d.html" l in
              let out_file = Filename.concat dir basename in
              let stats = output_html verbose !tab_size in_file out_file visited in
              (in_file, basename, stats) :: acc)
            data
            [] in
        output_html_index verbose (Filename.concat dir "index.html") (List.sort compare files);
        output_css (Filename.concat dir "style.css")

let () =
  try
    main ();
    exit 0
  with
  | Sys_error s ->
      Printf.eprintf " *** system error: %s\n" s;
      exit 1
  | Common.Invalid_file s ->
      Printf.eprintf " *** invalid file: '%s'\n" s;
      exit 1
  | Common.Unsupported_version s ->
      Printf.eprintf " *** unsupported version: '%s'\n" s;
      exit 1
  | Common.Modified_file s ->
      Printf.eprintf " *** concurrent modification: '%s'\n" s;
      exit 1
  | e ->
      Printf.eprintf " *** error: %s\n" (Printexc.to_string e);
      exit 1