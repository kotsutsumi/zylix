//
//  ZylixComponents.swift
//  Zylix
//
//  Swift definitions for Zylix component types and SwiftUI renderer.
//  These definitions mirror the Zig component.zig definitions for v0.2.0.
//

import SwiftUI

// MARK: - Component Types

/// Component type enum matching Zig's ComponentType
/// Must stay in sync with core/src/component.zig
public enum ZylixComponentType: UInt8, CaseIterable {
    // Basic Components (0-9)
    case container = 0
    case text = 1
    case button = 2
    case input = 3
    case image = 4
    case link = 5
    case list = 6
    case listItem = 7
    case heading = 8
    case paragraph = 9

    // Form Components (10-20)
    case select = 10
    case checkbox = 11
    case radio = 12
    case textarea = 13
    case toggleSwitch = 14
    case slider = 15
    case datePicker = 16
    case timePicker = 17
    case fileInput = 18
    case colorPicker = 19
    case form = 20

    // Layout Components (21-28)
    case stack = 21
    case grid = 22
    case scrollView = 23
    case spacer = 24
    case divider = 25
    case card = 26
    case aspectRatio = 27
    case safeArea = 28

    // Navigation Components (30-34)
    case navBar = 30
    case tabBar = 31
    case drawer = 32
    case breadcrumb = 33
    case pagination = 34

    // Feedback Components (40-46)
    case alert = 40
    case toast = 41
    case modal = 42
    case progress = 43
    case spinner = 44
    case skeleton = 45
    case badge = 46

    // Data Display Components (50-56)
    case table = 50
    case avatar = 51
    case icon = 52
    case tag = 53
    case tooltip = 54
    case accordion = 55
    case carousel = 56

    case custom = 255

    /// Human-readable name for the component type
    public var displayName: String {
        switch self {
        case .container: return "Container"
        case .text: return "Text"
        case .button: return "Button"
        case .input: return "Input"
        case .image: return "Image"
        case .link: return "Link"
        case .list: return "List"
        case .listItem: return "List Item"
        case .heading: return "Heading"
        case .paragraph: return "Paragraph"
        case .select: return "Select"
        case .checkbox: return "Checkbox"
        case .radio: return "Radio"
        case .textarea: return "Textarea"
        case .toggleSwitch: return "Toggle Switch"
        case .slider: return "Slider"
        case .datePicker: return "Date Picker"
        case .timePicker: return "Time Picker"
        case .fileInput: return "File Input"
        case .colorPicker: return "Color Picker"
        case .form: return "Form"
        case .stack: return "Stack"
        case .grid: return "Grid"
        case .scrollView: return "Scroll View"
        case .spacer: return "Spacer"
        case .divider: return "Divider"
        case .card: return "Card"
        case .aspectRatio: return "Aspect Ratio"
        case .safeArea: return "Safe Area"
        case .navBar: return "Nav Bar"
        case .tabBar: return "Tab Bar"
        case .drawer: return "Drawer"
        case .breadcrumb: return "Breadcrumb"
        case .pagination: return "Pagination"
        case .alert: return "Alert"
        case .toast: return "Toast"
        case .modal: return "Modal"
        case .progress: return "Progress"
        case .spinner: return "Spinner"
        case .skeleton: return "Skeleton"
        case .badge: return "Badge"
        case .table: return "Table"
        case .avatar: return "Avatar"
        case .icon: return "Icon"
        case .tag: return "Tag"
        case .tooltip: return "Tooltip"
        case .accordion: return "Accordion"
        case .carousel: return "Carousel"
        case .custom: return "Custom"
        }
    }

    /// Category of the component type
    public var category: ComponentCategory {
        switch self.rawValue {
        case 0...9: return .basic
        case 10...20: return .form
        case 21...28: return .layout
        case 30...34: return .navigation
        case 40...46: return .feedback
        case 50...56: return .dataDisplay
        default: return .custom
        }
    }
}

