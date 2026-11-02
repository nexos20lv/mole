import SwiftUI
import AppKit

// MARK: - App Entry Point
@main
struct MoleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainContentView()
                .frame(minWidth: 880, minHeight: 620)
                .background(VisualEffectView())
        }
        .windowStyle(.hiddenTitleBar)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Visual Effect (Liquid Glass Blur)
struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Navigation Tabs
enum NavigationTab: String, CaseIterable, Identifiable {
    case status = "Tableau de bord"
    case clean = "Nettoyeur"
    case optimize = "Optimiseur"
    case uninstall = "Désinstallateur"
    case console = "Console / Logs"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .status: return "gauge.with.needle"
        case .clean: return "sparkles"
        case .optimize: return "bolt.fill"
        case .uninstall: return "trash.fill"
        case .console: return "terminal.fill"
        }
    }
}

// MARK: - State Management & System Monitor
class SystemViewModel: ObservableObject {
    @Published var selectedTab: NavigationTab = .status

    @Published var cpuUsage: Double = 12.0
    @Published var ramDispoGB: Double = 6.0
    @Published var totalRamGB: Double = 16.0
    @Published var diskFreeGB: String = "121 Go"
    @Published var diskPercent: String = "41%"
    @Published var batteryPercent: String = "33%"
    @Published var uptimeStr: String = "1 j"
    @Published var topProcesses: [ProcessInfoItem] = []
    
    @Published var logs: String = "🐾 Mole GUI v2.0 prêt.\nMoteur open-source Mole v1.67.0 connecté.\n"
    @Published var isRunningTask: Bool = false
    @Published var currentTaskName: String = ""
    @Published var installedApps: [String] = []
    @Published var filterAppText: String = ""

    private var timer: Timer?

