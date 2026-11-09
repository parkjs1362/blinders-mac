# Blinders

Dim everything except the window you are using. A small Mac app for the Dock and the menu bar.

macOS 14 or later. The download is not notarized, so the first open needs an extra click. No account, no screen recording permission.

**English** · [한국어](#한국어)

## Install

1. Download `Blinders-0.1.0.zip` from [Releases](../../releases).
2. Unzip it and move `Blinders.app` to `/Applications`.
3. Right-click `Blinders.app` and choose **Open**, then **Open** again. The Dock icon is a window split into a bright half and a dim half.
4. Open **System Settings → Privacy & Security → Accessibility** and turn Blinders on. If the switch is already on and nothing dims, turn it off and on once.

The settings window opens from the Dock icon, or from **B** in the menu bar.

## Settings

- **On** turns dimming on or off. The front window stays bright. Other windows and the desktop dim. The menu bar and Dock stay bright.
- **Darkness** is 50% by default. The slider runs from 10% to 90%.
- **Pause** for 10 minutes or 1 hour.
- **Launch at login** works after the app is in `/Applications`.

Click the desktop and the shade goes away. Choose a window again and it comes back. If the front app has no window, the whole screen dims.

## Build

```bash
./scripts/bundle.sh
open build/Blinders.app
```

A new build changes the code signature, so Accessibility must be turned off and on again.

## License

[MIT](LICENSE) © 2026 Joonit

## 한국어

쓰는 창만 밝게 두고, 다른 창과 바탕화면을 어둡게 합니다.

1. [Releases](../../releases)에서 `Blinders-0.1.0.zip`을 받습니다.
2. 압축을 풀고 `Blinders.app`을 `/Applications`로 옮깁니다.
3. 앱을 오른쪽 클릭해서 **열기**를 두 번 누릅니다. 공증되지 않은 앱이라 첫 실행만 이렇게 합니다.
4. **시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용**에서 Blinders를 켭니다. 이미 켜져 있는데 어두워지지 않으면 한 번 끄고 다시 켭니다.

Dock 아이콘이나 메뉴막대의 **B**로 설정 창을 엽니다. 사용, 어둡기, 10분·1시간 일시정지, 로그인 시 실행이 있습니다.
