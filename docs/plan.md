# План — StreamingChat (~6–8 ч)

## 0. Перед написанием кода (30 мин)
- Получить ключ OpenRouter; проверить потоковую передачу через `curl`.
- Написать `docs/task.md`, `docs/plan.md`, `CLAUDE.md`.
- Запустить отсчёт времени.

## 1. Скелет (1 ч)
- `project.yml` (XcodeGen, target iOS 18).
- `Build.command` (`chmod +x`): генерация + сборка + запуск в симуляторе.
- `.gitignore` (игнорировать сгенерированный `.xcodeproj`).
- Пустое приложение SwiftUI, которое собирается и запускается.
- **Первый коммит.**

## 2. Слой API (1–1.5 ч)
- `OpenRouterClient`: потоковая передача SSE через `URLSession.bytes(for:)`,
  разбор строк `data:`.
- Отмена через `Task` → **Стоп**.
- Типы ошибок: нет сети, HTTP 429 (лимит), декодирование, общая.
- `APIKey.swift`: обфусцированные XOR байты ключа, восстановление во время выполнения.

## 3. Хранение (1 ч)
- SwiftData `@Model` `Chat` и `Message`.
- `ModelContainer` в App.
- Создание / удаление чатов; их список.

## 4. UI и состояния (1.5–2 ч)
- `NavigationSplitView`: список чатов ↔ диалог.
- Пузыри сообщений (пользователь vs ассистент).
- Пустой экран, баннер ошибки + **Повторить**, индикатор загрузки/потока.
- Светлая и тёмная тема.

## 5. Тестирование (1 ч)
- Сборка и запуск в iOS Simulator (iOS 26.5; target iOS 18).
- Тест без сети → сценарий ошибка + Повторить.
- Запуск `./Build.command` из чистого клона.

## 6. README и zip (30 мин)
- Заполнить шаблон README; скопировать и очистить `ai-logs/`; упаковать zip с `.git`.

## Обзор архитектуры
```
Sources/
  App/        StreamingChatApp, ContentView (корневой split view)
  Models/     Chat, Message  (SwiftData @Model)
  Services/   OpenRouterClient (SSE), APIKey (XOR), ChatError
  Views/      ChatListView, ConversationView, MessageBubble, экраны состояний
  Resources/  Assets.xcassets
```

## Заметки о рисках
- 8 ГБ ОЗУ: держать открытым один симулятор за раз; собирать из терминала, а не из GUI Xcode.
- Установлен только симулятор iOS 26.5 — target iOS 18, тестирование на 26.5.
- Дневные бесплатные лимиты — минимум живых вызовов API при разработке.

---

## Этап 2: опциональные функции

Бонусные функции, которые можно сделать, если останется время. Для каждой — краткий
подход и критерии готовности. Приоритет по трудозатратам: фото → Mac → офлайн.

### 2.1. Фото во вложении — ГОТОВО

**Как сделано.**
- `PhotosPicker` (`PhotosUI`) в панели ввода; превью над полем с кнопкой удаления.
- Сжатие перед отправкой (≤1024px, JPEG 0.7) через ImageIO (кросс-платформенно).
- Отправка в OpenAI-совместимом формате content parts (`type: image_url`,
  `data:image/jpeg;base64,…`) — кастомный `Encodable` в `OpenRouterClient`.
- Авто-выбор vision-модели при наличии фото (цепочка gemma → nemotron-vl →
  openrouter/free), иначе основная модель.
- Хранение вложения в `Message.imageData` с `@Attribute(.externalStorage)`,
  миниатюра в пузыре; переживает перезапуск.
- Ошибки: модель без vision → `imageUnsupported`, большой файл → `imageTooLarge`,
  обе с кнопкой «Повторить».

**Критерии готовности:** ✅ прикрепление, превью, отправка, миниатюра после
перезапуска, обработка ошибок.

### 2.2. Версия для Mac — ГОТОВО

**Выбранный вариант и почему.** Использован **один мультиплатформенный таргет**
через `supportedDestinations: [iOS, macOS]` в `project.yml` (XcodeGen), а **не**
отдельный macOS-таргет. Это проще: одна цель, одна схема, один общий набор
исходников и настроек — не нужно дублировать конфигурацию и синхронизировать два
таргета. Это **нативный** AppKit-бэкенд SwiftUI, а не Mac Catalyst. Минимальная
версия macOS — 15.0.

**Как сделано.**
- iOS-специфичный код изолирован через `#if os(iOS)` / `#if os(macOS)`.
- Кросс-платформенный слой `Sources/Platform/Platform.swift`:
  - изображения: `UIImage` ↔ `NSImage` через `Image(data:)`;
  - сжатие фото — через **ImageIO** (`CGImageSource`/`CGImageDestination`),
    одинаково на обеих платформах (вместо `UIGraphicsImageRenderer`);
  - буфер обмена: `UIPasteboard` ↔ `NSPasteboard`;
  - цвета: `secondarySystemBackground` ↔ `controlBackgroundColor`.
- `navigationBarTitleDisplayMode`, `scrollDismissesKeyboard`, панель инструментов
  `topBar*` — под `#if os(iOS)`; на macOS используются кросс-платформенные
  `ToolbarItemPlacement`.
- На Mac: `NavigationSplitView` с сайдбаром; отправка по **Enter**, перенос строки
  по **Shift+Enter** (через `onKeyPress(keys:)`); минимальный размер окна
  (`windowResizability(.contentMinSize)` + `frame(minWidth:minHeight:)`); светлая и
  тёмная тема. `PhotosPicker` работает и на macOS.
- `Build.command` вторым шагом собирает macOS-версию (`-destination platform=macOS`),
  ad-hoc подписывает и открывает её — без ручных команд.

**Критерии готовности:** ✅ обе платформы собираются из одного `project.yml`
(BUILD SUCCEEDED, без предупреждений); macOS-приложение запускается нативно;
`./Build.command` собирает iOS под симулятор и macOS-версию.

### 2.3. Офлайн-режим на Apple Foundation Models (iOS 26+/macOS 26+) — ГОТОВО

**Как сделано.**
- Протокол `ChatProvider` (общий streaming-интерфейс `AsyncThrowingStream`):
  `CloudProvider` (OpenRouter) и `OnDeviceProvider` (`LanguageModelSession.streamResponse`).
- Весь код `FoundationModels` под `#if canImport(FoundationModels)` +
  `if #available(iOS 26.0, macOS 26.0, *)`. На iOS 18 — без изменений, через OpenRouter.
- `OnDeviceAvailability` на базе `SystemLanguageModel.default.availability`: обработаны
  устройство не поддерживается / Apple Intelligence выключен / модель загружается.
- `NetworkMonitor` (NWPathMonitor): при отсутствии сети и доступной on-device модели —
  авто-офлайн с заметной меткой «Offline · on-device»; плюс ручной тумблер в меню.
- История передаётся в сессию с обрезкой старых сообщений под бюджет контекста.
- Фото в офлайне заблокированы; «Стоп» отменяет и on-device генерацию (Task cancel).
- Нет on-device и нет сети → прежняя ошибка «Нет сети» + «Повторить».

**Критерии готовности:** ✅ сборка iOS 18 и последней iOS (BUILD SUCCEEDED, без
предупреждений); все случаи доступности обработаны; запуск без сбоев.
**Ограничение:** живая on-device генерация требует реального устройства с включённым
Apple Intelligence (в симуляторе модель обычно недоступна).
