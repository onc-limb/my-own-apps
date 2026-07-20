type loc = {
  total : int;
  code : int;
  comment : int;
  blank : int;
}

type t = {
  loc : loc;
  cyclomatic : int;
  cognitive : int;
  functions : int;
}

(* 循環的複雑度で 1 つ数えるキーワード。switch/else/default は経路を増やさない。 *)
let cyclomatic_keywords = [ "if"; "for"; "while"; "case"; "catch" ]

let loc_of_kinds kinds =
  let total = List.length kinds in
  let code = List.length (List.filter (( = ) Tokenizer.Code) kinds) in
  let comment = List.length (List.filter (( = ) Tokenizer.Comment) kinds) in
  let blank = total - code - comment in
  { total; code; comment; blank }

let analyze (src : string) : t =
  let scanned = Tokenizer.scan src in
  let loc = loc_of_kinds scanned.line_kinds in
  let tokens = Lexer.tokenize scanned.cleaned in
  (* トークン列を 1 回走査して必要な個数を集計する。 *)
  let keyword_branches = ref 0 in
  let logical_ops = ref 0 in
  let ternary = ref 0 in
  let functions = ref 0 in
  List.iter
    (fun (t : Lexer.token) ->
      match t with
      | Lexer.Word w when List.mem w cyclomatic_keywords -> incr keyword_branches
      | Lexer.Word "function" -> incr functions
      | Lexer.And | Lexer.Or | Lexer.Nullish -> incr logical_ops
      | Lexer.Question -> incr ternary
      | Lexer.Arrow -> incr functions
      | _ -> ())
    tokens;
  let cyclomatic = 1 + !keyword_branches + !logical_ops + !ternary in
  let cognitive = Cognitive.complexity tokens in
  { loc; cyclomatic; cognitive; functions = !functions }
