open Scanner

let by_cyclomatic_desc a b =
  compare b.metrics.Metrics.cyclomatic a.metrics.Metrics.cyclomatic

let exceeds threshold results =
  List.length
    (List.filter (fun r -> r.metrics.Metrics.cyclomatic >= threshold) results)

(* 長いパスを右寄せで切り詰める（ファイル名側を優先して残す）。 *)
let shorten width p =
  if String.length p <= width then p
  else "..." ^ String.sub p (String.length p - (width - 3)) (width - 3)

let text ?threshold results =
  let buf = Buffer.create 1024 in
  let sorted = List.sort by_cyclomatic_desc results in
  Buffer.add_string buf
    (Printf.sprintf "%-46s %5s %5s %6s %6s\n" "FILE" "CC" "CG" "LOC" "FUNC");
  Buffer.add_string buf (String.make 72 '-');
  Buffer.add_char buf '\n';
  List.iter
    (fun r ->
      let m = r.metrics in
      let mark =
        match threshold with
        | Some t when m.Metrics.cyclomatic >= t -> " !"
        | _ -> ""
      in
      Buffer.add_string buf
        (Printf.sprintf "%-46s %5d %5d %6d %6d%s\n" (shorten 46 r.path)
           m.Metrics.cyclomatic m.Metrics.cognitive m.Metrics.loc.total
           m.Metrics.functions mark))
    sorted;
  let n = List.length results in
  let sum_cc =
    List.fold_left (fun a r -> a + r.metrics.Metrics.cyclomatic) 0 results
  in
  let sum_loc =
    List.fold_left (fun a r -> a + r.metrics.Metrics.loc.total) 0 results
  in
  Buffer.add_string buf (String.make 72 '-');
  Buffer.add_char buf '\n';
  Buffer.add_string buf
    (Printf.sprintf "files: %d   total CC: %d   total LOC: %d   avg CC: %.1f\n"
       n sum_cc sum_loc
       (if n = 0 then 0.0 else float_of_int sum_cc /. float_of_int n));
  (match threshold with
   | Some t ->
     Buffer.add_string buf
       (Printf.sprintf "threshold CC>=%d: %d file(s) flagged\n" t
          (exceeds t results))
   | None -> ());
  Buffer.contents buf

let json results =
  let file_json r =
    let m = r.metrics in
    `Assoc
      [
        ("path", `String r.path);
        ("cyclomatic", `Int m.Metrics.cyclomatic);
        ("cognitive", `Int m.Metrics.cognitive);
        ("functions", `Int m.Metrics.functions);
        ( "loc",
          `Assoc
            [
              ("total", `Int m.Metrics.loc.total);
              ("code", `Int m.Metrics.loc.code);
              ("comment", `Int m.Metrics.loc.comment);
              ("blank", `Int m.Metrics.loc.blank);
            ] );
      ]
  in
  `Assoc [ ("files", `List (List.map file_json results)) ]
  |> Yojson.Safe.pretty_to_string

(* --- 結合度メトリクス --- *)

let coupling_text (mods : Graph.module_metrics list) =
  let buf = Buffer.create 1024 in
  let sorted =
    List.sort
      (fun a b -> compare b.Graph.distance a.Graph.distance)
      mods
  in
  Buffer.add_string buf
    (Printf.sprintf "%-40s %4s %4s %5s %5s %5s %4s\n" "MODULE" "Ca" "Ce" "I" "A"
       "D" "EXT");
  Buffer.add_string buf (String.make 72 '-');
  Buffer.add_char buf '\n';
  List.iter
    (fun (m : Graph.module_metrics) ->
      Buffer.add_string buf
        (Printf.sprintf "%-40s %4d %4d %5.2f %5.2f %5.2f %4d\n"
           (shorten 40 m.path) m.ca m.ce m.instability m.abstractness m.distance
           m.external_deps))
    sorted;
  let n = List.length mods in
  let avg_d =
    if n = 0 then 0.0
    else
      List.fold_left (fun a m -> a +. m.Graph.distance) 0.0 mods
      /. float_of_int n
  in
  Buffer.add_string buf (String.make 72 '-');
  Buffer.add_char buf '\n';
  Buffer.add_string buf
    (Printf.sprintf "modules: %d   avg distance D: %.2f\n" n avg_d);
  Buffer.add_string buf
    "I=instability  A=abstractness  D=|A+I-1| (0 is best)  EXT=external deps\n";
  Buffer.contents buf

let coupling_json (mods : Graph.module_metrics list) =
  let m_json (m : Graph.module_metrics) =
    `Assoc
      [
        ("path", `String m.path);
        ("afferent", `Int m.ca);
        ("efferent", `Int m.ce);
        ("instability", `Float m.instability);
        ("abstractness", `Float m.abstractness);
        ("distance", `Float m.distance);
        ("external_deps", `Int m.external_deps);
      ]
  in
  `Assoc [ ("modules", `List (List.map m_json mods)) ]
  |> Yojson.Safe.pretty_to_string
