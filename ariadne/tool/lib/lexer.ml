type token =
  | Word of string
  | LBrace
  | RBrace
  | LParen
  | RParen
  | Semi
  | Question
  | And
  | Or
  | Nullish
  | Arrow

let is_word_start c =
  c = '_' || c = '$'
  || (c >= 'a' && c <= 'z')
  || (c >= 'A' && c <= 'Z')

let is_word_char c = is_word_start c || (c >= '0' && c <= '9')
let is_space c = c = ' ' || c = '\t' || c = '\r' || c = '\n'

let tokenize (s : string) : token list =
  let n = String.length s in
  let toks = ref [] in
  let push t = toks := t :: !toks in
  let i = ref 0 in
  let peek k = if !i + k < n then s.[!i + k] else '\000' in
  while !i < n do
    let c = s.[!i] in
    if is_space c then incr i
    else if is_word_start c then begin
      let start = !i in
      while !i < n && is_word_char s.[!i] do
        incr i
      done;
      push (Word (String.sub s start (!i - start)))
    end
    else begin
      (match c with
       | '{' -> push LBrace; incr i
       | '}' -> push RBrace; incr i
       | '(' -> push LParen; incr i
       | ')' -> push RParen; incr i
       | ';' -> push Semi; incr i
       | '&' -> if peek 1 = '&' then (push And; i := !i + 2) else incr i
       | '|' -> if peek 1 = '|' then (push Or; i := !i + 2) else incr i
       | '=' -> if peek 1 = '>' then (push Arrow; i := !i + 2) else incr i
       | '?' ->
         if peek 1 = '?' then (push Nullish; i := !i + 2)
         else if peek 1 = '.' then incr i  (* ?. optional chaining: 分岐ではない *)
         else begin
           (* 空白を飛ばした次が ':' なら省略可能マーカー x?: で分岐ではない *)
           let j = ref (!i + 1) in
           while !j < n && is_space s.[!j] do
             incr j
           done;
           if !j < n && s.[!j] = ':' then incr i  (* 省略可能: 数えない *)
           else (push Question; incr i)           (* 三項: 数える *)
         end
       | _ -> incr i  (* 関心のない文字はトークン化しない *))
    end
  done;
  List.rev !toks
