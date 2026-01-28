# Cinecenta Android Port Plan

## Executive Summary

This document outlines the plan for porting the Cinecenta iOS app to Android. The iOS app is ~6,100 lines of Swift/SwiftUI with a clean MVVM architecture, making it well-suited for porting. The Android version will use Kotlin and Jetpack Compose to mirror the modern declarative UI approach.

---

## 1. Technology Stack

### Recommended Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| Language | Kotlin | Modern, concise, null-safe |
| UI Framework | Jetpack Compose | Declarative UI like SwiftUI |
| Architecture | MVVM + Repository | Matches iOS architecture |
| Async | Kotlin Coroutines + Flow | Equivalent to Swift async/await |
| DI | Hilt | Standard Android DI |
| Networking | Retrofit + OkHttp | Industry standard |
| JSON Parsing | Kotlinx Serialization | Native Kotlin support |
| Image Loading | Coil | Compose-native, coroutine-based |
| Local Storage | Room + DataStore | Structured + preferences |
| Background Work | WorkManager | Replaces iOS BackgroundTasks |
| Notifications | NotificationManager | Local notifications |
| Widgets | Glance | Compose-based widgets |
| Graph Visualization | Custom Canvas or Vico | No direct Grape equivalent |
| YouTube Player | android-youtube-player | Similar to YouTubePlayerKit |

### Minimum SDK
- **minSdk: 26** (Android 8.0) - Covers 95%+ of devices
- **targetSdk: 34** (Android 14)

---

## 2. Project Structure

```
app/
├── src/main/
│   ├── java/com/latenightsw/cinecenta/
│   │   ├── CinecentaApp.kt              # Application class
│   │   ├── MainActivity.kt              # Single activity
│   │   │
│   │   ├── data/                        # Data layer
│   │   │   ├── model/                   # Data models
│   │   │   │   ├── Movie.kt
│   │   │   │   ├── Showtime.kt
│   │   │   │   ├── TMDbModels.kt
│   │   │   │   ├── MovieConnection.kt
│   │   │   │   └── WatchProvider.kt
│   │   │   │
│   │   │   ├── remote/                  # Network services
│   │   │   │   ├── CinecentaApi.kt      # Web scraping
│   │   │   │   ├── TMDbApi.kt           # TMDb API
│   │   │   │   └── WikidataApi.kt       # SPARQL queries
│   │   │   │
│   │   │   ├── local/                   # Local storage
│   │   │   │   ├── MovieDao.kt          # Room DAO
│   │   │   │   ├── MovieDatabase.kt     # Room database
│   │   │   │   └── PreferencesManager.kt
│   │   │   │
│   │   │   └── repository/              # Repositories
│   │   │       ├── MovieRepository.kt
│   │   │       ├── TMDbRepository.kt
│   │   │       └── ConnectionsRepository.kt
│   │   │
│   │   ├── domain/                      # Business logic
│   │   │   ├── usecase/
│   │   │   │   ├── GetMoviesUseCase.kt
│   │   │   │   ├── GetMovieConnectionsUseCase.kt
│   │   │   │   └── ScheduleReminderUseCase.kt
│   │   │   └── util/
│   │   │       ├── TitleMatcher.kt
│   │   │       └── HtmlDecoder.kt
│   │   │
│   │   ├── ui/                          # Presentation layer
│   │   │   ├── theme/
│   │   │   │   ├── Theme.kt
│   │   │   │   ├── Color.kt
│   │   │   │   └── Type.kt
│   │   │   │
│   │   │   ├── navigation/
│   │   │   │   └── CinecentaNavGraph.kt
│   │   │   │
│   │   │   ├── movielist/
│   │   │   │   ├── MovieListScreen.kt
│   │   │   │   ├── MovieListViewModel.kt
│   │   │   │   └── MovieRowItem.kt
│   │   │   │
│   │   │   ├── moviedetail/
│   │   │   │   ├── MovieDetailScreen.kt
│   │   │   │   ├── MovieDetailViewModel.kt
│   │   │   │   └── components/
│   │   │   │       ├── TrailerSection.kt
│   │   │   │       ├── ShowtimesSection.kt
│   │   │   │       ├── StreamingSection.kt
│   │   │   │       └── ReminderSheet.kt
│   │   │   │
│   │   │   ├── connections/
│   │   │   │   ├── ConnectionsScreen.kt
│   │   │   │   ├── ConnectionsViewModel.kt
│   │   │   │   ├── ConnectionsPreview.kt
│   │   │   │   └── NetworkGraphView.kt
│   │   │   │
│   │   │   └── components/              # Shared components
│   │   │       ├── MoviePoster.kt
│   │   │       ├── GenreChip.kt
│   │   │       ├── RatingBadge.kt
│   │   │       └── LoadingState.kt
│   │   │
│   │   ├── notification/
│   │   │   ├── NotificationHelper.kt
│   │   │   └── ReminderReceiver.kt
│   │   │
│   │   ├── widget/
│   │   │   ├── TonightWidget.kt
│   │   │   └── WidgetReceiver.kt
│   │   │
│   │   ├── worker/
│   │   │   └── RefreshWorker.kt
│   │   │
│   │   └── di/                          # Dependency injection
│   │       ├── AppModule.kt
│   │       ├── NetworkModule.kt
│   │       └── DatabaseModule.kt
│   │
│   ├── res/
│   │   ├── values/
│   │   ├── drawable/
│   │   └── raw/
│   │       └── curated_connections.json  # Bundled database
│   │
│   └── AndroidManifest.xml
│
├── build.gradle.kts
└── proguard-rules.pro
```

