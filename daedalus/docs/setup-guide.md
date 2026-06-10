# daedalus セットアップ手順書（AWS / Google Cloud / Cloudflare）

Terraform の導入から daedalus の設定・実行までを、対応3プロバイダ（AWS / Google Cloud /
Cloudflare）ごとに解説する。

> **前提となる考え方**
> daedalus は内部でヘッドレス Claude Code を動かし、その Bash ツールから `terraform` を実行する。
> つまり **daedalus を起動する環境（あなたの端末／コンテナ）に、`terraform` バイナリとクラウドの
> 認証情報が揃っていれば良い**。認証は各 Terraform プロバイダの「デフォルト認証チェーン」（≒環境変数や
> CLI のログイン状態）に委ねる設計なので、daedalus 側にキーを書く必要はない。

全体の流れ:

1. [Terraform を導入する](#1-terraform-を導入する)
2. [daedalus 本体をセットアップする](#2-daedalus-本体をセットアップする)
3. プロバイダの認証を設定する → [AWS](#3a-aws) / [Google Cloud](#3b-google-cloud) / [Cloudflare](#3c-cloudflare)
4. [spec を書く](#4-spec-を書く)
5. [実行する（plan → approval → auto）](#5-実行する)
6. [（任意）GitHub 連携](#6-任意-github-連携)
7. [トラブルシューティング](#7-トラブルシューティング) / [セキュリティ注意](#8-セキュリティ上の注意)

---

## 1. Terraform を導入する

daedalus を動かす環境に Terraform CLI（1.5 以上を推奨）を入れる。

### macOS（Homebrew）

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

### Linux（Debian / Ubuntu, apt）

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

### Windows

```powershell
winget install HashiCorp.Terraform
# または: choco install terraform
```

### バージョンを使い分けたい場合（tfenv）

```bash
brew install tfenv      # macOS。Linux は https://github.com/tfutils/tfenv
tfenv install latest
tfenv use latest
```

直接ダウンロードする場合は公式の手順を参照:
<https://developer.hashicorp.com/terraform/install>

### 確認

```bash
terraform -version
# Terraform v1.x.x が表示されればOK
```

> ⚠️ daedalus は Bash 経由で `terraform` を呼ぶので、**daedalus を起動するのと同じシェル / コンテナの
> PATH** に `terraform` が通っている必要がある。

---

## 2. daedalus 本体をセットアップする

パッケージ管理は [uv](https://docs.astral.sh/uv/)。

```bash
# uv 未導入なら（公式インストーラ）
curl -LsSf https://astral.sh/uv/install.sh | sh

cd daedalus
uv sync          # .venv 作成 + 依存インストール（uv.lock 準拠）
```

### 必須の環境変数

| 変数 | 用途 |
|---|---|
| `ANTHROPIC_API_KEY` | エージェント（Claude）の実行に必須 |

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

### 動作確認

```bash
uv run daedalus --help
uv run daedalus serve   # GUI: http://127.0.0.1:8420（環境変数バッジで設定状況を確認できる）
```

> spec 内の値は `${VAR}` 形式で環境変数を参照できる（アカウント ID やプロジェクト ID をファイルに
> 直書きしないため）。未設定の変数を参照するとエラーになる。

---

## 3. プロバイダの認証を設定する

`terraform` のデフォルト認証チェーンに沿って、**daedalus を起動する環境**に認証情報を用意する。
以下から使うプロバイダを選んで設定する（複数同時もOK）。

---

### 3a. AWS

#### 1) AWS CLI を入れる

```bash
# macOS
brew install awscli
# Linux: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
aws --version
```

#### 2) 認証を設定する（どちらか）

**方式A: IAM Identity Center / SSO（推奨・短命クレデンシャル）**

```bash
aws configure sso          # 対話で SSO を設定し、プロファイル名を付ける（例: daedalus）
aws sso login --profile daedalus
export AWS_PROFILE=daedalus
export AWS_REGION=ap-northeast-1
```

**方式B: IAM ユーザのアクセスキー**

```bash
aws configure              # Access Key / Secret / region を入力（~/.aws に保存）
# もしくは環境変数で直接:
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_REGION="ap-northeast-1"
```

daedalus が参照する主な環境変数: `AWS_PROFILE` / `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` /
`AWS_SESSION_TOKEN` / `AWS_REGION`。

#### 3) 確認

```bash
aws sts get-caller-identity   # アカウントID・ARN が返ればOK
```

> 🔐 検証用は**専用のサンドボックスアカウント**を使い、IAM は必要最小限の権限に絞る。
> `auto` モード（完全自動運転）はこのサンドボックスアカウントで使うこと。

---

### 3b. Google Cloud

#### 1) gcloud CLI を入れる

```bash
# macOS
brew install --cask google-cloud-sdk
# Linux: https://cloud.google.com/sdk/docs/install
gcloud --version
```

#### 2) 認証を設定する（どちらか）

**方式A: ADC（Application Default Credentials, 推奨・ローカル開発）**

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
export GOOGLE_PROJECT="YOUR_PROJECT_ID"
export GOOGLE_REGION="asia-northeast1"
```

**方式B: サービスアカウントキー（CI / 非対話環境）**

```bash
# サービスアカウントを作成して必要なロールを付与し、JSON キーを発行する
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/sa-key.json"
export GOOGLE_PROJECT="YOUR_PROJECT_ID"
export GOOGLE_REGION="asia-northeast1"
```

daedalus が参照する主な環境変数: `GOOGLE_APPLICATION_CREDENTIALS` / `GOOGLE_PROJECT`（=
`GOOGLE_CLOUD_PROJECT`）/ `GOOGLE_REGION`。

#### 3) 使う API を有効化する

```bash
# 例: Compute / Cloud Storage を使うなら
gcloud services enable compute.googleapis.com storage.googleapis.com
```

#### 4) 確認

```bash
gcloud auth list
gcloud auth application-default print-access-token >/dev/null && echo "ADC OK"
```

> 🔐 サービスアカウントキー（JSON）は機密。リポジトリに絶対コミットしない（`.gitignore` 済みの場所に置く）。
> 可能なら方式A（ADC）か Workload Identity を優先する。

---

### 3c. Cloudflare

#### 1) API トークンを作る（推奨・グローバルキーより安全）

Cloudflare ダッシュボード → **My Profile → API Tokens → Create Token** で、操作したいリソースに
絞ったトークンを発行する（例: Zone DNS Edit、Workers Scripts Edit など）。

```bash
export CLOUDFLARE_API_TOKEN="..."
# 多くのリソースでアカウントIDが必要
export CLOUDFLARE_ACCOUNT_ID="..."
```

（レガシーのグローバル API キーを使う場合のみ: `CLOUDFLARE_API_KEY` + `CLOUDFLARE_EMAIL`。非推奨。）

#### 2) 確認

```bash
curl -s "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | grep -o '"status":"active"' \
  && echo "token OK"
```

> 🔐 トークンはリソース・権限を最小限にスコープし、必要なら有効期限を設定する。
> `CLOUDFLARE_ACCOUNT_ID` / `CLOUDFLARE_ZONE_ID` は spec 内では `${CLOUDFLARE_ACCOUNT_ID}` の形で参照する。

---

## 4. spec を書く

spec は「何を作りたいか」を緩く書く YAML。`provider` を対象クラウドに合わせる。
各プロバイダの例は [`examples/`](../examples) にある。

### AWS（[`examples/spec.example.yaml`](../examples/spec.example.yaml)）

```yaml
name: demo-static-site
provider: aws
region: ap-northeast-1
description: |
  - 静的サイト配信用の S3 バケット + CloudFront
constraints:
  - すべてのリソースに tags { project = "daedalus-demo" } を付ける
  - state はローカルバックエンド
terraform:
  required_version: ">= 1.5.0"
  backend: local
```

### Google Cloud（[`examples/gcp.example.yaml`](../examples/gcp.example.yaml)）

```yaml
name: demo-gcs-site
provider: gcp
region: asia-northeast1
description: |
  - 静的サイト用の Cloud Storage バケット（公開）
constraints:
  - project は変数で受け取り、値は環境変数 GOOGLE_PROJECT を使う
  - provider バージョンはピン留めする
terraform:
  required_version: ">= 1.5.0"
  backend: local
```

### Cloudflare（[`examples/cloudflare.example.yaml`](../examples/cloudflare.example.yaml)）

```yaml
name: demo-dns
provider: cloudflare
description: |
  - example.com ゾーンに A レコードと CNAME を作成
constraints:
  - account_id / zone_id は変数で受け取り、値は環境変数から渡す
  - 認証は CLOUDFLARE_API_TOKEN（プロバイダのデフォルト）に委ねる
terraform:
  required_version: ">= 1.5.0"
  backend: local
```

> `region` は AWS / GCP では使うが、Cloudflare には概念がないので省略する。
> アカウント ID・プロジェクト ID・ゾーン ID は spec に直書きせず、`${VAR}` か Terraform 変数経由で
> 環境変数から渡す。

---

## 5. 実行する

まず安全な `plan`（dry-run）で確認し、問題なければ `approval` / `auto` に進む。

```bash
# 1) dry-run（デフォルト）— terraform plan まで。実リソースは作らない
uv run daedalus run examples/spec.example.yaml --workspace ./workspace

# 2) 承認モード — apply のたびに承認を求める（本番想定）
uv run daedalus run examples/gcp.example.yaml --workspace ./workspace --mode approval

# 3) 完全自動運転 — 承認なしで apply（★サンドボックスアカウントで）
uv run daedalus run examples/spec.example.yaml --workspace ./workspace --mode auto
```

リソースを削除する `terraform destroy` を許可する場合のみ `--allow-destroy` を付ける
（`approval` モードでは破棄も承認対象になる）。

### GUI で操作・レビューする

```bash
uv run daedalus serve     # → http://127.0.0.1:8420
```

- Spec を貼ってモードを選び **実行**。ログがリアルタイムに流れる
- `approval` モードでは直前の `plan` 出力つきの**承認カード**が出る → ✅承認 / ❌却下
- 画面上部のバッジで `ANTHROPIC_API_KEY` / `GITHUB_TOKEN` / `GITHUB_OWNER` の設定状況を確認できる

> モードの詳細は [`README.md`](../README.md#実行モード) を参照。

---

## 6. （任意）GitHub 連携

プロジェクトのコードをリポジトリで管理し、API 経由で pull / push できる。

```bash
export GITHUB_TOKEN="github_pat_..."   # contents read/write 権限の PAT
export GITHUB_OWNER="your-account"
```

spec に `github:` を追加:

```yaml
github:
  repo: my-infra-project
  owner: ${GITHUB_OWNER}   # 省略時も GITHUB_OWNER を使う
  branch: main
```

```bash
uv run daedalus pull examples/spec.example.yaml --workspace ./workspace   # 取得
uv run daedalus push examples/spec.example.yaml --workspace ./workspace -m "update"  # 反映
```

実行時に「実行前 pull」「成功後 push」を GUI のチェックボックスや run オプションで有効にもできる。
push は**追加・更新のみ**（リポジトリ側のファイル削除はしない）で、state や `.tfvars` は除外される。

---

## 7. トラブルシューティング

| 症状 | 原因・対処 |
|---|---|
| `ANTHROPIC_API_KEY is not set` | `export ANTHROPIC_API_KEY=...` を忘れている |
| `terraform: command not found`（ログ内） | daedalus を起動した環境の PATH に terraform が無い（§1） |
| AWS `NoCredentialProviders` / `ExpiredToken` | `aws sso login` し直す、`AWS_PROFILE`/`AWS_REGION` を確認 |
| GCP `could not find default credentials` | `gcloud auth application-default login` か `GOOGLE_APPLICATION_CREDENTIALS` を設定 |
| GCP `API has not been used/enabled` | `gcloud services enable <api>` で該当 API を有効化 |
| Cloudflare `Authentication error (10000)` | `CLOUDFLARE_API_TOKEN` の値・スコープ、`CLOUDFLARE_ACCOUNT_ID` を確認 |
| `environment variable not set: X`（spec ロード時） | spec の `${X}` に対応する環境変数を export する |
| apply が `denied`（dry-run 中） | 仕様。実適用は `--mode approval` か `--mode auto` を指定 |

---

## 8. セキュリティ上の注意

- **クレデンシャルは環境変数 / CLI ログインで渡し、spec や `.tf` に直書きしない**（daedalus の
  システムプロンプトも Claude にそう指示している）。
- **`auto` モードは検証用 / サンドボックスアカウントで**。本番相当のアカウントでは `approval` モードを使い、
  各 apply を人がレビューする。
- IAM / サービスアカウント / API トークンは**最小権限**に絞る。
- サービスアカウントキー（JSON）や `.tfvars`、`*.tfstate` はコミットしない（state には機密が入りうる）。
- GUI は認証なしの localhost 前提。外部公開する場合はリバースプロキシ等で必ず保護する。
