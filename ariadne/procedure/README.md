# Ariadne — Procedure Index

> [roadmap/](../roadmap/) の各フェーズ・セクションを実装／理解するための手順書。
> 「何をやるか」が roadmap、「どうやるか・どう確かめるか」が procedure。

## 使い方

1. 対応するフェーズの roadmap TODO を開く
2. このディレクトリの該当セクション手順書をそのまま上から実行する
3. 完了したら roadmap の TODO にチェックを入れる

## Phase 0 — OCaml Basics & Environment
- [01 Environment Setup](phase0/01-environment-setup.md)
- [02 Language Fundamentals](phase0/02-language-fundamentals.md)
- [03 Module System](phase0/03-module-system.md)
- [04 Practice](phase0/04-practice.md)

## Phase 1 — AST Traversal Skeleton
- [01 AST Understanding](phase1/01-ast-understanding.md)
- [02 Recursive Traversal](phase1/02-recursive-traversal.md)
- [03 First Metric: Lines of Code](phase1/03-loc-metric.md)
- [04 Second Metric: Cyclomatic Complexity](phase1/04-cyclomatic-complexity.md)
- [05 Nesting Depth (Optional)](phase1/05-nesting-depth.md)
- [06 CLI Integration](phase1/06-cli-integration.md)

## Phase 2 — Reading TypeScript (tree-sitter)
- [01 tree-sitter Setup](phase2/01-tree-sitter-setup.md)
- [02 FFI / Binding](phase2/02-ffi-binding.md)
- [03 Tree Structure Understanding](phase2/03-tree-structure-understanding.md)
- [04 Logic Migration](phase2/04-logic-migration.md)

## Phase 3 — Cyclomatic Complexity MVP
- [01 Comprehensive Branch Coverage](phase3/01-comprehensive-branch-coverage.md)
- [02 Function/Method Granularity](phase3/02-function-method-granularity.md)
- [03 Cognitive Complexity](phase3/03-cognitive-complexity.md)
- [04 Output Formatting](phase3/04-output-formatting.md)
- [05 Validation](phase3/05-validation.md)

## Phase 4 — Repository-wide Scan
- [01 Directory Traversal](phase4/01-directory-traversal.md)
- [02 Threshold & Warnings](phase4/02-threshold-warnings.md)
- [03 Configuration](phase4/03-configuration.md)
- [04 Report Output](phase4/04-report-output.md)
- [05 Error Handling & Robustness](phase4/05-error-handling.md)
- [06 Performance (Optional)](phase4/06-performance.md)
- [07 Real-world Validation](phase4/07-real-world-validation.md)

## Phase 5 — CI Integration & Python Extension
- [01 CI Integration](phase5/01-ci-integration.md)
- [02 Python Support](phase5/02-python-support.md)
- [03 Multi-language Architecture](phase5/03-multi-language-architecture.md)
- [04 Documentation & Distribution](phase5/04-documentation-distribution.md)

## 手順書の共通フォーマット

各手順書は次の構成で書かれている。

| セクション | 役割 |
|------------|------|
| Goal | この手順を終えたら何が手に入るか |
| Prerequisites | 前提となる完了済み手順 |
| Steps | 実行する操作を順番に |
| Verification | 完了の確認方法 |
| Pitfalls / Tips | はまりどころと回避策 |
| Outputs | この手順で生まれる成果物 |
| Next | 次に進むべき手順 |
