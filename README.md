# Sabbath School (Суботня Школа)

Офлайн-додаток уроків Суботньої Школи Адвентистів Сьомого Дня для **iPad 1G (iOS 5.1.1)**.

## Що це

Нативний Objective-C додаток (UIKit), який показує щоквартальні уроки з біблійними віршами та перемикачем перекладів Біблії. Працює повністю офлайн — дані вшиті в бандл.

## Для чого

iPad 1G застряг на iOS 5.1.1. Офіційний додаток Sabbath School давно не підтримує цю версію. Цей проєкт — заміна, зібрана через Theos для jailbroken iPad.

## Мови

- `uk` — українська
- `ro` — румунська

## Звідки дані

API: `https://sabbath-school.adventech.io/api/v2`

Це відкритий API проєкту [Adventech](https://github.com/Adventech). Дані завантажуються скриптом `download_days.py` і зберігаються в `data/` та `Resources/data/` (для включення в .app бандл).

### Структура даних
```
data/{lang}/quarterlies.json          — список кварталів
data/{lang}/{quarter}/lessons.json    — список уроків кварталу
data/{lang}/{quarter}/{lesson}/index.json  — деталі уроку
data/{lang}/{quarter}/{lesson}/{day}.json  — текст дня з біблійними віршами
```

### Оновлення даних на новий квартал
1. Відредагувати `QID` в `download_days.py` (напр. `2026-02`)
2. Запустити `python3 download_days.py` (в WSL або де є Python)
3. Скопіювати `data/` в `Resources/data/`
4. Перебілдити і задеплоїти (див. DEPLOY.md)

## Структура проєкту

| Файл | Опис |
|------|------|
| `SSAppDelegate` | Запуск, вибір мови |
| `SSLanguageVC` | Екран вибору мови (uk/ro) |
| `SSQuarterliesVC` | Список кварталів |
| `SSLessonsVC` | Список уроків кварталу |
| `SSReadVC` | Читання дня — WebView з HTML, попап біблійних віршів, перемикач перекладів |
| `SSAPIClient` | Завантаження даних (офлайн з бандлу або онлайн через CFNetwork TLS 1.2) |
| `download_days.py` | Скрипт завантаження даних з API |
| `Makefile` | Theos білд (armv7, iOS 5.0+, SDK 9.3) |
| `layout/DEBIAN/control` | Метадані .deb пакета |

## Білд і деплой

Див. [DEPLOY.md](DEPLOY.md) — покрокова інструкція з готовими командами.

## Toolchain

- **Theos** (~/theos в WSL) — білд-система для iOS
- **SDK**: iPhoneOS 9.3
- **Target**: armv7, iOS 5.0+
- **Підпис**: `ldid -S` (ad-hoc, для jailbroken)
