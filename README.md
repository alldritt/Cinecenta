# Cinecenta

A native iOS app for browsing movie showtimes at [Cinecenta](https://www.cinecenta.com), the University of Victoria's independent cinema.

## Purpose

Cinecenta is a repertory cinema that screens classic, art-house, and independent films. This app provides a streamlined way to:

- Browse upcoming movie showtimes
- Set reminders for screenings you don't want to miss
- Check tonight's schedule at a glance via Home Screen and Lock Screen widgets

## Features

### Movie List
- View all upcoming movies with poster images
- See showtime ranges at a glance (e.g., "Wed 7:00 PM - Sat 9:30 PM")
- "TODAY" badge highlights movies playing today
- Bell icon indicates movies with active reminders
- Pull-to-refresh for latest schedule

### Movie Details
- Full movie poster display
- All showtimes grouped by date (Today, Tomorrow, or specific dates)
- Tap any showtime to set a reminder
- Share movie details with friends

### Reminders
- Local notification reminders for showtimes
- Choose reminder timing: 15 min, 30 min, 1 hour, or 2 hours before
- Visual indicators show which showtimes have reminders set
- Past showtimes are automatically disabled

### Widgets
- **Home Screen Widgets**: Small, Medium, and Large sizes showing tonight's movies
- **Lock Screen Widgets**: Circular, Rectangular, and Inline styles
- Deep linking: Tap a movie in the widget to open its details
- Auto-refresh every 30 minutes

### Offline Support
- Movie data cached locally for offline viewing
- 24-hour soft cache expiry with 72-hour hard expiry
- Graceful fallback when network is unavailable

### Background Refresh
- Automatic data refresh in the background
- Keeps widgets up-to-date with latest schedule

## Technical Details

- **Platform**: iOS 17+
- **Framework**: SwiftUI with modern `@Observable` macro
- **Architecture**: MVVM with shared services
- **Data Source**: Scraped from cinecenta.com using JSON-LD structured data

## Built with Claude Code

This app was created entirely using [Claude Code](https://claude.com/claude-code), Anthropic's AI-powered coding assistant. The development process showcased Claude Code's capabilities for:

### Initial Development
- **Project Setup**: Created the Xcode project structure with proper targets for the main app and widget extension
- **Data Layer**: Designed and implemented `Movie`, `Showtime`, and related models with proper Codable conformance
- **Web Scraping**: Built `CinecentaService` to fetch and parse JSON-LD movie data from the Cinecenta website
- **UI Implementation**: Created SwiftUI views for movie list, detail screens, and showtime chips with reminder functionality

### Widget Development
- Implemented `WidgetKit` extension with support for 6 different widget families
- Created adaptive layouts for each widget size
- Added deep linking support for navigation from widgets to specific movies

### Feature Implementation
- **Notification System**: Built `NotificationManager` for scheduling and managing local reminders
- **Caching**: Implemented `MovieCache` for offline support with configurable expiry
- **Background Tasks**: Added `BackgroundTaskManager` for keeping data fresh

### Code Quality Improvements
Claude Code assisted with ongoing refinements including:
- Extracting magic numbers into named constants
- Consolidating duplicated date logic into helper methods
- Migrating from `ObservableObject` to the modern `@Observable` macro
- Removing unnecessary `@EnvironmentObject` usage in favor of direct singleton access
- Improving showtime display formatting for multi-day ranges

### Iterative Development
The conversational nature of Claude Code enabled rapid iteration:
- Describing desired features in natural language
- Reviewing generated code and requesting modifications
- Identifying areas for improvement and implementing fixes
- Refactoring code based on best practices suggestions

## Project Structure

```
Cinecenta/
├── Cinecenta/
│   ├── CinecentaApp.swift          # App entry point
│   └── Views/
│       ├── MovieListView.swift     # Main movie list
│       └── MovieDetailView.swift   # Movie detail with showtimes
├── CinecentaWidget/
│   └── CinecentaWidget.swift       # Widget extension
└── Shared/
    ├── SharedModels.swift          # Movie, Showtime models
    ├── CinecentaService.swift      # Data fetching service
    ├── NotificationManager.swift   # Reminder notifications
    ├── MovieCache.swift            # Offline caching
    └── BackgroundTaskManager.swift # Background refresh
```

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
