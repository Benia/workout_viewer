# Workout Viewer (Android)

Пульс, темп, высота, зоны, карта с треком. Зум пальцами. CSV / GPX.

---

## Собрать APK через GitHub (без установки Flutter)

### 1. Создайте репозиторий
1. Зайдите на https://github.com → **New repository**
2. Имя, например `workout_viewer`
3. **Public** (проще и бесплатно)
4. Create repository

### 2. Загрузите проект
PowerShell, из папки с распакованным архивом:

```bat
cd путь\к\workout_android
git init
git add .
git commit -m "Workout Viewer"
git branch -M main
git remote add origin https://github.com/ВАШ_ЛОГИН/workout_viewer.git
git push -u origin main
```

(GitHub попросит войти.)

### 3. Дождитесь сборки
1. Репозиторий на GitHub → вкладка **Actions**
2. **Build Android APK** — ждите зелёную галочку (5–15 мин)

### 4. Скачайте APK
1. Actions → успешный run
2. Внизу **Artifacts** → **workout-viewer-apk**
3. Скачайте zip → внутри `app-release.apk`
4. На телефон и установить

Повторно: **Actions → Build Android APK → Run workflow**.

---

## Что умеет

- CSV / GPX (FIT — позже)
- Пульс + темп + высота + зоны
- Мощность — выключатель
- Зум щипком, прокрутка, поворот
- Карта + трек; палец по графику → точка на карте
