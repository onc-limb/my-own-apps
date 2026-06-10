# telos — コンセプトとエビデンス

## 問題

ビジネスパーソンの仕事の情報は、4つの場面で「持っているのに使えない」状態になる。

| 場面 | 症状 | 根本原因 |
|------|------|----------|
| リリース前 | 確認漏れ・手順抜けが毎回どこかで起きる | やるべきことが記憶と経験の中にだけある |
| 進捗報告 | 作るのに時間がかかり、しかも伝わらない | 「起きたこと」の時系列羅列で、結論が先頭にない |
| 要件・打ち合わせ | 言われた通り作ったのに満足されない | 表層の要望の奥にある「本当の目的」を掘っていない |
| ビジネス説明 | 資料が情報過多で、結局何を決めたいのか伝わらない | 相手の意思決定に必要な最小限に絞れていない |

4つは別々の症状に見えるが、共通の根は1つ：**情報が「記録」のままで、目的に向かう道具になっていない。**

## エビデンス

### 1. チェックリストは専門家の「抜け」を確実に減らす

- Haynes et al. (2009) は、WHO の19項目の手術安全チェックリストを8カ国の病院に導入した結果、**合併症率が 11.0% → 7.0%、院内死亡率が 1.5% → 0.8% に低下**したことを示した。高度な専門家チームですら、記憶に頼る限り基本的な確認を落とす。
- Gawande (2009) はこの知見を一般化し、複雑な業務での失敗の多くが「無知（知らない）」ではなく「知っているのにやり損ねる」ことによるものであり、チェックリストがその対策になると論じた。
- ソフトウェアリリースは、関係者が多く・手順が多く・一回性が高いという点で手術と同型の問題構造を持つ。

### 2. 報告と説明は「結論ファースト」の構造が意思決定者に効く

- Minto のピラミッド原則（McKinsey で開発、Minto 1987）は、**結論を先頭に置き、それを支える論点を3つ程度にグルーピングして配置する**構造を提唱する。意思決定者は結論を先に掴んでから根拠を検証する認知の流れを持つため、この順序が認知負荷を下げる。
- telos の **Slides** は先頭スライドを「状況サマリー（結論）」に固定する。**Brief** は「背景 → 提案 → 期待効果 → コスト → 意思決定のお願い」という、相手が判断に必要な最小要素だけに絞った一枚に落とす。情報を足すのではなく削ることで伝わる。

### 3. 「なぜ」の反復は表層の要望から根本の目的に降りる

- 5 Whys は大野耐一がトヨタ生産方式の中で「トヨタの科学的アプローチの基本」として定式化した手法（Ohno 1988）。なぜを繰り返すことで、症状ではなく原因の連鎖を遡る。
- ただし批判もある：5 Whys は単一の因果連鎖しか追えず、根拠なく「なぜ」に答えると自信を持って間違える。telos では、**会話ログという実データから出発する**（憶測ではなく発言の引用から掘る）ことでこの弱点を緩和する。
- Jobs to Be Done（Christensen et al., 2016）は、顧客の要望の奥には「遂げたい進歩（job）」があり、機能要望ではなく job を特定すべきだと論じる。Goals の最終出力を JTBD 形式（「〜の状況で、〜したい。そうすれば〜できる」）にするのはこのため。

## AI 支援の位置づけ

LLM 連携は**任意の上乗せ**であって前提ではない。各ツールはヒューリスティック（マーカー検出・テンプレート構造）だけで完結する。AI を有効にすると、Goals の発言抽出と「なぜ」の提案、Brief の下書き生成が強化される。

- API キーを画面に持たせず、ローカルブリッジ（`server/`）に隔離する。
- **サブスクリプション（`claude -p`）** を一級市民として扱う。トークン課金の API キーがなくても、既存の Claude 契約でそのまま使える。LiteLLM 互換 API も選べる。

## 知見と機能の対応

| 知見 | 機能 |
|------|------|
| チェックリストは専門家の不注意を防ぐ（Haynes 2009, Gawande 2009） | Checklist |
| 結論ファースト構造が報告・説明を伝わるものにする（Minto 1987） | Slides / Brief |
| 実データから「なぜ」を掘ると根本の目的に届く（Ohno 1988, Christensen 2016） | Goals |

## 出典

- Haynes, A.B. et al. "A Surgical Safety Checklist to Reduce Morbidity and Mortality in a Global Population." *New England Journal of Medicine* 360 (2009): 491–499. <https://www.nejm.org/doi/abs/10.1056/NEJMsa0810119>
- Gawande, A. *The Checklist Manifesto: How to Get Things Right.* Metropolitan Books (2009).
- Minto, B. *The Pyramid Principle: Logic in Writing and Thinking.* Minto International (1987). 解説: <https://www.betterup.com/blog/minto-pyramid>
- Ohno, T. *Toyota Production System: Beyond Large-Scale Production.* Productivity Press (1988). 批判含む概観: <https://en.wikipedia.org/wiki/Five_whys>
- Christensen, C., Hall, T., Dillon, K., & Duncan, D. "Know Your Customers' Jobs to Be Done." *Harvard Business Review* (2016). <https://hbr.org/2016/09/know-your-customers-jobs-to-be-done>