// MARK: - Component Category

public enum ComponentCategory: String, CaseIterable {
    case basic = "Basic"
    case form = "Form"
    case layout = "Layout"
    case navigation = "Navigation"
    case feedback = "Feedback"
    case dataDisplay = "Data Display"
    case custom = "Custom"
}

// MARK: - Stack Direction

public enum ZylixStackDirection: UInt8 {
    case vertical = 0
    case horizontal = 1
    case zStack = 2
}

// MARK: - Stack Alignment

public enum ZylixStackAlignment: UInt8 {
    case start = 0
    case center = 1
    case end = 2
    case stretch = 3
    case spaceBetween = 4
    case spaceAround = 5
    case spaceEvenly = 6
}

// MARK: - Progress Style

public enum ZylixProgressStyle: UInt8 {
    case linear = 0
    case circular = 1
    case indeterminate = 2
}

// MARK: - Alert Style

public enum ZylixAlertStyle: UInt8 {
    case info = 0
    case success = 1
    case warning = 2
    case error = 3

    public var color: Color {
        switch self {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }

    public var iconName: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
}

// MARK: - Toast Position

public enum ZylixToastPosition: UInt8 {
    case top = 0
    case bottom = 1
    case topLeft = 2
    case topRight = 3
    case bottomLeft = 4
    case bottomRight = 5
}

// MARK: - Component Props

/// Properties that can be applied to components
public struct ZylixComponentProps {
    // Common
    public var id: UInt32 = 0
    public var componentType: ZylixComponentType = .container
    public var text: String = ""
    public var isDisabled: Bool = false
    public var isVisible: Bool = true

    // Layout
    public var width: CGFloat?
    public var height: CGFloat?
    public var padding: CGFloat = 0
    public var margin: CGFloat = 0

    // Stack
    public var stackDirection: ZylixStackDirection = .vertical
    public var stackAlignment: ZylixStackAlignment = .start
    public var stackSpacing: CGFloat = 0

    // Form
    public var placeholder: String = ""
    public var isChecked: Bool = false
    public var value: Double = 0
    public var minValue: Double = 0
    public var maxValue: Double = 100

    // Progress/Feedback
    public var progressStyle: ZylixProgressStyle = .linear
    public var progressValue: Double = 0
    public var alertStyle: ZylixAlertStyle = .info
    public var toastPosition: ZylixToastPosition = .bottom
    public var toastDuration: Int = 3000

    // Heading
    public var headingLevel: Int = 1

    public init() {}
}

// MARK: - Component View Factory

/// Factory for creating SwiftUI views from Zylix component types
public struct ZylixComponentFactory {

