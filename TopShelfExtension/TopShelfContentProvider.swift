@preconcurrency import TVServices

@objc(TopShelfContentProvider)
final class TopShelfContentProvider: TVTopShelfContentProvider, @unchecked Sendable {

    // Return simple test content using sectioned content API
    override func loadTopShelfContent() async -> TVTopShelfContent? {
        // Use a simple, known-working poster image
        let testImageURL = URL(string: "https://image.tmdb.org/t/p/w500/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg")!

        let item1 = TVTopShelfSectionedItem(identifier: "test-1")
        item1.title = "Test Movie 1"
        item1.setImageURL(testImageURL, for: .screenScale1x)
        item1.setImageURL(testImageURL, for: .screenScale2x)
        item1.imageShape = .poster

        let item2 = TVTopShelfSectionedItem(identifier: "test-2")
        item2.title = "Test Movie 2"
        item2.setImageURL(testImageURL, for: .screenScale1x)
        item2.setImageURL(testImageURL, for: .screenScale2x)
        item2.imageShape = .poster

        // Create a section with the items
        let section = TVTopShelfItemCollection(items: [item1, item2])
        section.title = "Now Showing"

        return TVTopShelfSectionedContent(sections: [section])
    }

    private func formatShowtime(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Tomorrow \(formatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE h:mm a"
            return formatter.string(from: date)
        }
    }
}