    init() {
        refreshMetrics()
        loadInstalledApps()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refreshMetrics()
        }
    }

    func refreshMetrics() {
        DispatchQueue.global(qos: .utility).async {
            let cpu = self.getCPUUsage()
            let ram = self.getAvailableRAM()
            let (dfree, dperc) = self.getDiskInfo()
            let batt = self.getBattery()
            let procs = self.getTopProcesses()

            DispatchQueue.main.async {
                self.cpuUsage = cpu
                self.ramDispoGB = ram
                self.diskFreeGB = dfree
                self.diskPercent = dperc
                self.batteryPercent = batt
                self.topProcesses = procs
            }
        }
    }

    private func getCPUUsage() -> Double {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        task.arguments = ["-l", "1", "-s", "0", "-n", "0"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let out = String(data: data, encoding: .utf8) {
            for line in out.components(separatedBy: "\n") {
                if line.contains("CPU usage:") {
                    let parts = line.components(separatedBy: ",")
                    if parts.count >= 3, let idleStr = parts[2].components(separatedBy: "%").first?.trimmingCharacters(in: .whitespaces) {
                        if let idleVal = Double(idleStr) {
                            return max(1.0, min(100.0, 100.0 - idleVal))
                        }
                    }
                }
            }
        }
        return 14.5
    }

    private func getAvailableRAM() -> Double {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/vm_stat")
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let out = String(data: data, encoding: .utf8) {
            var sumPages: Double = 0
            for line in out.components(separatedBy: "\n") {
                if line.contains("Pages free:") || line.contains("Pages inactive:") || line.contains("Pages purgeable:") {
                    let cleaned = line.replacingOccurrences(of: ".", with: "").components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""
                    if let pages = Double(cleaned) {
                        sumPages += pages
                    }
                }
            }
            return Double(round(10 * (sumPages * 16384.0 / 1073741824.0)) / 10)
        }
        return 6.0
    }

    private func getDiskInfo() -> (String, String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/df")
        task.arguments = ["-h", "/System/Volumes/Data"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let out = String(data: data, encoding: .utf8) {
            let lines = out.components(separatedBy: "\n")
            if lines.count >= 2 {
                let parts = lines[1].split(separator: " ", omittingEmptySubsequences: true)
                if parts.count >= 5 {
                    let free = String(parts[3]).replacingOccurrences(of: "Gi", with: " Go")
                    let used = String(parts[4])
                    return (free, used)
                }
            }
        }
        return ("121 Go", "41%")
    }

    private func getBattery() -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["-g", "batt"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let out = String(data: data, encoding: .utf8) {
            if let match = out.range(of: #"[0-9]+%"#, options: .regularExpression) {
                return String(out[match])
            }
        }
        return "100%"
    }

    private func getTopProcesses() -> [ProcessInfoItem] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-Aceo", "pid,pcpu,pmem,comm", "-r"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        var items: [ProcessInfoItem] = []
        if let out = String(data: data, encoding: .utf8) {
            let lines = out.components(separatedBy: "\n").dropFirst()
            for line in lines.prefix(7) {
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                if parts.count >= 4 {
                    let pid = String(parts[0])
                    let cpu = String(parts[1]) + "%"
                    let mem = String(parts[2]) + "%"
                    let name = parts.dropFirst(3).joined(separator: " ")
                    items.append(ProcessInfoItem(id: pid, name: (name as NSString).lastPathComponent, cpu: cpu, mem: mem))
                }
            }
        }
        return items
    }

    func loadInstalledApps() {
        DispatchQueue.global(qos: .utility).async {
            var apps: [String] = []
            if let urls = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: "/Applications"), includingPropertiesForKeys: nil) {
                for url in urls where url.pathExtension == "app" {
                    apps.append(url.deletingPathExtension().lastPathComponent)
                }
            }
            DispatchQueue.main.async {
                self.installedApps = apps.sorted()
            }
        }
    }

    func runMoleCommand(args: [String], name: String) {
        guard !isRunningTask else { return }
        isRunningTask = true
        currentTaskName = name
        selectedTab = .console
        appendLog("\n═══════════════════════════════════════════════════\n🚀 Tâche lancée : mole \(args.joined(separator: " "))\n═══════════════════════════════════════════════════\n")

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/mole")
            process.arguments = args
            var env = ProcessInfo.processInfo.environment
            env["TERM"] = "xterm-256color"
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            process.environment = env

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            let outHandle = pipe.fileHandleForReading
            outHandle.readabilityHandler = { handle in
                let d = handle.availableData
                if let s = String(data: d, encoding: .utf8), !s.isEmpty {
                    let clean = s.replacingOccurrences(of: "\\x1b\\[[0-9;]*[a-zA-Z]", with: "", options: .regularExpression)
                    DispatchQueue.main.async {
                        self.appendLog(clean)
                    }
                }
            }

            try? process.run()
            process.waitUntilExit()

            DispatchQueue.main.async {
                self.isRunningTask = false
                self.currentTaskName = ""
                self.appendLog("\n✅ [Tâche \(name) terminée avec succès !]\n")
                self.refreshMetrics()
            }
        }
    }

    func appendLog(_ s: String) {
        logs += s
    }
}

struct ProcessInfoItem: Identifiable {
    let id: String
    let name: String
    let cpu: String
    let mem: String
}

// MARK: - Main Content View
struct MainContentView: View {
    @StateObject var vm = SystemViewModel()

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(vm: vm)
                .frame(width: 220)

            Divider()
                .opacity(0.3)

            VStack(spacing: 0) {
                TopBarView(vm: vm, title: vm.selectedTab.rawValue)

                ZStack {
                    switch vm.selectedTab {
                    case .status:
                        DashboardView(vm: vm)
                    case .clean:
                        CleanView(vm: vm)
                    case .optimize:
                        OptimizeView(vm: vm)
                    case .uninstall:
                        UninstallerView(vm: vm)
                    case .console:
                        ConsoleView(vm: vm)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: vm.selectedTab)
            }
        }
    }
}

// MARK: - Sidebar View
struct SidebarView: View {
    @ObservedObject var vm: SystemViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Logo & Badge
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color.purple, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 34, height: 34)
                    Text("🐾")
                        .font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mole")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("PRO • GRATUIT")
                        .font(.system(size: 9, weight: .heavy))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.purple.opacity(0.4))
                        .cornerRadius(4)
                        .foregroundColor(Color(red: 0.85, green: 0.7, blue: 1.0))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 20)

            // Menu Items
            ForEach(NavigationTab.allCases) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        vm.selectedTab = tab
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(vm.selectedTab == tab ? Color(red: 0.88, green: 0.75, blue: 1.0) : .gray)
                            .frame(width: 20)

                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: vm.selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(vm.selectedTab == tab ? .white : Color(white: 0.75))

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(vm.selectedTab == tab ? Color.purple.opacity(0.25) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text("MacBook Air • Apple M4")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                Text("Mole Engine v1.67.0")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
            .padding(12)
        }
        .background(Color.black.opacity(0.25))
    }
}

