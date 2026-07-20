type line_kind =
  | Code
  | Comment
  | Blank

type t = {
  cleaned : string;
  line_kinds : line_kind list;
}

(* 走査中の状態。どの「文脈」の中にいるかを表す。 *)
type state =
  | Normal
  | Line_comment            (* // ... 行末まで *)
  | Block_comment           (* /* ... */ *)
  | In_string of char       (* '...' または "..."。引数は閉じ記号 *)
  | In_template             (* `...` *)

(* 1 行ぶんの集計。コメント文字とコード文字のどちらが現れたかを覚えておく。 *)
type line_acc = {
  mutable has_code : bool;
  mutable has_comment : bool;
}

let classify acc =
  if acc.has_code then Code
  else if acc.has_comment then Comment
  else Blank

let scan (src : string) : t =
  let n = String.length src in
  let cleaned = Buffer.create n in
  (* 行分類は逆順に積んで最後に reverse する（リスト先頭追加が O(1) なため）。 *)
  let kinds = ref [] in
  let acc = { has_code = false; has_comment = false } in
  let state = ref Normal in

  (* 改行に当たったときの共通処理: 行を分類し、アキュムレータを初期化する。 *)
  let end_line () =
    kinds := classify acc :: !kinds;
    acc.has_code <- false;
    acc.has_comment <- false
  in

  let i = ref 0 in
  while !i < n do
    let c = src.[!i] in
    (* 次の文字を覗き見るヘルパ（範囲外なら '\000'）。 *)
    let peek k = if !i + k < n then src.[!i + k] else '\000' in
    (match !state with
     | Normal ->
       if c = '/' && peek 1 = '/' then begin
         state := Line_comment;
         acc.has_comment <- true;
         Buffer.add_char cleaned ' ';
         Buffer.add_char cleaned ' ';
         incr i (* 2 文字消費するため余分に進める *)
       end
       else if c = '/' && peek 1 = '*' then begin
         state := Block_comment;
         acc.has_comment <- true;
         Buffer.add_char cleaned ' ';
         Buffer.add_char cleaned ' ';
         incr i
       end
       else if c = '\'' || c = '"' then begin
         state := In_string c;
         acc.has_code <- true;        (* 文字列リテラルはコード扱い *)
         Buffer.add_char cleaned c    (* 開きクォートは残す *)
       end
       else if c = '`' then begin
         state := In_template;
         acc.has_code <- true;
         Buffer.add_char cleaned c
       end
       else if c = '\n' then begin
         end_line ();
         Buffer.add_char cleaned '\n'
       end
       else begin
         (* 空白以外が出たらコード行とみなす *)
         if c <> ' ' && c <> '\t' && c <> '\r' then acc.has_code <- true;
         Buffer.add_char cleaned c
       end

     | Line_comment ->
       if c = '\n' then begin
         state := Normal;
         end_line ();
         Buffer.add_char cleaned '\n'
       end
       else Buffer.add_char cleaned ' '  (* コメント中身は空白に潰す *)

     | Block_comment ->
       if c = '*' && peek 1 = '/' then begin
         state := Normal;
         Buffer.add_char cleaned ' ';
         Buffer.add_char cleaned ' ';
         incr i
       end
       else if c = '\n' then begin
         (* ブロックコメントが複数行にまたがる場合、この行はコメント行 *)
         end_line ();
         acc.has_comment <- true;  (* end_line で消えた印を次行ぶんとして立て直す *)
         Buffer.add_char cleaned '\n'
       end
       else Buffer.add_char cleaned ' '

     | In_string q ->
       if c = '\\' then begin
         (* エスケープ: 次の 1 文字ごと潰して読み飛ばす *)
         Buffer.add_char cleaned ' ';
         if !i + 1 < n then Buffer.add_char cleaned ' ';
         incr i
       end
       else if c = q then begin
         state := Normal;
         Buffer.add_char cleaned c   (* 閉じクォートは残す *)
       end
       else if c = '\n' then begin
         (* 通常の文字列は改行で閉じない言語仕様だが、壊れた入力に備えて復帰 *)
         state := Normal;
         end_line ();
         Buffer.add_char cleaned '\n'
       end
       else Buffer.add_char cleaned ' '  (* 中身は潰す *)

     | In_template ->
       if c = '\\' then begin
         Buffer.add_char cleaned ' ';
         if !i + 1 < n then Buffer.add_char cleaned ' ';
         incr i
       end
       else if c = '`' then begin
         state := Normal;
         Buffer.add_char cleaned c
       end
       else if c = '\n' then begin
         (* テンプレートリテラルは複数行可。中身はコード扱いのまま継続 *)
         end_line ();
         acc.has_code <- true;
         Buffer.add_char cleaned '\n'
       end
       else Buffer.add_char cleaned ' ');
    incr i
  done;

  (* 末尾に改行が無い場合、最後の行を取りこぼさないよう締める。
     原文が空文字列のときは行を 0 とする。 *)
  if n > 0 && src.[n - 1] <> '\n' then end_line ();

  { cleaned = Buffer.contents cleaned; line_kinds = List.rev !kinds }
