# zg01-linux

[English](README.md) | **日本語**

ヤマハのゲームストリーミングミキサー **ZG01** を、Linuxで通話用のマイク・スピーカーとして使うための設定ファイル集です（Zoom、Slackのハドル、Discordなど）。

> **非公式プロジェクトです。** ヤマハ株式会社とは一切関係がなく、動作の保証もありません。自己責任でご利用ください。

## 対応状況

| 機能 | 状況 |
|---|---|
| オーディオデバイスとしての認識 | ✅（下記のmodprobe設定が必要） |
| 再生（10ch） | ✅ |
| マイク録音 | ✅ |
| 「ZG01 Chat」「ZG01 Mic」での通話 | ✅ |
| 配信用ミックス（Streaming）の録音 | ⚠️ 未検証（後述） |
| ZG Controllerの機能（エフェクト、ミキサー設定） | ❌ Linuxでは使用不可 |

検証環境：Ubuntu 26.04（カーネル 7.0.0-30-generic、PipeWire / WirePlumber 1.6.2）

## そのままでは動かない理由

ZG01（USB ID `0499:1513`）の中身はほぼ標準のUSB Audio Class 2.0ですが、インターフェースが「ベンダー独自クラス（255）」として申告されています。Linuxカーネルは個別の登録（quirk）がないとこれを扱えず、ZG01の登録はまだありません（兄弟機のZG02は登録済み）。そのため、何もしないとMIDIデバイスとしてしか認識されません。

Steinberg UR22（`0499:1509`）がZG01と同じインターフェース構成なので、このプロジェクトでは「ZG01をUR22として扱う」ようカーネルに指示しています。

## インストール

```bash
git clone https://github.com/mint-rabi/zg01-linux.git
cd zg01-linux
./install.sh
```

スクリプトは次の3つのファイルを配置します。

| ファイル | 役割 |
|---|---|
| `/etc/modprobe.d/zg01.conf` | カーネルのドライバにZG01を認識させる |
| `~/.config/wireplumber/wireplumber.conf.d/51-zg01.conf` | 録音フォーマットをS32LEに固定する |
| `~/.config/pipewire/pipewire.conf.d/zg01.conf` | 仮想デバイス「ZG01 Mic」「ZG01 Chat」を作る |

あとは通話アプリで次のように選ぶだけです。

- **出力：ZG01 Chat**
- **入力：ZG01 Mic**

通話用途なら、ZG Controllerでの設定変更は不要です。

アンインストールは `./uninstall.sh` を実行してください。

## チャンネル構成

**再生（10ch、S32_LE、48kHz）**

| チャンネル | ZG01の系統 | Windowsでのデバイス名 |
|---|---|---|
| 0〜7 | ゲーム（7.1chサラウンド） | スピーカー (Yamaha ZG01) |
| 8〜9 | ボイスチャット | Voice (Yamaha ZG01) |

**録音（4ch、S32_LE、48kHz）**

| チャンネル | ZG01の系統 | Windowsでのデバイス名 |
|---|---|---|
| 0〜1 | 配信用ミックス | Streaming (Yamaha ZG01) |
| 2〜3 | マイク | Voice (Yamaha ZG01) |

「ZG01 Chat」はボイスチャットの系統に出力されるので、本体のボイスチャットレベルノブで音量を調節できます。標準の「Yamaha ZG01 Multichannel」に出した音は、ゲームの系統（ch0〜1）に入ります。

## トラブルシューティング

**ZG01がまったく表示されない**
`sudo dmesg | grep "quirk alias"` で `applying quirk alias 0499:1509` と出るか確認してください。インストール後は、ZG01を抜き差しするか再起動してください。

**「ZG01 Mic」「ZG01 Chat」が表示されない**
設定はPipeWireの標準のノード名を前提にしています。`wpctl status` や `pactl list short sources` で名前を確認し、違っていれば `config/pipewire/zg01.conf` の `target.object` を書き換えてください。

**マイクがノイズになる、または無音**
`pactl list short sources | grep -i zg01` で録音フォーマットが `s32le` になっているか確認してください。`float32le` のままなら、WirePlumberの設定が効いていません（WirePlumber 0.5以降が必要です）。

**マイクの音量が小さい**
出力の小さいダイナミックマイクでは、ゲインノブを最大近くまで上げる必要があることがあります。マイクに近づいて話す、ファンタム電源で動くインラインのマイクブースターを使う、またはソフトウェアで増幅する（`wpctl set-volume <ZG01 MicのID> 2.0`）などで対処してください。

**配信用ミックス（録音ch0〜1）が無音**
ZG01は初期状態では、配信用ミックスをHDMI OUTにだけ出力します。Windows/MacのZG Controllerで、STREAMING OUTPUT MIXER画面の「USB」をONにすると、USBにも送られるはずです。この設定は本体に保存されると考えられますが、Linuxでの動作は未検証です。また、HDMI入力にHDCPがかかっている場合は、USBには出力されません。

## ライセンス

MIT