    @ViewBuilder
    public static func createView(for props: ZylixComponentProps) -> some View {
        switch props.componentType {
        // Basic Components
        case .container:
            ContainerView(props: props)
        case .text:
            TextView(props: props)
        case .button:
            ButtonView(props: props)
        case .input:
            InputView(props: props)
        case .heading:
            HeadingView(props: props)
        case .paragraph:
            ParagraphView(props: props)
        case .link:
            LinkView(props: props)
        case .image:
            ImageView(props: props)
        case .list:
            ListView(props: props)
        case .listItem:
            ListItemView(props: props)

        // Form Components
        case .checkbox:
            CheckboxView(props: props)
        case .toggleSwitch:
            ToggleSwitchView(props: props)
        case .slider:
            SliderView(props: props)
        case .select:
            SelectView(props: props)
        case .datePicker:
            DatePickerView(props: props)
        case .timePicker:
            TimePickerView(props: props)
        case .colorPicker:
            ColorPickerView(props: props)
        case .textarea:
            TextareaView(props: props)
        case .radio:
            RadioView(props: props)
        case .fileInput:
            FileInputView(props: props)
        case .form:
            FormView(props: props)

        // Layout Components
        case .stack:
            StackView(props: props)
        case .grid:
            GridView(props: props)
        case .scrollView:
            ScrollViewWrapper(props: props)
        case .spacer:
            SpacerView()
        case .divider:
            DividerView()
        case .card:
            CardView(props: props)
        case .aspectRatio:
            AspectRatioView(props: props)
        case .safeArea:
            SafeAreaView(props: props)

        // Navigation Components
        case .navBar:
            NavBarView(props: props)
        case .tabBar:
            TabBarView(props: props)
        case .drawer:
            DrawerView(props: props)
        case .breadcrumb:
            BreadcrumbView(props: props)
        case .pagination:
            PaginationView(props: props)

        // Feedback Components
        case .alert:
            AlertView(props: props)
        case .progress:
            ProgressView(props: props)
        case .spinner:
            SpinnerView()
        case .skeleton:
            SkeletonView(props: props)
        case .badge:
            BadgeView(props: props)
        case .toast:
            ToastView(props: props)
        case .modal:
            ModalView(props: props)

        // Data Display Components
        case .avatar:
            AvatarView(props: props)
        case .icon:
            IconView(props: props)
        case .tag:
            TagView(props: props)
        case .table:
            TableView(props: props)
        case .tooltip:
            TooltipView(props: props)
        case .accordion:
            AccordionView(props: props)
        case .carousel:
            CarouselView(props: props)

        case .custom:
            PlaceholderView(props: props)
        }
    }
}

// MARK: - Basic Component Views

struct ContainerView: View {
    let props: ZylixComponentProps

    var body: some View {
        VStack {
            // Container can hold children
        }
        .padding(props.padding)
    }
}

struct TextView: View {
    let props: ZylixComponentProps

    var body: some View {
        Text(props.text)
    }
}

struct ButtonView: View {
    let props: ZylixComponentProps

    var body: some View {
        Button(props.text) {
            // Action handled by Zylix Core
        }
        .disabled(props.isDisabled)
        .buttonStyle(.borderedProminent)
    }
}

struct InputView: View {
    let props: ZylixComponentProps
    @State private var text: String = ""

    var body: some View {
        TextField(props.placeholder, text: $text)
            .textFieldStyle(.roundedBorder)
            .disabled(props.isDisabled)
    }
}

struct HeadingView: View {
    let props: ZylixComponentProps

    var body: some View {
        Text(props.text)
            .font(fontForLevel(props.headingLevel))
            .fontWeight(.bold)
    }

    private func fontForLevel(_ level: Int) -> Font {
        switch level {
        case 1: return .largeTitle
        case 2: return .title
        case 3: return .title2
        case 4: return .title3
        case 5: return .headline
        default: return .subheadline
        }
    }
}

struct ParagraphView: View {
    let props: ZylixComponentProps

    var body: some View {
        Text(props.text)
            .font(.body)
    }
}

struct LinkView: View {
    let props: ZylixComponentProps

    var body: some View {
        Button(props.text) {
            // Link action
        }
        .foregroundStyle(.blue)
    }
}

struct ImageView: View {
    let props: ZylixComponentProps

    var body: some View {
        Image(systemName: "photo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: props.width, height: props.height)
    }
}

struct ListView: View {
    let props: ZylixComponentProps

    var body: some View {
        List {
            // List items will be children
        }
    }
}

struct ListItemView: View {
    let props: ZylixComponentProps

    var body: some View {
        Text(props.text)
    }
}

// MARK: - Form Component Views

struct CheckboxView: View {
    let props: ZylixComponentProps
    @State private var isChecked: Bool = false

    var body: some View {
        Toggle(props.text, isOn: $isChecked)
            .toggleStyle(.switch)
            .disabled(props.isDisabled)
    }
}

struct ToggleSwitchView: View {
    let props: ZylixComponentProps
    @State private var isOn: Bool = false

    var body: some View {
        Toggle(props.text, isOn: $isOn)
            .disabled(props.isDisabled)
    }
}

struct SliderView: View {
    let props: ZylixComponentProps
    @State private var value: Double = 50

