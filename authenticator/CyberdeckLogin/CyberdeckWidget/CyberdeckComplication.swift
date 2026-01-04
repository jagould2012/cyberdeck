import WidgetKit
import SwiftUI

@main
struct CyberdeckWidgetBundle: WidgetBundle {
    var body: some Widget {
        CyberdeckComplication()
    }
}

struct CyberdeckComplication: Widget {
    let kind: String = "CyberdeckComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Cyberdeck")
        .description("Quick unlock your devices")
        #if os(watchOS)
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular,
            .accessoryInline
        ])
        #endif
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date()))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = SimpleEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct ComplicationView: View {
    var entry: SimpleEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 24))
            }
        case .accessoryCorner:
            Image(systemName: "lock.open.fill")
                .font(.system(size: 20))
                .widgetLabel {
                    Text("Unlock")
                }
        case .accessoryRectangular:
            HStack {
                Image(systemName: "lock.open.fill")
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text("Cyberdeck")
                        .font(.headline)
                    Text("Tap to unlock")
                        .font(.caption)
                }
            }
        case .accessoryInline:
            Label("Unlock", systemImage: "lock.open.fill")
        @unknown default:
            Image(systemName: "lock.open.fill")
        }
    }
}
