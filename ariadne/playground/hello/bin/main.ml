let () = print_endline "Hello, Ariadne!"

let safe_div x y =
  if y = 0 then Error "divide by zero" else Ok (x / y)

type expr =
  | Int of int
  | Add of expr * expr
  | Mul of expr * expr
  | Sub of expr * expr
  | Div of expr * expr

let rec eval = function
 | Int n -> Ok n
 | Add (a, b) -> (match eval a with 
  | Error e -> Error e
  | Ok av -> 
    (match eval b with
      | Error e -> Error e
      | Ok bv -> Ok (av + bv)))
  | Mul (a, b) ->
      (match eval a with
       | Error e -> Error e
       | Ok av ->
         (match eval b with
          | Error e -> Error e
          | Ok bv -> Ok (av * bv)))
  | Sub (a, b) ->
      (match eval a with
       | Error e -> Error e
       | Ok av ->
         (match eval b with
          | Error e -> Error e
          | Ok bv -> Ok (av - bv)))
  | Div (a, b) ->
      (match eval a with
       | Error e -> Error e
       | Ok av ->
         (match eval b with
          | Error e -> Error e
          | Ok bv -> safe_div av bv))