---

## 3. Component Mapping

### Data Models (Direct Port)

| iOS (Swift) | Android (Kotlin) |
|-------------|------------------|
| `Showtime` struct | `data class Showtime` |
| `Movie` struct | `data class Movie` |
| `TMDbMovieInfo` | `data class TMDbMovieInfo` |
| `WatchProvider` | `data class WatchProvider` |
| `MovieNode`, `MovieEdge`, `MovieGraph` | Same structure |
| `CuratedMovieConnections.json` | Copy to `res/raw/` |

### Services → Repositories

| iOS Service | Android Equivalent |
|-------------|-------------------|
| `CinecentaService` (actor) | `CinecentaRepository` + `CinecentaApi` |
| `TMDbService` (actor) | `TMDbRepository` + Retrofit interface |
| `WikidataService` (actor) | `WikidataRepository` + Retrofit |
| `CuratedConnectionsService` | `CuratedConnectionsRepository` |
| `MovieCache` (actor) | Room Database + `MovieDao` |
| `FoundationModelService` | Gemini Nano (if available) or skip |

### UI Components

| iOS View | Android Composable |
|----------|-------------------|
| `MovieListView` | `MovieListScreen` |
| `MovieRowView` | `MovieRowItem` |
| `MovieDetailView` | `MovieDetailScreen` |
| `MovieConnectionsView` | `ConnectionsScreen` |
| `MovieConnectionsPreview` | `ConnectionsPreview` |
| `MovieNetworkGraphView` | `NetworkGraphView` (Canvas) |
| `YouTubePlayerView` | `YouTubePlayerView` (library) |
| `ReminderSelectionSheet` | `ReminderBottomSheet` |
| `FlowLayout` | `FlowRow` (Compose) |

### Platform Features

| iOS Feature | Android Equivalent |
|-------------|-------------------|
| `BackgroundTaskManager` | `WorkManager` with `PeriodicWorkRequest` |
| `NotificationManager` | `NotificationManagerCompat` + `AlarmManager` |
| WidgetKit | Glance (Jetpack Compose for widgets) |
| Deep links (`cinecenta://`) | Intent filters + Navigation DeepLinks |
| `@Observable` | `StateFlow` + `collectAsState()` |
| `AsyncImage` | `AsyncImage` (Coil) |

---

## 4. Implementation Phases

### Phase 1: Project Setup & Core Data Layer
**Estimated effort: Foundation work**

- [ ] Create new Android Studio project with Compose
- [ ] Configure Gradle dependencies
- [ ] Set up Hilt dependency injection
- [ ] Port data models (`Movie`, `Showtime`, `TMDbMovieInfo`, etc.)
- [ ] Implement `CinecentaApi` for web scraping
- [ ] Set up Room database for caching
- [ ] Create `MovieRepository` with offline support

**Key files to create:**
- `build.gradle.kts` with all dependencies
- All data model classes
- `CinecentaApi.kt` - JSoup for HTML parsing
- `MovieDatabase.kt` and `MovieDao.kt`

### Phase 2: TMDb Integration
**Estimated effort: API integration**

