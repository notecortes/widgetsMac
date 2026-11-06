import SwiftUI
import EventKit
import CoreLocation
// import PulseCore

@MainActor
public final class OnboardingViewModel: ObservableObject {
    @Published public var calendarGranted: Bool = false
    @Published public var isRequestingCalendar: Bool = false

    public init() {}

    public func requestCalendarAccess() {
        isRequestingCalendar = true
        Task {
            let store = EKEventStore()
            do {
                let granted = try await store.requestFullAccessToEvents()
                await MainActor.run {
                    self.calendarGranted = granted
                    self.isRequestingCalendar = false
                }
            } catch {
                await MainActor.run {
                    self.isRequestingCalendar = false
                }
            }
        }
    }
}

public struct OnboardingView: View {
    @ObservedObject private var vm = OnboardingViewModel()

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            // Header Icon & Title
            VStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 44))
                    .foregroundColor(.accentColor)

                Text("Bienvenido a Pulse Monitor")
                    .font(.system(size: 20, weight: .bold))

                Text("Monitorización avanzada de hardware, alertas inteligentes y widgets nativos para macOS.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 10)

            Divider()

            // Permissions explanation
            VStack(alignment: .leading, spacing: 14) {
                // Calendar Permission
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Acceso a Calendario")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Permite detectar reuniones próximas (Google Meet, Zoom, Teams) y unirte con un clic desde la barra de menús o los widgets.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(vm.calendarGranted ? "Concedido" : "Permitir") {
                        vm.requestCalendarAccess()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(vm.calendarGranted)
                }

                // Wi-Fi / Location Permission
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "wifi")
                        .font(.system(size: 22))
                        .foregroundColor(.green)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Detalles de Red Wi-Fi")
                            .font(.system(size: 13, weight: .semibold))
                        Text("macOS requiere permiso de localización para leer el nombre de la red (SSID) y canal Wi-Fi. Sin este permiso, la app mostrará solo velocidades y consumo sin nombre de red.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                // Privacy guarantee
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 14))
                    Text("100% Privado y Local: sin telemetría ni analítica.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.1)))
            }
            .padding(.horizontal, 14)

            Spacer()

            // Start button
            Button(action: {
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                NSApp.keyWindow?.close()
            }) {
                Text("Comenzar a Monitorizar")
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .frame(width: 460, height: 440)
    }
}
