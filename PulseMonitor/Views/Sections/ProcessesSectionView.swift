import SwiftUI
import AppKit
// import PulseCore

@MainActor public struct ProcessesSectionView: View {
    @ObservedObject public var viewModel: ProcessesViewModel

    @MainActor public init(viewModel: ProcessesViewModel? = nil) {
        self.viewModel = viewModel ?? SystemMonitor.shared.processesVM
    }

    public init(monitor: SystemMonitor) {
        self.viewModel = monitor.processesVM
    }

    private var filteredProcesses: [ProcessItem] {
        viewModel.filteredProcesses
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Search & Sort bar
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    TextField("Buscar proceso...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))

                Button(action: { viewModel.sortByCPU.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.sortByCPU ? "cpu" : "memorychip")
                        Text(viewModel.sortByCPU ? "CPU" : "RAM")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }

            // Process items list
            VStack(spacing: 6) {
                if filteredProcesses.isEmpty {
                    Text("No se encontraron procesos")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else {
                    ForEach(filteredProcesses) { item in
                        HStack(spacing: 10) {
                            // Process icon / initial
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 24, height: 24)
                                Text(item.name.prefix(1).uppercased())
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.primary)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                Text("PID: \(item.pid)")
                                    .font(.system(size: 9))
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // CPU %
                            Text(Formatters.percentage(item.cpuPercentage))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(item.cpuPercentage > 50.0 ? .red : (item.cpuPercentage > 20.0 ? .orange : .primary))
                                .frame(width: 50, alignment: .trailing)

                            // RAM
                            Text(Formatters.bytes(item.memoryBytes))
                                .font(.system(size: 11, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .trailing)

                            // Terminate button with inline confirmation
                            if viewModel.processToTerminate?.pid == item.pid {
                                HStack(spacing: 4) {
                                    Button("¿Salir?") {
                                        PulseLog.ui.info("🛑 Terminar proceso confirmado para PID: \(item.pid) (\(item.name))")
                                        SystemMonitor.shared.terminateProcess(pid: item.pid)
                                        viewModel.processToTerminate = nil
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.red)
                                    .controlSize(.mini)

                                    Button("No") {
                                        PulseLog.ui.info("↩️ Cancelar terminar proceso para PID: \(item.pid)")
                                        viewModel.processToTerminate = nil
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                }
                            } else {
                                Button(action: {
                                    PulseLog.ui.info("⚠️ Solicitar terminar proceso para PID: \(item.pid) (\(item.name))")
                                    viewModel.processToTerminate = item
                                }) {
                                    Image(systemName: "xmark.circle")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .padding(4)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                .help("Forzar salida de \(item.name)")
                            }
                        }
                        .padding(.vertical, 2)

                        if item.id != filteredProcesses.last?.id {
                            Divider().opacity(0.3)
                        }
                    }
                }
            }
            .liquidGlassCard()
        }
    }
}
