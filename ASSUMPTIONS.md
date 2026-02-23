# Assumptions

このファイルは、情報不足により推測で実装した箇所を記録する。

## 1. HabitFormView の save() エラーハンドリング

- **ファイル**: `habiterm/Habiterm/Views/HabitForm/HabitFormView.swift:30`
- **不足情報**: save() が throws だが、ローカル SwiftData 操作で発生しうるエラーの種類と、ユーザーへの通知方法が未定義
- **推測**: ローカル SwiftData の書き込みエラーは稀であり、初期実装では try? で簡潔に処理するのが妥当
- **実装**: 保存ボタンのアクション内で `try? viewModel.save()` としてエラーを無視
- **将来の対応**: エラーハンドリング要件が定まった際に、do-catch + Alert 表示等に変更する
