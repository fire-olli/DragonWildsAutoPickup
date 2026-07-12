## 테스트 환경

- ✅ 싱글플레이에서만 테스트했습니다.
- ⚠️ 멀티플레이에서는 테스트하지 않았습니다.

# DragonWildsAutoPickup (한국어)

이 모드는 RuneScape: Dragonwilds에서 바닥에 떨어진 아이템을 쉽게 획득할 수 있도록 도와주는 UE4SS 기반 Lua 모드입니다.

기능
F9 : 주변 아이템을 한 번만 검색하여 획득 (추천)
F8 : 자동으로 계속 검색하며 획득 (실험 기능, 버벅임이 발생할 수 있음)

F8을 켜두면 주위의 나무돌이 자동루팅되지만 버벅임이 있습니다.

## 설치 방법

1. UE4SS를 설치합니다.
2. DragonWildsAutoPickup 폴더를 다운로드합니다.
3. 아래 폴더에 복사합니다.

Binaries\Win64\ue4ss\Mods\

4. 게임을 실행합니다.
5. F9를 눌러 주변 아이템을 획득합니다.


## UE4SS 다운로드

https://github.com/UE4SS-RE/RE-UE4SS/releases 
위 페이지에서 
<img width="975" height="429" alt="image" src="https://github.com/user-attachments/assets/e3f252e2-a18c-4fe6-9d8c-34a83e071534" />

zDEV-UE4SS_v3.0.1-1009-gc2ac2464.zip

다운로드 하시면 됩니다.





## Folder 구조

## UE4SS

```text
RuneScape Dragonwilds
└── RSDragonwilds
    └── Binaries
        └── Win64
            ├── RSDragonwilds-Win64-Shipping.exe
            ├── dwmapi.dll
            ├── UE4SS.dll
            ├── ue4ss
            └── ...
\steamapps\common\RSDragonwilds\RSDragonwilds\Binaries\Win64\ue4ss
````


## DragonWildsAutoPickup
```text
Binaries
└── Win64
    └── ue4ss
        └── Mods
            └── DragonWildsAutoPickup
                └── Scripts
                    └── main.lua
```
\steamapps\common\RSDragonwilds\RSDragonwilds\Binaries\Win64\ue4ss\Mods\DragonwildsAutoPickup\Scripts


## 올바른 설치
```text
Win64
├── UE4SS.dll
├── dwmapi.dll
├── ue4ss
└── RSDragonwilds-Win64-Shipping.exe
```
## 잘못된 설치
```text
Win64
└── zDEV-UE4SS_v3.0.1-1009-gc2ac2464
    ├── UE4SS.dll
    └── ue4ss
```
 