- [ ] Set up Retrofit for TMDb API
- [ ] Port `TMDbService` logic to `TMDbRepository`
- [ ] Implement title matching algorithm
- [ ] Add TMDb response models
- [ ] Implement in-memory LRU cache
- [ ] Add watch provider support

**Key files:**
- `TMDbApi.kt` - Retrofit interface
- `TMDbRepository.kt` - Business logic
- `TitleMatcher.kt` - Fuzzy matching

### Phase 3: Movie List Screen
**Estimated effort: Main UI**

- [ ] Create app theme (Material 3)
- [ ] Implement `MovieListViewModel`
- [ ] Build `MovieListScreen` composable
- [ ] Create `MovieRowItem` component
- [ ] Add pull-to-refresh
- [ ] Implement loading/error states
- [ ] Progressive TMDb enrichment

**Key files:**
- `Theme.kt`, `Color.kt`, `Type.kt`
- `MovieListScreen.kt`
- `MovieListViewModel.kt`

### Phase 4: Movie Detail Screen
**Estimated effort: Complex UI**

- [ ] Implement `MovieDetailViewModel`
- [ ] Build `MovieDetailScreen` with all sections
- [ ] Integrate YouTube player library
- [ ] Create streaming provider section with deep links
- [ ] Implement showtime grouping by date
- [ ] Add share functionality

**Key files:**
- `MovieDetailScreen.kt`
- `MovieDetailViewModel.kt`
- `TrailerSection.kt`, `StreamingSection.kt`

### Phase 5: Notifications & Reminders
**Estimated effort: Platform integration**

- [ ] Create notification channel
- [ ] Implement `NotificationHelper`
- [ ] Create `ReminderReceiver` (BroadcastReceiver)
- [ ] Build reminder selection bottom sheet
- [ ] Add reminder state tracking
- [ ] Handle notification permissions (Android 13+)

**Key files:**
- `NotificationHelper.kt`
- `ReminderReceiver.kt`
- `ReminderBottomSheet.kt`

### Phase 6: Movie Connections
**Estimated effort: Complex feature**

- [ ] Port `CuratedConnectionsRepository`
- [ ] Bundle `curated_connections.json`
- [ ] Implement `WikidataRepository` with SPARQL
- [ ] Create `ConnectionsViewModel`
- [ ] Build `ConnectionsScreen` with list view
- [ ] Implement `NetworkGraphView` with Canvas
- [ ] Add data source badges

**Key files:**
- `CuratedConnectionsRepository.kt`
- `WikidataRepository.kt`
- `ConnectionsScreen.kt`
- `NetworkGraphView.kt`

### Phase 7: Background Refresh
**Estimated effort: WorkManager integration**

- [ ] Create `RefreshWorker`
- [ ] Schedule periodic refresh (30 min minimum)
- [ ] Handle work constraints (network, battery)
- [ ] Update cached data

**Key files:**
- `RefreshWorker.kt`
- `WorkerModule.kt`

### Phase 8: Widgets
**Estimated effort: Glance widgets**

- [ ] Create Glance widget receiver
- [ ] Build `TonightWidget` composable
- [ ] Implement widget data provider
- [ ] Add deep link handling
- [ ] Support multiple widget sizes

**Key files:**
- `TonightWidget.kt`
- `WidgetReceiver.kt`

### Phase 9: Deep Linking & Polish
**Estimated effort: Final integration**

- [ ] Configure intent filters for `cinecenta://`
- [ ] Implement Navigation deep links
- [ ] Add app shortcuts
- [ ] Performance optimization
- [ ] Edge case handling
- [ ] Testing

---

## 5. Key Technical Challenges

### 1. Web Scraping
**iOS:** Uses Foundation's URL loading and regex
**Android Solution:** Use JSoup library for HTML parsing

```kotlin
// Example: CinecentaApi.kt
suspend fun fetchMovies(): List<Movie> {
    val doc = Jsoup.connect("https://www.cinecenta.com/calendar/").get()
    val scripts = doc.select("script[type=application/ld+json]")
    // Parse JSON-LD schema.org data
}
```

### 2. Force-Directed Graph
**iOS:** Uses Grape library
**Android Solution:** Custom Canvas implementation or adapt a library

```kotlin
@Composable
fun NetworkGraphView(graph: MovieGraph) {
    Canvas(modifier = Modifier.fillMaxSize()) {
        // Implement force-directed layout algorithm
        // Draw nodes and edges
    }
}
```