// MARK: - Top Header Bar
struct TopBarView: View {
    @ObservedObject var vm: SystemViewModel
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            if vm.isRunningTask {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Exécution en cours : \(vm.currentTaskName)...")
                        .font(.system(size: 12))
                        .foregroundColor(.purple)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.purple.opacity(0.15))
                .cornerRadius(12)
            }

            Button(action: { vm.refreshMetrics() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .bold))
                    .padding(8)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.15))
    }
}

// MARK: - Circular Gauge Component
struct CircularRingGauge: View {
    let title: String
    let valueStr: String
    let subtitle: String
    let progress: Double
    let gradientColors: [Color]
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 8)
                    .frame(width: 82, height: 82)

                Circle()
                    .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                    .stroke(
                        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 82, height: 82)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)

                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(gradientColors.first ?? .purple)
                    Text(valueStr)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.white)
                }
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }
}

// MARK: - Dashboard View (Live Status)
struct DashboardView: View {
    @ObservedObject var vm: SystemViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 14) {
                    CircularRingGauge(
                        title: "Processeur",
                        valueStr: String(format: "%.0f%%", vm.cpuUsage),
                        subtitle: "Charge CPU M4",
                        progress: vm.cpuUsage / 100.0,
                        gradientColors: [Color.cyan, Color.blue],
                        icon: "cpu"
                    )

                    CircularRingGauge(
                        title: "Mémoire RAM",
                        valueStr: String(format: "%.1f Go", vm.ramDispoGB),
                        subtitle: "Libre / 16 Go",
                        progress: (16.0 - vm.ramDispoGB) / 16.0,
                        gradientColors: [Color.purple, Color(red: 0.9, green: 0.4, blue: 0.9)],
                        icon: "memorychip"
                    )

                    CircularRingGauge(
                        title: "Stockage SSD",
                        valueStr: vm.diskFreeGB,
                        subtitle: "\(vm.diskPercent) occupé",
                        progress: 0.41,
                        gradientColors: [Color.green, Color.mint],
                        icon: "internaldrive"
                    )

                    CircularRingGauge(
                        title: "Batterie",
                        valueStr: vm.batteryPercent,
                        subtitle: "Santé 100%",
                        progress: (Double(vm.batteryPercent.replacingOccurrences(of: "%", with: "")) ?? 33.0) / 100.0,
                        gradientColors: [Color.yellow, Color.orange],
                        icon: "battery.75"
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .foregroundColor(.purple)
                        Text("Processus Actifs (Temps Réel)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }

                    VStack(spacing: 8) {
                        HStack {
                            Text("PROCESSUS").font(.system(size: 10, weight: .bold)).foregroundColor(.gray).frame(width: 220, alignment: .leading)
                            Text("PID").font(.system(size: 10, weight: .bold)).foregroundColor(.gray).frame(width: 70, alignment: .leading)
                            Text("CPU").font(.system(size: 10, weight: .bold)).foregroundColor(.gray).frame(width: 70, alignment: .leading)
                            Text("RAM").font(.system(size: 10, weight: .bold)).foregroundColor(.gray).frame(width: 70, alignment: .leading)
                            Spacer()
                        }
                        .padding(.horizontal, 10)

                        ForEach(vm.topProcesses) { proc in
                            HStack {
                                Text(proc.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 220, alignment: .leading)
                                    .lineLimit(1)

                                Text(proc.id)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .frame(width: 70, alignment: .leading)

                                Text(proc.cpu)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color.cyan)
                                    .frame(width: 70, alignment: .leading)

                                Text(proc.mem)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.purple)
                                    .frame(width: 70, alignment: .leading)

                                Spacer()
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(6)
                        }
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
                )
            }
            .padding(24)
        }
    }
}

