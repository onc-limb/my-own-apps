# OCaml Static Analysis Tool - Learning Roadmap

> **Goal:** OCaml を習得しながら、TypeScript（後に Python）のコードを解析し、
> 循環的複雑度などのアーキテクチャ指標を計算・管理する実用ツールを一から作る。
> 成果物は自分の案件のコードベースに実際に回せるものにする。

## Design Philosophy

- 簡単なものから積み上げる（最初は tree-sitter の FFI を避ける）
- 指標ロジックは言語非依存（分岐を数える発想は対象言語が変わっても同じ）
- 「動いた」で終わらせない（各フェーズに「身についたと言える基準」を設ける）

## Phases Overview

| Phase | Theme | Target Lang | tree-sitter | Focus |
|-------|-------|-------------|-------------|-------|
| 0 | OCaml basics & environment | -- | No | Grammar, ADT, pattern match, dune/opam |
| 1 | AST traversal skeleton | OCaml | No | Recursive traversal logic (no FFI) |
| 2 | Reading TypeScript | TypeScript | Introduce | External parser integration |
| 3 | Cyclomatic complexity MVP | TypeScript | Use | Single-file metrics |
| 4 | Repository-wide scan | TypeScript | Use | Threshold warnings, reports |
| 5 | CI integration & Python | TS / Python | Use | Multi-language, production use |

## Progress

See each phase's TODO file for detailed tasks and progress tracking.
