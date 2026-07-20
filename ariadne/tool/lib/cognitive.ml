(* 認知的複雑度の近似計算。詳細な方針は cognitive.mli を参照。 *)

(* { ... } スコープごとに「ネストを 1 段増やしたか」と「何が開いたか」を覚える。
   opener は do-while の trailing while をスキップするために使う。 *)
type scope = {
  is_nesting : bool;
  opener : string;
}

(* 直前に出た控えの「これから波括弧が来る」状態。 *)
type pending =
  | P_none
  | P_control  (* if / for / while / switch / catch / else など *)
  | P_func     (* function / => *)

type logical =
  | L_none
  | L_and
  | L_or
  | L_nullish

let complexity (tokens : Lexer.token list) : int =
  let score = ref 0 in
  let nesting = ref 0 in
  let paren = ref 0 in
  let scopes = ref [] in
  let pending = ref P_none in
  let pending_opener = ref "" in
  let after_else = ref false in       (* 直前トークンが else だったか（else if 判定用） *)
  let expect_dowhile = ref false in   (* 次の while は do-while の末尾なので数えない *)
  let prev_logical = ref L_none in

  let open_scope is_nesting opener =
    scopes := { is_nesting; opener } :: !scopes;
    if is_nesting then incr nesting
  in
  let close_scope () =
    match !scopes with
    | s :: tl ->
      scopes := tl;
      if s.is_nesting then decr nesting;
      s.opener
    | [] -> ""
  in
  (* 論理演算子: 直前と異なる演算子が来たら新しい列として +1（B1 の列ルール近似）。 *)
  let logical_hit l =
    if !prev_logical <> l then incr score;
    prev_logical := l
  in

  List.iter
    (fun tok ->
      let was_after_else = !after_else in
      (* Word 以外のトークンが来たら else 直後フラグは消える *)
      (match tok with Lexer.Word _ -> () | _ -> after_else := false);
      match tok with
      | Lexer.LParen -> incr paren
      | Lexer.RParen -> if !paren > 0 then decr paren
      | Lexer.Semi ->
        (* 文の終わり: 波括弧なしの制御文の控えをここで解除する（括弧内の ; は無視） *)
        if !paren = 0 then pending := P_none;
        prev_logical := L_none
      | Lexer.LBrace ->
        let is_nesting, opener =
          match !pending with
          | P_control -> (true, !pending_opener)
          | P_func -> (!nesting > 0, "func")  (* トップレベル関数本体はネスト 0 *)
          | P_none -> (false, "block")        (* オブジェクト/クラス/ただのブロック *)
        in
        open_scope is_nesting opener;
        pending := P_none;
        prev_logical := L_none
      | Lexer.RBrace ->
        let opener = close_scope () in
        if opener = "do" then expect_dowhile := true;
        prev_logical := L_none
      | Lexer.And -> logical_hit L_and
      | Lexer.Or -> logical_hit L_or
      | Lexer.Nullish -> logical_hit L_nullish
      | Lexer.Question ->
        score := !score + 1 + !nesting;
        prev_logical := L_none
      | Lexer.Arrow ->
        pending := P_func;
        prev_logical := L_none
      | Lexer.Word w ->
        (* 注意: 識別子（オペランド）では prev_logical をリセットしない。
           [a && b && c] のような演算子の連続を途切れさせないため。
           リセットは制御キーワード（条件式が新しく始まる）でのみ行う。 *)
        after_else := false;
        (match w with
         | "if" ->
           prev_logical := L_none;
           if was_after_else then
             (* else if: else 側で既に +1 済み。ここでは加点もネスト加点もしない *)
             (pending := P_control; pending_opener := "if")
           else begin
             score := !score + 1 + !nesting;
             pending := P_control;
             pending_opener := "if"
           end
         | "else" ->
           prev_logical := L_none;
           score := !score + 1;  (* ネスト加点はしない (B3) *)
           after_else := true;
           pending := P_control;
           pending_opener := "else"
         | "for" | "while" | "switch" | "catch" | "do" ->
           prev_logical := L_none;
           if w = "while" && !expect_dowhile then expect_dowhile := false
           else begin
             score := !score + 1 + !nesting;
             pending := P_control;
             pending_opener := w
           end
         | "function" -> pending := P_func
         | _ -> ()))
    tokens;
  !score