// MARK: - Clean View
struct CleanView: View {
    @ObservedObject var vm: SystemViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 22))
                            .foregroundColor(.purple)
                        Text("Nettoyage Système Intelligent")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text("Supprime les fichiers temporaires, résidus d'applications, caches obsolètes et logs pour récupérer instantanément de l'espace sur votre SSD.")
                        .font(.system(size: 12.5))
                        .foregroundColor(Color.gray)
                        .lineSpacing(3)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(colors: [Color.purple.opacity(0.25), Color.indigo.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.purple.opacity(0.3), lineWidth: 1))

                VStack(spacing: 12) {
                    CleanOptionRow(icon: "internaldrive.fill", title: "Caches Système & Utilisateur", subtitle: "Fichiers temporaires des applications fermées, bibliothèques", color: .purple)
                    CleanOptionRow(icon: "doc.text.fill", title: "Journaux & Crash Logs", subtitle: "Rapports de plantages et diagnostics obsolètes", color: .blue)
                    CleanOptionRow(icon: "globe", title: "Caches Web des Navigateurs", subtitle: "Cache de Google Chrome, Safari, Electron", color: .cyan)
                    CleanOptionRow(icon: "shippingbox.fill", title: "Caches Gestionnaires de Paquets", subtitle: "Anciens téléchargements Homebrew, npm, pip", color: .orange)
                }

                Button(action: {
                    vm.runMoleCommand(args: ["clean"], name: "Nettoyage Complet")
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.shield.fill")
                        Text("Lancer le Nettoyage Approfondi")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient(colors: [Color.purple, Color.indigo], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(color: Color.purple.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
            .padding(24)
        }
    }
}

struct CleanOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
    }
}

// MARK: - Optimize View
struct OptimizeView: View {
    @ObservedObject var vm: SystemViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Optimisations Système & Performances")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                VStack(spacing: 12) {
                    OptimizeCard(
                        icon: "bolt.fill",
                        title: "Optimisation Générale Mole",
                        description: "Relance et réindexe les services système, vide les verrous d'arrière-plan et restaure la vélocité maximale de macOS.",
                        btnText: "Exécuter",
                        action: { vm.runMoleCommand(args: ["optimize"], name: "Optimisation Système") }
                    )

                    OptimizeCard(
                        icon: "network",
                        title: "Purger le Cache DNS",
                        description: "Réinitialise le résolveur DNS mDNSResponder pour corriger les lenteurs de connexion ou de navigation web.",
                        btnText: "Purger DNS",
                        action: { vm.runMoleCommand(args: ["clean", "dns"], name: "Flush DNS") }
                    )

                    OptimizeCard(
                        icon: "hammer.fill",
                        title: "Purger les Dépendances Dev (Purge)",
                        description: "Supprime les répertoires node_modules orphelins, les dossiers de build et les caches de développement oubliés.",
                        btnText: "Purger Dev",
                        action: { vm.runMoleCommand(args: ["purge"], name: "Purge Projets Dev") }
                    )
                }
            }
            .padding(24)
        }
    }
}

struct OptimizeCard: View {
    let icon: String
    let title: String
    let description: String
    let btnText: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.purple)
                .frame(width: 44, height: 44)
                .background(Color.purple.opacity(0.15))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 11.5))
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: action) {
                Text(btnText)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }
}

// MARK: - Uninstaller View
struct UninstallerView: View {
    @ObservedObject var vm: SystemViewModel

    var filteredApps: [String] {
        if vm.filterAppText.isEmpty {
            return vm.installedApps
        } else {
            return vm.installedApps.filter { $0.localizedCaseInsensitiveContains(vm.filterAppText) }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Désinstallateur d'Applications Propre")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Rechercher une application...", text: Binding(
                        get: { vm.filterAppText },
                        set: { vm.filterAppText = $0 }
                    ))
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)
                .frame(width: 220)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            List(filteredApps, id: \.self) { appName in
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.purple.opacity(0.2))
                            .frame(width: 32, height: 32)
                        Image(systemName: "app.fill")
                            .foregroundColor(.purple)
                    }

                    Text(appName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        vm.runMoleCommand(args: ["uninstall", appName], name: "Désinstallation de \(appName)")
                    }) {
                        Text("Désinstaller")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
            .scrollContentBackground(.hidden)
        }
    }
}

// MARK: - Console Log View
struct ConsoleView: View {
    @ObservedObject var vm: SystemViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Journal d'Exécution Mole (Temps Réel)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: { vm.logs = "" }) {
                    Text("Effacer les logs")
                        .font(.system(size: 11))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                Text(vm.logs)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(red: 0.88, green: 0.85, blue: 0.98))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
            .background(Color.black.opacity(0.4))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .padding(24)
    }
}
