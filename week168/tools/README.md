# tools

App target のビルドには含まれない補助スクリプト（`project.yml` の `sources` は `Week168` のみ）。

## RenderAppIcon.swift

アプリアイコン（D-109「168」）を生成する。図を手で描く代わりにコードで組んであるのは、
**小さいサイズで成立するかを繰り返し確かめながら寸法を詰めた**ため。

```sh
swiftc -O -o /tmp/rendericon tools/RenderAppIcon.swift
/tmp/rendericon /tmp/icons
cp /tmp/icons/icon-1024.png Week168/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
```

`/tmp/icons/contact-sheet.png` に 120 / 87 / 60 / 40 / 29pt を並べたものが出る。
**アイコンを変えるときは、必ずこれを見てから決める**（1024px だけ見て決めると 29pt で潰れる）。

出力は **アルファチャンネルなし**（App Store Connect がアルファ付きアイコンを弾くため）。
