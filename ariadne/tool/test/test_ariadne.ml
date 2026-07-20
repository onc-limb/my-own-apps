let failures = ref 0

let check name cond =
  if cond then Printf.printf "  ok   %s\n" name
  else begin
    incr failures;
    Printf.printf "  FAIL %s\n" name
  end

let cc src = (Ariadne.Metrics.analyze src).cyclomatic
let cg src = (Ariadne.Metrics.analyze src).cognitive

let () =
  (* --- LOC 分類 --- *)
  let src =
    "// header comment\n\
     const x = 1;\n\
     \n\
     /* block\n\
     still comment */\n\
     function f() { return x; }\n"
  in
  let m = Ariadne.Metrics.analyze src in
  check "loc.total = 6" (m.loc.total = 6);
  check "loc.blank = 1" (m.loc.blank = 1);
  check "loc.comment = 3" (m.loc.comment = 3);
  check "loc.code = 2" (m.loc.code = 2);

  (* --- 循環的複雑度 --- *)
  check "cc base = 1" (cc "const x = 1;\n" = 1);
  check "cc if/&&/|| = 4" (cc "if (a && b || c) { return 1; }\n" = 4);
  check "keywords in string/comment ignored"
    (cc "const s = \"if for while\"; // if for while\nconst y = 2;\n" = 1);
  check "cc for/while/catch/case = 5"
    (cc
       "for (;;) { while (true) { try {} catch (e) {} switch (x) { case 1: break; } } }\n"
     = 5);

  (* --- A: 三項演算子は数える / ?. ?? x?: は数えない --- *)
  check "ternary counted (cc=2)" (cc "const r = a ? b : c;\n" = 2);
  check "optional chaining not counted (cc=1)" (cc "const r = a?.b?.c;\n" = 1);
  check "optional param not counted (cc=1)"
    (cc "function f(x?: number) { return x; }\n" = 1);
  check "nullish is one branch (cc=2)" (cc "const r = a ?? b;\n" = 2);

  (* --- B: 認知的複雑度 --- *)
  check "cg flat if = 1" (cg "if (a) { b(); }\n" = 1);
  check "cg nested if = 3" (cg "if (a) { if (b) { c(); } }\n" = 3);
  check "cg if/else = 2" (cg "if (a) {} else {}\n" = 2);
  check "cg for>if nesting = 3" (cg "for (;;) { if (a) {} }\n" = 3);
  check "cg && sequence = 1" (cg "const r = a && b && c;\n" = 1);
  check "cg && then || = 2" (cg "const r = a && b || c;\n" = 2);
  check "cg switch counts once (case ignored)"
    (cg "switch (x) { case 1: break; default: break; }\n" = 1);
  check "cg else if chain = 3"
    (cg "if (a) {} else if (b) {} else {}\n" = 3);

  (* --- C: import 抽出と抽象度 --- *)
  let info =
    Ariadne.Imports.extract
      "import { a } from './a';\n\
       import 'side';\n\
       const m = require('react');\n\
       export interface I {}\n\
       export class C {}\n"
  in
  check "specifiers extracted"
    (List.sort compare info.specifiers = [ "./a"; "react"; "side" ]);
  check "abstract export counted" (info.abstract_exports = 1);
  check "concrete export counted" (info.concrete_exports = 1);

  (* --- C: グラフ Ca/Ce/I/A/D --- *)
  let entries =
    [
      ( "/proj/a.ts",
        {
          Ariadne.Imports.specifiers = [ "./b"; "react" ];
          abstract_exports = 0;
          concrete_exports = 1;
        } );
      ( "/proj/b.ts",
        {
          Ariadne.Imports.specifiers = [];
          abstract_exports = 1;
          concrete_exports = 0;
        } );
    ]
  in
  let mods = Ariadne.Graph.analyze entries in
  let find p = List.find (fun (m : Ariadne.Graph.module_metrics) -> m.path = p) mods in
  let a = find "/proj/a.ts" and b = find "/proj/b.ts" in
  check "a.ce = 1 (imports b)" (a.ce = 1);
  check "a.ca = 0" (a.ca = 0);
  check "a.external = 1 (react)" (a.external_deps = 1);
  check "a.instability = 1.0" (a.instability = 1.0);
  check "a.distance = 0.0" (a.distance = 0.0);
  check "b.ca = 1 (used by a)" (b.ca = 1);
  check "b.abstractness = 1.0" (b.abstractness = 1.0);
  check "b.instability = 0.0" (b.instability = 0.0);
  check "b.distance = 0.0" (b.distance = 0.0);

  if !failures = 0 then print_string "\nALL TESTS PASSED\n"
  else begin
    Printf.printf "\n%d TEST(S) FAILED\n" !failures;
    exit 1
  end
