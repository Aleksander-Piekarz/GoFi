<div align="center">

# 🏋️ GoFi

### Twój Personalny Trener w Kieszeni

[![Flutter](https://img.shields.io/badge/Flutter-3.6+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-Express_5-339933?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org)
[![MySQL](https://img.shields.io/badge/MySQL-Database-4479A1?style=for-the-badge&logo=mysql&logoColor=white)](https://mysql.com)
[![AI Powered](https://img.shields.io/badge/AI-Gemini_|_GPT_|_Claude-FF6F00?style=for-the-badge&logo=google-gemini&logoColor=white)](#-sztuczna-inteligencja)
[![Version](https://img.shields.io/badge/version-1.1.3-E8710A?style=for-the-badge)](#)

<br/>

Mobilna aplikacja fitness łącząca **AI-generowane plany treningowe**, rozbudowaną **bibliotekę ćwiczeń** oraz **tracking postępów** w jednym miejscu. Dwujęzyczna (🇵🇱 / 🇬🇧), z ciemnym motywem, obsługą jednostek metrycznych i imperialnych.

<br/>

</div>

---

## 📑 Spis treści

- [Funkcjonalności](#-funkcjonalności)
- [Stos technologiczny](#-stos-technologiczny)
- [Architektura](#-architektura)
- [Sztuczna inteligencja](#-sztuczna-inteligencja)
- [Ekrany aplikacji](#-ekrany-aplikacji)
- [API — Endpointy](#-api--endpointy)
- [Baza danych](#-baza-danych)
- [Biblioteka ćwiczeń](#-biblioteka-ćwiczeń)
- [Struktura projektu](#-struktura-projektu)
- [Instalacja i uruchomienie](#-instalacja-i-uruchomienie)
- [Rozwój projektu](#-rozwój-projektu)

---

## ✨ Funkcjonalności

<table>
<tr>
<td width="50%">

### 🧠 Inteligentne planowanie
- AI-generowane plany treningowe (Gemini / GPT / Claude)
- Automatyczny dobór splitów (FBW, Upper/Lower, PPL)
- Algorytm lokalny jako fallback
- Filtrowanie ćwiczeń wg kontuzji i sprzętu
- System zarządzania zmęczeniem (fatigue score)

### 📊 Tracking postępów
- Wykres progresji siłowej per ćwiczenie
- Statystyki: objętość, serie, powtórzenia
- Śledzenie wagi ciała z historią
- Wbudowany krokomierz (pedometer)
- Porównanie postępu od początku (%)

### 🏃 Aktywny trening
- Timer przerw między seriami z dźwiękiem
- Śledzenie faz treningu (rozgrzewka → trening → odpoczynek → cooldown)
- Wstrzymanie i wznowienie treningu
- Auto-wznowienie po crashu aplikacji
- Czas trwania serii

</td>
<td width="50%">

### 📚 Biblioteka ćwiczeń
- **1200+** ćwiczeń z opisami PL/EN
- Filtrowanie: partia ciała, mięśnie, sprzęt, trudność
- Instrukcje, częste błędy, dane bezpieczeństwa
- Animowane GIF-y ćwiczeń
- System alternatyw (zamienniki ćwiczeń)
- Własne ćwiczenia (tworzenie, edycja, usuwanie)

### 🔧 Personalizacja
- Dwujęzyczny interfejs (PL / EN)
- Ciemny / jasny / systemowy motyw
- Jednostki: metryczne / imperialne
- Kreator własnych planów (4 typy splitów)
- Import / eksport planów

### 🔒 Konta i bezpieczeństwo
- JWT autoryzacja z 7-dniowym tokenem
- Szyfrowane przechowywanie danych (Secure Storage)
- Auto-update z własnego serwera (APK)
- System wersjonowania z force-update

</td>
</tr>
</table>

---

## 🛠 Stos technologiczny

### Frontend — Flutter

| Technologia | Wersja | Zastosowanie |
|:-----------:|:------:|:-------------|
| **Flutter** | 3.6+ | Framework UI |
| **Riverpod** | 2.5+ | State management |
| **fl_chart** | 0.68+ | Wykresy i wizualizacje |
| **audioplayers** | 6.0 | Dźwięk timera |
| **pedometer** | 4.0 | Krokomierz |
| **flutter_secure_storage** | 9.2 | Bezpieczne tokeny |
| **share_plus** / **file_picker** | — | Import/eksport planów |
| **intl** | 0.20 | Formatowanie dat |

### Backend — Node.js

| Technologia | Wersja | Zastosowanie |
|:-----------:|:------:|:-------------|
| **Express** | 5.1 | Serwer HTTP |
| **MySQL 2** | 3.14 | Baza danych (connection pooling) |
| **JWT** | 9.0 | Autoryzacja |
| **bcryptjs** | 2.4 | Hashowanie haseł |
| **dotenv** | 16.3 | Konfiguracja środowiskowa |
| **Jest** | 30.2 | Testy jednostkowe |

### AI Providers

| Provider | Model | Rola |
|:--------:|:-----:|:-----|
| **Google** | Gemini 2.5 Flash | Domyślny — szybki i tani |
| **OpenAI** | GPT-4o-mini | Alternatywny |
| **Anthropic** | Claude 3.5 Haiku | Alternatywny |

---

## 🏗 Architektura

```
┌──────────────────────────────────────────────────────────────┐
│                      Flutter App                             │
│                                                              │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐  │
│  │ Screens  │◄──│Providers │◄──│ Services │──►│  Models  │  │
│  │  (UI)    │   │(Riverpod)│   │(API Layer│   │  (Data)  │  │
│  └──────────┘   └──────────┘   └──────────┘   └──────────┘  │
│                                      │                       │
└──────────────────────────────────────┼───────────────────────┘
                                       │ HTTPS / JWT
                                       ▼
┌──────────────────────────────────────────────────────────────┐
│                     Express API                              │
│                                                              │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐  │
│  │  Routes  │──►│  Auth    │──►│Controllers│──►│   DB     │  │
│  │          │   │Middleware │   │           │   │  (MySQL) │  │
│  └──────────┘   └──────────┘   └──────────┘   └──────────┘  │
│                                                    │         │
│  ┌──────────────────────────────────────┐          │         │
│  │         AI Plan Generator            │          │         │
│  │  ┌─────────┐ ┌───────┐ ┌──────────┐ │          │         │
│  │  │ Gemini  │ │  GPT  │ │  Claude  │ │◄─────────┘         │
│  │  └─────────┘ └───────┘ └──────────┘ │                     │
│  └──────────────────────────────────────┘                    │
└──────────────────────────────────────────────────────────────┘
```

**Wzorce projektowe:**
- **Service Layer** — abstrakcja HTTP w dedykowanych serwisach (`AuthService`, `LogService`, `ExerciseService`...)
- **Provider-based DI** — Riverpod jako single source of truth
- **Controller pattern** — logika biznesowa oddzielona od routingu (backend)
- **Middleware chain** — JWT auth → route handler → response

---

## 🤖 Sztuczna inteligencja

System generowania planów treningowych wykorzystuje **podwójną ścieżkę**:

### 1. AI Planner (domyślny)
```
Kwestionariusz użytkownika
        │
        ▼
  Filtrowanie ćwiczeń ← Kontuzje, sprzęt, poziom
        │
        ▼
  Prompt systemowy (elite personal trainer, 20 lat doświadczenia)
        │
        ▼
  LLM (Gemini 2.5 Flash) → Strukturyzowany plan JSON
        │
        ▼
  Walidacja & normalizacja → Zapisanie do MySQL
```

**Prompt AI uwzględnia:**
- Periodyzację opartą na nauce
- Biomechanikę i fizjologię wysiłku
- Tolerancję zmęczenia użytkownika
- Cele treningowe (siła / hipertrofia / wytrzymałość)
- Sloty czasowe i dostępny sprzęt

### 2. Algorytm lokalny (fallback)
Deterministyczny algorytm w JavaScript (3100+ linii) z:
- Priorytetyzacją ćwiczeń "optimal tier"
- Zarządzaniem wynikiem zmęczenia
- Gwarantowaną liczbą ćwiczeń
- Doborem splitów na podstawie liczby dni treningowych

---

## 📱 Ekrany aplikacji

| # | Ekran | Opis |
|:-:|:------|:-----|
| 1 | **Starting Screen** | Ekran powitalny z tłem |
| 2 | **Login / Register** | Logowanie i rejestracja z walidacją |
| 3 | **Home** | Dashboard: krokomierz, waga, dzisiejszy trening, wznów trening |
| 4 | **Plan View** | Widok planu treningowego z trybem edycji |
| 5 | **Custom Plan Builder** | Kreator planów (FBW / Upper-Lower / PPL / Custom) |
| 6 | **Active Workout** | Aktywny trening: timery, serie, RPE, fazy, wstrzymanie |
| 7 | **Exercise Library** | Przeszukiwalna baza 1200+ ćwiczeń z filtrami |
| 8 | **Exercise Detail** | Szczegóły ćwiczenia: instrukcje, błędy, bezpieczeństwo, GIF |
| 9 | **Exercise Stats** | Wykres progresji, rekord, objętość, historia treningów |
| 10 | **Workout Details** | Podsumowanie ukończonego treningu |
| 11 | **Questionnaire** | Kwestionariusz fitness (cel, doświadczenie, kontuzje...) |
| 12 | **Profile** | Ustawienia: język, motyw, jednostki, powiadomienia |

---

## 🌐 API — Endpointy

<details>
<summary><b>POST /api/auth</b> — Autoryzacja</summary>

| Metoda | Endpoint | Opis |
|:------:|:---------|:-----|
| POST | `/register` | Rejestracja nowego użytkownika |
| POST | `/login` | Logowanie, zwraca JWT |
</details>

<details>
<summary><b>GET/PUT /api/users</b> — Użytkownicy</summary>

| Metoda | Endpoint | Opis |
|:------:|:---------|:-----|
| PUT | `/me/settings` | Aktualizacja ustawień (jednostki, powiadomienia, cel kroków) |
</details>

<details>
<summary><b>/api/exercises</b> — Biblioteka ćwiczeń</summary>

| Metoda | Endpoint | Opis |
|:------:|:---------|:-----|
| GET | `/` | Lista ćwiczeń (paginacja) |
| GET | `/search` | Wyszukiwanie |
| GET | `/muscles` | Dostępne grupy mięśniowe |
| GET | `/equipment` | Dostępny sprzęt |
| GET | `/:code` | Szczegóły ćwiczenia |
| GET | `/:code/alternatives` | Alternatywne ćwiczenia |
| GET | `/custom/list` | Własne ćwiczenia użytkownika |
| POST | `/custom` | Dodaj własne ćwiczenie |
| PUT | `/custom/:id` | Edytuj własne ćwiczenie |
| DELETE | `/custom/:id` | Usuń własne ćwiczenie |
</details>

<details>
<summary><b>/api/questionnaire</b> — Kwestionariusz</summary>

| Metoda | Endpoint | Opis |
|:------:|:---------|:-----|
| GET | `/` | Pytania kwestionariusza |
| GET | `/answers/latest` | Ostatnie odpowiedzi |
| POST | `/answers` | Zapisz odpowiedzi |
| GET | `/plan/latest` | Pobierz aktualny plan |
| PUT | `/plan/latest` | Aktualizuj plan |
| POST | `/submit` | Wyślij kwestionariusz i wygeneruj plan (AI) |
| POST | `/plan/custom` | Zapisz własny plan |
</details>

<details>
<summary><b>/api/log</b> — Logowanie treningów</summary>

| Metoda | Endpoint | Opis |
|:------:|:---------|:-----|
| POST | `/workout` | Zapisz ukończony trening |
| GET | `/workouts` | Historia treningów |
| GET | `/workout/:id` | Szczegóły treningu |
| GET | `/exercise/:code` | Historia ćwiczenia (max waga, serie, objętość) |
| GET | `/logged-exercises` | Lista logowanych ćwiczeń |
| POST | `/weight` | Zapisz wagę ciała |
| GET | `/weight-history` | Historia wagi |
| POST | `/latest-for-exercises` | Ostatnie dane dla zestawu ćwiczeń |
</details>

<details>
<summary><b>/api/workout</b> — Sesje treningowe</summary>

| Metoda | Endpoint | Opis |
|:------:|:---------|:-----|
| POST | `/session/start` | Rozpocznij lub wznów sesję |
| GET | `/session/current` | Sprawdź aktywną sesję |
| POST | `/session/set/start` | Rozpocznij serię |
| POST | `/session/set/end` | Zakończ serię |
| POST | `/session/transition` | Zmień fazę (warmup → training → rest) |
| POST | `/session/end` | Zakończ sesję |
| POST | `/session/abandon` | Porzuć sesję |
| POST | `/session/heartbeat` | Utrzymaj sesję przy życiu |
</details>

<details>
<summary><b>/api/app-version</b> — Aktualizacje</summary>

| Metoda | Endpoint | Opis |
|:------:|:---------|:-----|
| GET | `/` | Informacje o aktualnej wersji |
| GET | `/check/:version` | Sprawdź czy jest nowsza wersja |
</details>

---

## 🗃 Baza danych

```sql
-- Główne tabele
users                 -- Konta użytkowników (bcrypt, role, ustawienia)
exercises             -- 1200+ ćwiczeń (dwujęzyczne, tier, fatigue_score)
user_custom_exercises -- Własne ćwiczenia użytkowników
plans                 -- Wygenerowane plany treningowe
questionnaire_answers -- Odpowiedzi z kwestionariusza

-- Logowanie treningów
workout_logs          -- Ukończone treningi
workout_log_sets      -- Serie w ramach treningu (waga, powtórzenia)

-- Sesje na żywo
workout_sessions      -- Aktywne/zakończone/porzucone sesje
workout_activities    -- Fazy sesji (preparation/training/rest/cooldown)
```

---

## 💪 Biblioteka ćwiczeń

Baza danych zawiera **1200+ ćwiczeń** z pełnymi danymi:

```json
{
  "code": "barbell_bench_press",
  "name": { "en": "Barbell Bench Press", "pl": "Wyciskanie sztangi na ławce" },
  "body_part": "CHEST",
  "primary_muscle": "pectoralis major",
  "secondary_muscles": { "en": "anterior deltoid, triceps", "pl": "..." },
  "tier": "optimal",
  "fatigue_score": 7,
  "mechanics": "compound",
  "equipment": "barbell, bench",
  "difficulty": "intermediate",
  "rep_range_type": "hypertrophy",
  "instructions": { "en": ["Step 1...", "Step 2..."], "pl": ["..."] },
  "common_mistakes": { "en": ["..."], "pl": ["..."] },
  "safety_data": { "injuries": ["shoulder", "lower_back"], "tips": ["..."] }
}
```

**System filtrowania:**
- Partia ciała: Nogi, Klatka, Plecy, Barki, Ramiona, Core
- Sprzęt: Sztanga, Hantle, Maszyna, Wyciąg, TRX...
- Trudność: Beginner / Intermediate / Advanced
- Kontuzje: Automatyczne blokowanie niebezpiecznych ćwiczeń

---

## 📁 Struktura projektu

```
GoFi/
├── lib/                          # Flutter — kod źródłowy
│   ├── main.dart                 # Entry point
│   ├── app/
│   │   └── theme.dart            # Dark/Light motyw, kolory
│   ├── models/
│   │   ├── exercise.dart         # Model ćwiczenia
│   │   └── user.dart             # Model użytkownika
│   ├── screens/                  # 14 ekranów UI
│   │   ├── home_screen.dart      # Dashboard (krokomierz, waga, trening dnia)
│   │   ├── active_workout_screen.dart  # Aktywny trening z timerami
│   │   ├── exercise_library_screen.dart # Biblioteka 1200+ ćwiczeń
│   │   ├── exercise_stats_screen.dart  # Statystyki ćwiczenia
│   │   └── ...
│   ├── services/api/             # Warstwa serwisów
│   │   ├── api_client.dart       # HTTP wrapper z JWT
│   │   ├── auth_service.dart     # Logowanie / rejestracja
│   │   ├── exercise_service.dart # CRUD ćwiczeń
│   │   ├── log_service.dart      # Logowanie treningów
│   │   ├── workout_session_service.dart # Sesje na żywo
│   │   └── providers.dart        # Riverpod — DI hub
│   ├── utils/
│   │   ├── converters.dart       # kg ↔ lbs konwerter
│   │   └── language_settings.dart # PL / EN
│   └── widgets/                  # Współdzielone widgety
│
├── gofi-api/                     # Node.js — backend
│   ├── index.js                  # Entry point Express
│   ├── routes/                   # 7 modułów endpointów
│   │   ├── auth.js               # POST /register, /login
│   │   ├── exercises.js          # Biblioteka ćwiczeń
│   │   ├── questionnaire.js      # Kwestionariusz + plan
│   │   ├── log.js                # Historia treningów
│   │   ├── session.js            # Sesje na żywo
│   │   └── ...
│   ├── lib/                      # Logika biznesowa
│   │   ├── aiPlanner.js          # Multi-provider AI (1200 linii)
│   │   ├── algorithm.js          # Fallback algorytm (3100 linii)
│   │   ├── exerciseFilter.js     # Filtrowanie wg kontuzji/sprzętu
│   │   ├── planGenerator.js      # Orkiestrator AI vs local
│   │   └── db.js                 # MySQL connection pool
│   ├── data/
│   │   ├── exercises.json        # 1200+ ćwiczeń
│   │   └── exercise_alternatives.json
│   ├── migrations/               # Schemat SQL
│   └── tools/                    # Seedy, migracje, testy
│
├── assets/
│   ├── images/                   # Tła, splash screen
│   └── sounds/                   # timer_done.mp3
│
├── android/                      # Konfiguracja Android
├── ios/                          # Konfiguracja iOS
├── web/                          # Konfiguracja Web
├── windows/                      # Konfiguracja Windows
├── linux/                        # Konfiguracja Linux
├── macos/                        # Konfiguracja macOS
├── test/                         # Testy Flutter
└── pubspec.yaml                  # Zależności Flutter
```

---

## 🚀 Instalacja i uruchomienie

### Wymagania
- **Flutter SDK** ≥ 3.6.0
- **Node.js** ≥ 18
- **MySQL** ≥ 8.0

### Backend

```bash
cd gofi-api

# Zainstaluj zależności
npm install

# Skonfiguruj zmienne środowiskowe
cp .env.example .env
# Edytuj .env: DB_HOST, DB_USER, DB_PASS, JWT_SECRET, GEMINI_API_KEY...

# Uruchom migracje
node tools/run_migration.js

# Seeduj bazę ćwiczeń
node tools/seed_exercises.js

# Uruchom serwer
node index.js
```

### Frontend (Flutter)

```bash
# Zainstaluj zależności
flutter pub get

# Uruchom na emulatorze / urządzeniu
flutter run

# Build APK (release)
flutter build apk --release
```

---

## 🔮 Rozwój projektu
- [ ] Konta użytkowników (potwierdzenie maila, logowanie przez google/apple)
- [ ] Możliwość posiadania kilku planów
- [ ] Zdjęcia profilowe użytkowników
- [ ] Powiadomienia push (przypomnienia o treningu)
- [ ] Social feed — udostępnianie treningów
- [ ] Integracja z Google Fit / Apple Health
- [ ] Eksport danych do CSV/PDF
- [ ] Tryb offline z synchronizacją

---

<div align="center">

**Zbudowano z** ❤️ **i Flutterem**

[![Flutter](https://img.shields.io/badge/Made_with-Flutter-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![Express](https://img.shields.io/badge/Powered_by-Express-000000?style=flat-square&logo=express)](https://expressjs.com)
[![AI](https://img.shields.io/badge/Enhanced_with-AI-FF6F00?style=flat-square&logo=google-gemini)](https://ai.google.dev)

</div>