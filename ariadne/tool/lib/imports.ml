type module_info = {
  specifiers : string list;
  abstract_exports : int;
  concrete_exports : int;
}

(* コメントだけを取り除き、文字列リテラルは残す小さなスキャナ。
   import 指定子は文字列なので、Tokenizer.scan（文字列も潰す）は使えない。 *)
let strip_comments (s : string) : string =
  let n = String.length s in
  let b = Buffer.create n in
  let i = ref 0 in
  let peek k = if !i + k < n then s.[!i + k] else '\000' in
  let state = ref `Normal in
  while !i < n do
    let c = s.[!i] in
    (match !state with
     | `Normal ->
       if c = '/' && peek 1 = '/' then (state := `Line; Buffer.add_string b "  "; incr i)
       else if c = '/' && peek 1 = '*' then (state := `Block; Buffer.add_string b "  "; incr i)
       else if c = '\'' || c = '"' || c = '`' then (state := `Str c; Buffer.add_char b c)
       else Buffer.add_char b c
     | `Line -> if c = '\n' then (state := `Normal; Buffer.add_char b c) else Buffer.add_char b ' '
     | `Block ->
       if c = '*' && peek 1 = '/' then (state := `Normal; Buffer.add_string b "  "; incr i)
       else Buffer.add_char b (if c = '\n' then '\n' else ' ')
     | `Str q ->
       Buffer.add_char b c;
       if c = '\\' then (if !i + 1 < n then (Buffer.add_char b (peek 1); incr i))
       else if c = q then state := `Normal);
    incr i
  done;
  Buffer.contents b

let compile p = Re.Pcre.re p |> Re.compile

(* 指定子を取り出す 3 系統の正規表現（group 1 が指定子）。 *)
let re_from = compile {|\bfrom\s*["']([^"']+)["']|}
let re_bare_import = compile {|\bimport\s*["']([^"']+)["']|}
let re_dynamic = compile {|\b(?:import|require)\s*\(\s*["']([^"']+)["']|}

let collect_specifiers text =
  let grab re =
    Re.all re text |> List.map (fun g -> Re.Group.get g 1)
  in
  grab re_from @ grab re_bare_import @ grab re_dynamic

(* export 抽象度の集計用パターン。 *)
let re_interface = compile {|\bexport\s+(?:declare\s+)?interface\b|}
let re_type_alias = compile {|\bexport\s+type\s+[A-Za-z_$]|}
let re_abstract_class = compile {|\bexport\s+(?:default\s+)?abstract\s+class\b|}
let re_class = compile {|\bexport\s+(?:default\s+)?class\b|}
let re_function = compile {|\bexport\s+(?:default\s+)?(?:async\s+)?function\b|}
let re_var = compile {|\bexport\s+(?:const|let|var|enum)\b|}

let count re text = List.length (Re.all re text)

let extract (src : string) : module_info =
  let text = strip_comments src in
  let specifiers = collect_specifiers text in
  let abstract_exports =
    count re_interface text + count re_type_alias text
    + count re_abstract_class text
  in
  let concrete_exports =
    count re_function text + count re_class text + count re_var text
  in
  { specifiers; abstract_exports; concrete_exports }
