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

### 2.1. Фото во вложении
- **Подход:** добавить `PhotosPicker` (framework `PhotosUI`) в панель ввода; выбранное
  изображение кодировать в base64 data URL и отправлять как мультимодальное сообщение
  в формате OpenRouter (массив `content` с частями `type: "text"` и `type: "image_url"`);
  использовать модель с поддержкой зрения (vision), например одну из бесплатных vision-моделей.
  Миниатюру вложения хранить в `Message` (новое поле `imageData: Data?` в SwiftData).
- **Критерии готовности:** пользователь прикрепляет фото, оно отображается в пузыре;
  ассистент отвечает по содержимому изображения; вложение сохраняется между перезапусками;
  при выборе не-vision модели — понятное сообщение/фолбэк.

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

### 2.3. Офлайн-режим на Apple Foundation Models (iOS 26+)
- **Подход:** использовать framework `FoundationModels` (`SystemLanguageModel`,
  `LanguageModelSession`) для генерации на устройстве; весь код — строго под
  `if #available(iOS 26, *)` с фолбэком на OpenRouter для iOS 18; добавить переключатель
  «офлайн / онлайн» и проверку `SystemLanguageModel.default.availability`; переиспользовать
  тот же потоковый интерфейс (`AsyncThrowingStream`), что и сетевой клиент, чтобы UI не менялся.
- **Критерии готовности:** на устройстве/симуляторе с iOS 26 и доступной моделью чат
  работает без сети; потоковый вывод и Стоп функционируют; на iOS 18 функция скрыта,
  приложение продолжает работать через OpenRouter; при недоступности модели — понятное
  состояние.