    var body: some View {
        Slider(value: $value, in: props.minValue...props.maxValue)
            .disabled(props.isDisabled)
    }
}

struct SelectView: View {
    let props: ZylixComponentProps
    @State private var selection: String = ""

    var body: some View {
        Picker(props.text, selection: $selection) {
            Text("Option 1").tag("1")
            Text("Option 2").tag("2")
            Text("Option 3").tag("3")
        }
        .pickerStyle(.menu)
    }
}

struct DatePickerView: View {
    let props: ZylixComponentProps
    @State private var date = Date()

    var body: some View {
        DatePicker(props.text, selection: $date, displayedComponents: .date)
            .disabled(props.isDisabled)
    }
}

struct TimePickerView: View {
    let props: ZylixComponentProps
    @State private var time = Date()

    var body: some View {
        DatePicker(props.text, selection: $time, displayedComponents: .hourAndMinute)
            .disabled(props.isDisabled)
    }
}

struct ColorPickerView: View {
    let props: ZylixComponentProps
    @State private var color: Color = .blue

    var body: some View {
        SwiftUI.ColorPicker(props.text, selection: $color)
            .disabled(props.isDisabled)
    }
}

struct TextareaView: View {
    let props: ZylixComponentProps
    @State private var text: String = ""

    var body: some View {
        TextEditor(text: $text)
            .frame(minHeight: 100)
            .disabled(props.isDisabled)
    }
}

// MARK: - Layout Component Views

struct StackView: View {
    let props: ZylixComponentProps

    var body: some View {
        switch props.stackDirection {
        case .horizontal:
            HStack(spacing: props.stackSpacing) {
                // Children
            }
        case .zStack:
            ZStack {
                // Children
            }
        case .vertical:
            VStack(spacing: props.stackSpacing) {
                // Children
            }
        }
    }
}

struct GridView: View {
    let props: ZylixComponentProps

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
            // Grid items
        }
    }
}

struct ScrollViewWrapper: View {
    let props: ZylixComponentProps

    var body: some View {
        ScrollView {
            // Content
        }
    }
}

struct SpacerView: View {
    var body: some View {
        Spacer()
    }
}

struct DividerView: View {
    var body: some View {
        Divider()
    }
}

struct CardView: View {
    let props: ZylixComponentProps