Consider libraries:
- Custom implementation with Compose Canvas
- GraphView library (adapted)
- D3.js in WebView (fallback)

### 3. YouTube Player
**iOS:** YouTubePlayerKit
**Android Solution:** android-youtube-player library

```kotlin
implementation("com.pierfrancescosoffritti.androidyoutubeplayer:core:12.1.0")
```

### 4. Streaming App Deep Links
**iOS:** Checks `canOpenURL` for app schemes
**Android Solution:** Use `PackageManager` to check installed apps

```kotlin
fun isAppInstalled(packageName: String): Boolean {
    return try {
        packageManager.getPackageInfo(packageName, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }
}
```

### 5. On-Device AI (Optional)
**iOS:** Foundation Models (iOS 26+)
**Android Solution:** Gemini Nano via ML Kit (limited availability)

This feature could be omitted initially, relying on curated database + Wikidata.

---

## 6. Dependencies (build.gradle.kts)

```kotlin
dependencies {
    // Core
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("androidx.activity:activity-compose:1.8.2")

    // Compose
    implementation(platform("androidx.compose:compose-bom:2024.02.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")

    // Navigation
    implementation("androidx.navigation:navigation-compose:2.7.7")

    // Hilt
    implementation("com.google.dagger:hilt-android:2.50")
    kapt("com.google.dagger:hilt-compiler:2.50")
    implementation("androidx.hilt:hilt-navigation-compose:1.1.0")

    // Networking
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.2")
    implementation("com.jakewharton.retrofit:retrofit2-kotlinx-serialization-converter:1.0.0")

    // HTML Parsing
    implementation("org.jsoup:jsoup:1.17.2")

    // Image Loading
    implementation("io.coil-kt:coil-compose:2.5.0")

    // Room
    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    kapt("androidx.room:room-compiler:2.6.1")

    // DataStore
    implementation("androidx.datastore:datastore-preferences:1.0.0")

    // WorkManager
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    implementation("androidx.hilt:hilt-work:1.1.0")

    // Widgets (Glance)
    implementation("androidx.glance:glance-appwidget:1.0.0")
    implementation("androidx.glance:glance-material3:1.0.0")

    // YouTube Player
    implementation("com.pierfrancescosoffritti.androidyoutubeplayer:core:12.1.0")

    // Testing
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
}
```

---

## 7. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Graph visualization complexity | High | Medium | Start simple, iterate |
| Web scraping brittleness | Medium | High | Same as iOS, monitor for changes |
| Streaming deep link variations | Medium | Low | Test on real devices |
| Widget data sync issues | Medium | Medium | Use WorkManager + proper state |
| YouTube API restrictions | Low | Medium | Use established library |

---

## 8. Testing Strategy

### Unit Tests
- Repository logic
- Title matching algorithm
- Data model parsing
- Use case validation

### Integration Tests
- API responses (mock server)
- Database operations
- WorkManager tasks

### UI Tests
- Compose UI tests
- Navigation flows
- Screenshot tests

### Manual Testing
- Real device testing for widgets
- Notification behavior
- Deep link handling
- Streaming app integration

---

## 9. Alternatives Considered

### Cross-Platform Options

| Option | Pros | Cons |
|--------|------|------|
| **Kotlin Multiplatform** | Share business logic | Still need native UI |
| **Flutter** | Single codebase | Rewrite everything |
| **React Native** | Single codebase | Performance concerns |
| **Native Android** | Best UX, full control | More work |

**Recommendation:** Native Android with Kotlin/Compose provides the best user experience and maintainability, matching the quality of the iOS app.

---

## 10. Maintenance Considerations

- Keep curated database in sync between platforms
- Monitor Cinecenta website for scraping changes
- Update TMDb API usage as needed
- Coordinate feature releases across platforms
- Consider shared Kotlin Multiplatform module for business logic in future

---

## Summary

The Cinecenta iOS app has a clean architecture that maps well to Android. The main challenges are:

1. **Graph visualization** - No direct Grape equivalent; requires custom implementation
2. **Platform APIs** - Different patterns for notifications, background work, widgets

The recommended approach is native Android with Jetpack Compose, following the same MVVM architecture. This will result in an app that feels native to Android users while maintaining feature parity with iOS.

Estimated total effort: 8-12 weeks for a single developer, depending on experience with Android development.
