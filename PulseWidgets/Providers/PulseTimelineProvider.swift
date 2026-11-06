import WidgetKit
import SwiftUI
import AppIntents
// import PulseCore

public struct PulseEntry: TimelineEntry {
    public let date: Date
    public let snapshot: SystemSnapshot?

    public init(date: Date = Date(), snapshot: SystemSnapshot? = nil) {
        self.date = date
        self.snapshot = snapshot
    }
}

public struct PulseTimelineProvider: TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> PulseEntry {
        PulseEntry(date: Date(), snapshot: .preview)
    }

    public func getSnapshot(in context: Context, completion: @escaping (PulseEntry) -> Void) {
        if context.isPreview {
            completion(PulseEntry(date: Date(), snapshot: .preview))
            return
        }
        completion(load())
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<PulseEntry>) -> Void) {
        let entry = load()
        // Refresh policy: 5 minutes as safety fallback; app pushes updates via reloadAllTimelines()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date().addingTimeInterval(300)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func load() -> PulseEntry {
        if let snap = SharedSnapshotStore.shared.loadOptional() {
            let ramGB = Int((Double(snap.system.totalRAM) / pow(1024, 3)).rounded())
            PulseLog.widget.info("[WIDGET] snapshot leído: chip=\(snap.system.chipName, privacy: .public), ram=\(ramGB, privacy: .public)GB")
            return PulseEntry(date: Date(), snapshot: snap)
        } else {
            PulseLog.widget.warning("[WIDGET] snapshot NO disponible — mostrando estado sin datos")
            return PulseEntry(date: Date(), snapshot: nil)
        }
    }
}

public typealias PulseProvider = PulseTimelineProvider

// MARK: - Reusable Widget Container View with "No data" state
public struct WidgetContainerView<Content: View>: View {
    public let snapshot: SystemSnapshot?
    public let content: (SystemSnapshot) -> Content

    public init(snapshot: SystemSnapshot?, @ViewBuilder content: @escaping (SystemSnapshot) -> Content) {
        self.snapshot = snapshot
        self.content = content
    }

    public var body: some View {
        if let snapshot = snapshot {
            content(snapshot)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                Text("Sin datos")
                    .font(.system(size: 11, weight: .bold))
                Text("abre Pulse Monitor")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(for: .widget) {
                Color.clear
            }
        }
    }
}

// MARK: - App Intents for Interactive Widgets
public struct RefreshPulseWidgetIntent: AppIntent {
    public static var title: LocalizedStringResource { "Actualizar Widget" }
    public static var description: IntentDescription { IntentDescription("Fuerza la recarga de los datos de Pulse Monitor en los widgets.") }

    public init() {}

    public func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