    var body: some View {
        VStack {
            if !props.text.isEmpty {
                Text(props.text)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

// MARK: - Navigation Component Views

struct NavBarView: View {
    let props: ZylixComponentProps

    var body: some View {
        HStack {
            Text(props.text)
                .font(.headline)
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

struct TabBarView: View {
    let props: ZylixComponentProps
    @State private var selectedTab = 0

    var body: some View {
        Picker("", selection: $selectedTab) {
            Text("Tab 1").tag(0)
            Text("Tab 2").tag(1)
            Text("Tab 3").tag(2)
        }
        .pickerStyle(.segmented)
    }
}

// MARK: - Feedback Component Views

struct AlertView: View {
    let props: ZylixComponentProps

    var body: some View {
        HStack {
            Image(systemName: props.alertStyle.iconName)
                .foregroundStyle(props.alertStyle.color)
            Text(props.text)
            Spacer()
        }
        .padding()
        .background(props.alertStyle.color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ProgressView: View {
    let props: ZylixComponentProps

    var body: some View {
        switch props.progressStyle {
        case .linear:
            SwiftUI.ProgressView(value: props.progressValue, total: 100)
        case .circular:
            SwiftUI.ProgressView(value: props.progressValue, total: 100)
                .progressViewStyle(.circular)
        case .indeterminate:
            SwiftUI.ProgressView()
        }
    }
}

struct SpinnerView: View {
    var body: some View {
        SwiftUI.ProgressView()
            .progressViewStyle(.circular)
    }
}

struct SkeletonView: View {
    let props: ZylixComponentProps
    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.gray.opacity(0.3))
            .frame(height: 20)
            .opacity(isAnimating ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}

struct BadgeView: View {
    let props: ZylixComponentProps

    var body: some View {
        Text(props.text)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
}

// MARK: - Data Display Component Views

struct AvatarView: View {
    let props: ZylixComponentProps

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 40, height: 40)
            .overlay(
                Text(String(props.text.prefix(1)).uppercased())
                    .foregroundStyle(.white)
                    .fontWeight(.bold)
            )
    }
}

struct IconView: View {
    let props: ZylixComponentProps

    var body: some View {
        Image(systemName: props.text.isEmpty ? "star.fill" : props.text)
            .font(.system(size: 24))
    }
}

struct TagView: View {
    let props: ZylixComponentProps

    var body: some View {
        Text(props.text)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(.systemGray5))
            .clipShape(Capsule())
    }
}

// MARK: - Feedback Component Views (Continued)

struct ToastView: View {
    let props: ZylixComponentProps

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: props.alertStyle.iconName)
                .foregroundStyle(props.alertStyle.color)
            Text(props.text)
                .font(.subheadline)
            Spacer()
            Button(action: {}) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(radius: 8)
    }
}

struct ModalView: View {
    let props: ZylixComponentProps
    @State private var isPresented = false

    var body: some View {
        Button("Show Modal") {
            isPresented = true
        }
        .sheet(isPresented: $isPresented) {
            VStack(spacing: 16) {
                Text(props.text.isEmpty ? "Modal Content" : props.text)
                    .font(.headline)
                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Data Display Component Views (Continued)

struct TableView: View {
    let props: ZylixComponentProps

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Column 1").fontWeight(.bold).frame(maxWidth: .infinity, alignment: .leading)
                Text("Column 2").fontWeight(.bold).frame(maxWidth: .infinity, alignment: .leading)
                Text("Column 3").fontWeight(.bold).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color(.systemGray5))

            Divider()

            // Rows
            ForEach(0..<3, id: \.self) { row in
                HStack {
                    Text("Row \(row + 1)").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Data").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Value").frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()

                if row < 2 {
                    Divider()
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

struct TooltipView: View {
    let props: ZylixComponentProps
    @State private var showTooltip = false

    var body: some View {
        Text(props.text.isEmpty ? "Hover me" : props.text)
            .padding(8)
            .background(showTooltip ? Color(.systemGray5) : Color.clear)
            .cornerRadius(4)
            .overlay(
                Group {
                    if showTooltip {
                        Text("Tooltip content")
                            .font(.caption)
                            .padding(8)
                            .background(Color.black.opacity(0.8))
                            .foregroundStyle(.white)
                            .cornerRadius(4)
                            .offset(y: -40)
                    }
                }
            )
            .onHover { hovering in
                showTooltip = hovering
            }
    }
}

struct AccordionView: View {
    let props: ZylixComponentProps
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text(props.text.isEmpty ? "Accordion Header" : props.text)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text("Accordion content goes here. This section expands and collapses when the header is tapped.")
                    .padding()
                    .background(Color(.systemBackground))
            }
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

struct CarouselView: View {
    let props: ZylixComponentProps
    @State private var currentIndex = 0
    private let items = ["Slide 1", "Slide 2", "Slide 3"]

    var body: some View {
        VStack {
            TabView(selection: $currentIndex) {
                ForEach(0..<items.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .overlay(
                            Text(items[index])
                                .font(.title2)
                                .fontWeight(.semibold)
                        )
                        .padding(.horizontal)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 200)
        }
    }
}

// MARK: - Navigation Component Views (Continued)

struct DrawerView: View {
    let props: ZylixComponentProps
    @State private var isOpen = false

    var body: some View {
        Button("Open Drawer") {
            isOpen = true
        }
        .sheet(isPresented: $isOpen) {
            NavigationStack {
                List {
                    NavigationLink("Home", destination: Text("Home"))
                    NavigationLink("Settings", destination: Text("Settings"))
                    NavigationLink("Profile", destination: Text("Profile"))
                }
                .navigationTitle(props.text.isEmpty ? "Menu" : props.text)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { isOpen = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

struct BreadcrumbView: View {
    let props: ZylixComponentProps
    private let items = ["Home", "Category", "Current"]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if index < items.count - 1 {
                    Button(item) {}
                        .foregroundStyle(.blue)
                } else {
                    Text(item)
                        .foregroundStyle(.primary)
                }
            }
        }
        .font(.subheadline)
    }
}

struct PaginationView: View {
    let props: ZylixComponentProps
    @State private var currentPage = 1
    private let totalPages = 5

    var body: some View {
        HStack(spacing: 4) {
            Button(action: { if currentPage > 1 { currentPage -= 1 } }) {
                Image(systemName: "chevron.left")
            }
            .disabled(currentPage == 1)

            ForEach(1...totalPages, id: \.self) { page in
                Button("\(page)") {
                    currentPage = page
                }
                .buttonStyle(currentPage == page ? .borderedProminent : .bordered)
            }

            Button(action: { if currentPage < totalPages { currentPage += 1 } }) {
                Image(systemName: "chevron.right")
            }
            .disabled(currentPage == totalPages)
        }
    }
}

// MARK: - Form Component Views (Continued)

struct RadioView: View {
    let props: ZylixComponentProps
    @State private var selected = false

    var body: some View {
        Button(action: { selected.toggle() }) {
            HStack {
                Image(systemName: selected ? "circle.inset.filled" : "circle")
                    .foregroundStyle(selected ? .blue : .secondary)
                Text(props.text)
            }
        }
        .buttonStyle(.plain)
        .disabled(props.isDisabled)
    }
}

struct FileInputView: View {
    let props: ZylixComponentProps
    @State private var selectedFile: String = ""

    var body: some View {
        HStack {
            Text(selectedFile.isEmpty ? "No file selected" : selectedFile)
                .foregroundStyle(selectedFile.isEmpty ? .secondary : .primary)
            Spacer()
            Button("Browse...") {
                selectedFile = "example.pdf"
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct FormView: View {
    let props: ZylixComponentProps

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Form container for children
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Layout Component Views (Continued)

struct AspectRatioView: View {
    let props: ZylixComponentProps

    var body: some View {
        Color(.systemGray5)
            .aspectRatio(16/9, contentMode: .fit)
            .overlay(
                Text("16:9")
                    .foregroundStyle(.secondary)
            )
            .cornerRadius(8)
    }
}

struct SafeAreaView: View {
    let props: ZylixComponentProps

    var body: some View {
        GeometryReader { geometry in
            VStack {
                // Content respecting safe areas
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - Placeholder View

struct PlaceholderView: View {
    let props: ZylixComponentProps

    var body: some View {
        VStack {
            Image(systemName: "square.dashed")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(props.componentType.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Component Demo View

/// A demo view showing all available component types
public struct ZylixComponentsDemo: View {
    @State private var selectedCategory: ComponentCategory = .basic

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack {
                // Category picker
                Picker("Category", selection: $selectedCategory) {
                    ForEach(ComponentCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Component list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(componentsInCategory(selectedCategory), id: \.rawValue) { type in
                            componentRow(for: type)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Zylix Components")
        }
    }

    private func componentsInCategory(_ category: ComponentCategory) -> [ZylixComponentType] {
        ZylixComponentType.allCases.filter { $0.category == category }
    }

    private func componentRow(for type: ZylixComponentType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(type.displayName)
                .font(.headline)

            var props = ZylixComponentProps()
            props.componentType = type
            props.text = type.displayName

            ZylixComponentFactory.createView(for: props)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

#Preview {
    ZylixComponentsDemo()
}
