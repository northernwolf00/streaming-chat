# StreamingChat

Нативное AI-приложение-чат для iPhone, iPad и Mac на SwiftUI. Ответ ассистента отображается токен за токеном в реальном времени, генерацию можно остановить в любой момент, а история переписок сохраняется локально. Поддерживаются вложение изображений, переключение моделей и офлайн-режим на базе Apple Foundation Models.

## Возможности

- **Потоковая генерация** — ответы приходят токен за токеном через `URLSession.bytes(for:)` и Server-Sent Events (SSE).
- **Прерывание ответа** — кнопка «Стоп» отменяет текущую задачу (`Task.cancel()`) и сохраняет уже полученную часть текста (работает как онлайн, так и офлайн).
- **Несколько чатов и история** — боковая панель со списком диалогов, превью и временем последнего сообщения; удаление отдельных чатов (свайпом и через контекстное меню) и полная очистка истории. Данные хранятся в SwiftData (`Chat` и `Message`).
- **Выбор модели** — переключение прямо из тулбара чата с сохранением выбора:
  - **Auto** (по умолчанию) — автоматический fallback по цепочке бесплатных моделей;
  - отдельные модели: ERNIE 5.5 Flash, Gemma 4 31B, Nemotron 3.5 VL, OpenRouter Free. При отправке фото автоматически подбирается vision-модель.
- **Вложение фото** — выбор через `PhotosPicker`, превью перед отправкой, сжатие через ImageIO (до 1024 px, JPEG 0.7), передача в формате `image_url` (data URL) и хранение в SwiftData с `@Attribute(.externalStorage)`.
- **Офлайн-режим (Apple Foundation Models)** — при потере сети (`NWPathMonitor`) или через ручной переключатель приложение переходит на локальную модель (`LanguageModelSession`) с индикатором `Offline · on-device`. Используется проверка `SystemLanguageModel.availability`; весь код изолирован под `#if canImport(FoundationModels)` и `#available(iOS 26, macOS 26, *)`, поэтому проект без проблем работает на iOS 18 и macOS 15.
- **Нативный macOS** — единый мультиплатформенный таргет (не Catalyst): отправка по `Enter`, новая строка по `Shift+Enter`, сайдбар, минимальный размер окна.
- **Состояния и UX** — индикатор набора, баннер ошибки с кнопкой «Повторить» (нет сети, лимит 429, модель не поддерживает фото), пустые экраны, копирование сообщений, время и дата под каждым пузырём, светлая и тёмная темы.

## Стек

- **Язык и UI:** Swift 6, SwiftUI, SwiftData
- **Системные фреймворки:** `Foundation`, `PhotosUI`, `Network`, `ImageIO`, `FoundationModels` (iOS 26+ / macOS 26+) — без сторонних зависимостей
- **Сборка:** XcodeGen (`project.yml` → `StreamingChat.xcodeproj`)
- **Облачный API:** OpenRouter (`chat/completions` с `stream: true`)
- **Минимальные версии:** iOS 18.0, macOS 15.0

## Сборка и запуск

### Быстрый старт

Запустите `Build.command` двойным кликом в Finder (или из терминала `./Build.command`) — скрипт при необходимости установит XcodeGen, сгенерирует проект, соберёт и запустит приложение в iOS Simulator, а затем соберёт и откроет нативную версию для macOS.

### Вручную

```sh
xcodegen generate
open StreamingChat.xcodeproj
```

После открытия выберите схему `StreamingChat` (iOS Simulator или My Mac) и запустите проект (`⌘R`).

## API-ключ

Чтобы не хранить ключ открытым текстом в исходниках и не светить его в таблице строк бинарника, в `Sources/Services/APIKey.swift` используется XOR-обфускация (`pad` и `obfuscated`), а восстановление происходит во время выполнения.

Для подстановки собственного ключа OpenRouter можно перегенерировать байтовые массивы скриптом:

```sh
swift scripts/ObfuscateKey.swift "sk-or-v1-...."
```

## Структура проекта

```text
project.yml            Конфигурация XcodeGen (мультиплатформенный таргет iOS 18 + macOS 15)
Build.command          Скрипт сборки и запуска для iOS Simulator и macOS
scripts/
  ObfuscateKey.swift   Генератор XOR-обфусцированного API-ключа
Sources/
  App/                 Точка входа и корневой NavigationSplitView
  Models/              Модели SwiftData (Chat, Message)
  Services/            OpenRouterClient (SSE), OnDeviceProvider (Foundation Models),
                       NetworkMonitor, AIModel, APIKey, ChatError
  Views/               Список чатов, экран диалога, пузыри сообщений, состояния и ViewModel
  Platform/            Кросс-платформенные обёртки (изображения, буфер обмена, цвета)
  Resources/           Assets.xcassets
```
