# 2026-11-16 Debug Browser の置き場所

- 決定: 動作確認用のブラウザ（Debug Browser）は agora ではなく my-own-apps の中（`debug-browser/`）に作る。
- 理由: agora は設計の知識を受け渡すツールで、動作確認はその外側の役割になる。
  開発環境の分担（自動で動く TAKT / 並走する ols / 知識を持つ agora）では、TAKT が実装したコードの動作確認は ols が並走して受け持つ範囲になる。
- 設計ルール違反の差し戻し（architecture-sandbox）は agora に残す。
- 次: 企画書の Debug Browser 部分を、こちらの計画として書き直す（ヒアリングは後回しのまま）。
