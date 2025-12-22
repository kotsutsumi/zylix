package com.zylix

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Component type enum matching Zig's ComponentType.
 * Must stay in sync with core/src/component.zig
 */
enum class ZylixComponentType(val value: Int) {
    // Basic Components (0-9)
    CONTAINER(0),
    TEXT(1),
    BUTTON(2),
    INPUT(3),
    IMAGE(4),
    LINK(5),
    LIST(6),
    LIST_ITEM(7),
    HEADING(8),
    PARAGRAPH(9),

    // Form Components (10-20)
    SELECT(10),
    CHECKBOX(11),
    RADIO(12),
    TEXTAREA(13),
    TOGGLE_SWITCH(14),
    SLIDER(15),
    DATE_PICKER(16),
    TIME_PICKER(17),
    FILE_INPUT(18),
    COLOR_PICKER(19),
    FORM(20),

    // Layout Components (21-28)
    STACK(21),
    GRID(22),
    SCROLL_VIEW(23),
    SPACER(24),
    DIVIDER(25),
    CARD(26),
    ASPECT_RATIO(27),
    SAFE_AREA(28),

    // Navigation Components (30-34)
    NAV_BAR(30),
    TAB_BAR(31),
    DRAWER(32),
    BREADCRUMB(33),
    PAGINATION(34),

    // Feedback Components (40-46)
    ALERT(40),
    TOAST(41),
    MODAL(42),
    PROGRESS(43),
    SPINNER(44),
    SKELETON(45),
    BADGE(46),

    // Data Display Components (50-56)
    TABLE(50),
    AVATAR(51),
    ICON(52),
    TAG(53),
    TOOLTIP(54),
    ACCORDION(55),
    CAROUSEL(56),

    CUSTOM(255);

    val displayName: String
        get() = name.lowercase().replace('_', ' ').replaceFirstChar { it.uppercase() }

    val category: ComponentCategory
        get() = when (value) {
            in 0..9 -> ComponentCategory.BASIC
            in 10..20 -> ComponentCategory.FORM
            in 21..28 -> ComponentCategory.LAYOUT
            in 30..34 -> ComponentCategory.NAVIGATION
            in 40..46 -> ComponentCategory.FEEDBACK
            in 50..56 -> ComponentCategory.DATA_DISPLAY
            else -> ComponentCategory.CUSTOM
        }

    companion object {
        fun fromValue(value: Int): ZylixComponentType =
            entries.find { it.value == value } ?: CUSTOM
    }
}

/**
 * Component category for grouping.
 */
enum class ComponentCategory(val displayName: String) {
    BASIC("Basic"),
    FORM("Form"),
    LAYOUT("Layout"),
    NAVIGATION("Navigation"),
    FEEDBACK("Feedback"),
    DATA_DISPLAY("Data Display"),
    CUSTOM("Custom")
}

/**
 * Stack direction enum.
 */
enum class ZylixStackDirection(val value: Int) {
    VERTICAL(0),
    HORIZONTAL(1),
    Z_STACK(2)
}

/**
 * Stack alignment enum.
 */
enum class ZylixStackAlignment(val value: Int) {
    START(0),
    CENTER(1),
    END(2),
    STRETCH(3),
    SPACE_BETWEEN(4),
    SPACE_AROUND(5),
    SPACE_EVENLY(6)
}

/**
 * Progress style enum.
 */
enum class ZylixProgressStyle(val value: Int) {
    LINEAR(0),
    CIRCULAR(1),
    INDETERMINATE(2)
}

/**
 * Alert style enum.
 */
enum class ZylixAlertStyle(val value: Int) {
    INFO(0),
    SUCCESS(1),
    WARNING(2),
    ERROR(3);

    val color: Color
        get() = when (this) {
            INFO -> Color(0xFF2196F3)
            SUCCESS -> Color(0xFF4CAF50)
            WARNING -> Color(0xFFFF9800)
            ERROR -> Color(0xFFF44336)
        }

    val icon: ImageVector
        get() = when (this) {
            INFO -> Icons.Default.Info
            SUCCESS -> Icons.Default.CheckCircle
            WARNING -> Icons.Default.Warning
            ERROR -> Icons.Default.Error
        }
}

/**
 * Toast position enum.
 */
enum class ZylixToastPosition(val value: Int) {
    TOP(0),
    BOTTOM(1),
    TOP_LEFT(2),
    TOP_RIGHT(3),
    BOTTOM_LEFT(4),
    BOTTOM_RIGHT(5)
}

/**
 * Component properties.
 */
data class ZylixComponentProps(
    val id: Int = 0,
    val componentType: ZylixComponentType = ZylixComponentType.CONTAINER,
    val text: String = "",
    val isDisabled: Boolean = false,
    val isVisible: Boolean = true,

    // Layout
    val width: Int? = null,
    val height: Int? = null,
    val padding: Int = 0,
    val margin: Int = 0,

    // Stack
    val stackDirection: ZylixStackDirection = ZylixStackDirection.VERTICAL,
    val stackAlignment: ZylixStackAlignment = ZylixStackAlignment.START,
    val stackSpacing: Int = 0,

    // Form
    val placeholder: String = "",
    val isChecked: Boolean = false,
    val value: Float = 0f,
    val minValue: Float = 0f,
    val maxValue: Float = 100f,

    // Progress/Feedback
    val progressStyle: ZylixProgressStyle = ZylixProgressStyle.LINEAR,
    val progressValue: Float = 0f,
    val alertStyle: ZylixAlertStyle = ZylixAlertStyle.INFO,
    val toastPosition: ZylixToastPosition = ZylixToastPosition.BOTTOM,
    val toastDuration: Int = 3000,

    // Heading
    val headingLevel: Int = 1
)

/**
 * Factory for creating Compose views from Zylix component types.
 */
object ZylixComponentFactory {

    @Composable
    fun CreateView(props: ZylixComponentProps) {
        when (props.componentType) {
            // Basic Components
            ZylixComponentType.CONTAINER -> ContainerView(props)
            ZylixComponentType.TEXT -> TextView(props)
            ZylixComponentType.BUTTON -> ButtonView(props)
            ZylixComponentType.INPUT -> InputView(props)
            ZylixComponentType.IMAGE -> ImageView(props)
            ZylixComponentType.LINK -> LinkView(props)
            ZylixComponentType.LIST -> ListView(props)
            ZylixComponentType.LIST_ITEM -> ListItemView(props)
            ZylixComponentType.HEADING -> HeadingView(props)
            ZylixComponentType.PARAGRAPH -> ParagraphView(props)

            // Form Components
            ZylixComponentType.SELECT -> SelectView(props)
            ZylixComponentType.CHECKBOX -> CheckboxView(props)
            ZylixComponentType.RADIO -> RadioView(props)
            ZylixComponentType.TEXTAREA -> TextareaView(props)
            ZylixComponentType.TOGGLE_SWITCH -> ToggleSwitchView(props)
            ZylixComponentType.SLIDER -> SliderView(props)
            ZylixComponentType.DATE_PICKER -> DatePickerView(props)
            ZylixComponentType.TIME_PICKER -> TimePickerView(props)
            ZylixComponentType.FILE_INPUT -> FileInputView(props)
            ZylixComponentType.COLOR_PICKER -> ColorPickerView(props)
            ZylixComponentType.FORM -> FormView(props)

            // Layout Components
            ZylixComponentType.STACK -> StackView(props)
            ZylixComponentType.GRID -> GridView(props)
            ZylixComponentType.SCROLL_VIEW -> ScrollViewWrapper(props)
            ZylixComponentType.SPACER -> SpacerView()
            ZylixComponentType.DIVIDER -> DividerView()
            ZylixComponentType.CARD -> CardView(props)
            ZylixComponentType.ASPECT_RATIO -> AspectRatioView(props)
            ZylixComponentType.SAFE_AREA -> SafeAreaView(props)

            // Navigation Components
            ZylixComponentType.NAV_BAR -> NavBarView(props)
            ZylixComponentType.TAB_BAR -> TabBarView(props)
            ZylixComponentType.DRAWER -> DrawerView(props)
            ZylixComponentType.BREADCRUMB -> BreadcrumbView(props)
            ZylixComponentType.PAGINATION -> PaginationView(props)

            // Feedback Components
            ZylixComponentType.ALERT -> AlertView(props)
            ZylixComponentType.TOAST -> ToastView(props)
            ZylixComponentType.MODAL -> ModalView(props)
            ZylixComponentType.PROGRESS -> ProgressView(props)
            ZylixComponentType.SPINNER -> SpinnerView()
            ZylixComponentType.SKELETON -> SkeletonView(props)
            ZylixComponentType.BADGE -> BadgeView(props)

            // Data Display Components
            ZylixComponentType.TABLE -> TableView(props)
            ZylixComponentType.AVATAR -> AvatarView(props)
            ZylixComponentType.ICON -> IconView(props)
            ZylixComponentType.TAG -> TagView(props)
            ZylixComponentType.TOOLTIP -> TooltipView(props)
            ZylixComponentType.ACCORDION -> AccordionView(props)
            ZylixComponentType.CAROUSEL -> CarouselView(props)

            ZylixComponentType.CUSTOM -> PlaceholderView(props)
        }
    }
}

// MARK: - Basic Component Views

@Composable
private fun ContainerView(props: ZylixComponentProps) {
    Column(
        modifier = Modifier.padding(props.padding.dp)
    ) {
        // Children will be added here
    }
}

@Composable
private fun TextView(props: ZylixComponentProps) {
    Text(text = props.text)
}

@Composable
private fun ButtonView(props: ZylixComponentProps) {
    Button(
        onClick = { /* Action handled by Zylix Core */ },
        enabled = !props.isDisabled
    ) {
        Text(props.text)
    }
}

@Composable
private fun InputView(props: ZylixComponentProps) {
    var text by remember { mutableStateOf("") }
    OutlinedTextField(
        value = text,
        onValueChange = { text = it },
        placeholder = { Text(props.placeholder) },
        enabled = !props.isDisabled,
        modifier = Modifier.fillMaxWidth()
    )
}

@Composable
private fun ImageView(props: ZylixComponentProps) {
    Icon(
        imageVector = Icons.Default.Image,
        contentDescription = props.text,
        modifier = Modifier.size(100.dp)
    )
}

@Composable
private fun LinkView(props: ZylixComponentProps) {
    TextButton(onClick = { /* Link action */ }) {
        Text(
            text = props.text,
            color = MaterialTheme.colorScheme.primary
        )
    }
}

@Composable
private fun ListView(props: ZylixComponentProps) {
    LazyColumn {
        // List items
    }
}

@Composable
private fun ListItemView(props: ZylixComponentProps) {
    Text(text = props.text, modifier = Modifier.padding(8.dp))
}

@Composable
private fun HeadingView(props: ZylixComponentProps) {
    val fontSize = when (props.headingLevel) {
        1 -> 32.sp
        2 -> 28.sp
        3 -> 24.sp
        4 -> 20.sp
        5 -> 18.sp
        else -> 16.sp
    }
    Text(
        text = props.text,
        fontSize = fontSize,
        fontWeight = FontWeight.Bold
    )
}

@Composable
private fun ParagraphView(props: ZylixComponentProps) {
    Text(
        text = props.text,
        fontSize = 16.sp,
        lineHeight = 24.sp
    )
}

// MARK: - Form Component Views

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SelectView(props: ZylixComponentProps) {
    var expanded by remember { mutableStateOf(false) }
    var selected by remember { mutableStateOf("Select...") }

    ExposedDropdownMenuBox(
        expanded = expanded,
        onExpandedChange = { expanded = !expanded }
    ) {
        OutlinedTextField(
            value = selected,
            onValueChange = {},
            readOnly = true,
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            modifier = Modifier.menuAnchor()
        )
        ExposedDropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false }
        ) {
            listOf("Option 1", "Option 2", "Option 3").forEach { option ->
                DropdownMenuItem(
                    text = { Text(option) },
                    onClick = {
                        selected = option
                        expanded = false
                    }
                )
            }
        }
    }
}

@Composable
private fun CheckboxView(props: ZylixComponentProps) {
    var checked by remember { mutableStateOf(props.isChecked) }
    Row(verticalAlignment = Alignment.CenterVertically) {
        Checkbox(
            checked = checked,
            onCheckedChange = { checked = it },
            enabled = !props.isDisabled
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(props.text)
    }
}

@Composable
private fun RadioView(props: ZylixComponentProps) {
    var selected by remember { mutableStateOf(false) }
    Row(verticalAlignment = Alignment.CenterVertically) {
        RadioButton(
            selected = selected,
            onClick = { selected = !selected },
            enabled = !props.isDisabled
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(props.text)
    }
}

@Composable
private fun TextareaView(props: ZylixComponentProps) {
    var text by remember { mutableStateOf("") }
    OutlinedTextField(
        value = text,
        onValueChange = { text = it },
        placeholder = { Text(props.placeholder) },
        enabled = !props.isDisabled,
        modifier = Modifier
            .fillMaxWidth()
            .height(120.dp)
    )
}

@Composable
private fun ToggleSwitchView(props: ZylixComponentProps) {
    var checked by remember { mutableStateOf(props.isChecked) }
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(props.text)
        Spacer(modifier = Modifier.width(8.dp))
        Switch(
            checked = checked,
            onCheckedChange = { checked = it },
            enabled = !props.isDisabled
        )
    }
}

@Composable
private fun SliderView(props: ZylixComponentProps) {
    var value by remember { mutableStateOf(props.value) }
    Slider(
        value = value,
        onValueChange = { value = it },
        valueRange = props.minValue..props.maxValue,
        enabled = !props.isDisabled
    )
}

@Composable
private fun FormView(props: ZylixComponentProps) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp)
    ) {
        // Form children
    }
}

@Composable
private fun DatePickerView(props: ZylixComponentProps) {
    var showDialog by remember { mutableStateOf(false) }
    var selectedDate by remember { mutableStateOf("Select Date") }

    OutlinedButton(
        onClick = { showDialog = true },
        enabled = !props.isDisabled
    ) {
        Icon(Icons.Default.DateRange, contentDescription = null)
        Spacer(modifier = Modifier.width(8.dp))
        Text(selectedDate)
    }

    if (showDialog) {
        AlertDialog(
            onDismissRequest = { showDialog = false },
            title = { Text("Select Date") },
            text = { Text("Date picker would appear here") },
            confirmButton = {
                TextButton(onClick = {
                    selectedDate = "2024-01-15"
                    showDialog = false
                }) { Text("OK") }
            },
            dismissButton = {
                TextButton(onClick = { showDialog = false }) { Text("Cancel") }
            }
        )
    }
}

@Composable
private fun TimePickerView(props: ZylixComponentProps) {
    var showDialog by remember { mutableStateOf(false) }
    var selectedTime by remember { mutableStateOf("Select Time") }

    OutlinedButton(
        onClick = { showDialog = true },
        enabled = !props.isDisabled
    ) {
        Icon(Icons.Default.Schedule, contentDescription = null)
        Spacer(modifier = Modifier.width(8.dp))
        Text(selectedTime)
    }

    if (showDialog) {
        AlertDialog(
            onDismissRequest = { showDialog = false },
            title = { Text("Select Time") },
            text = { Text("Time picker would appear here") },
            confirmButton = {
                TextButton(onClick = {
                    selectedTime = "14:30"
                    showDialog = false
                }) { Text("OK") }
            },
            dismissButton = {
                TextButton(onClick = { showDialog = false }) { Text("Cancel") }
            }
        )
    }
}

@Composable
private fun FileInputView(props: ZylixComponentProps) {
    var selectedFile by remember { mutableStateOf<String?>(null) }

    OutlinedButton(
        onClick = { /* File picker would open here */ },
        enabled = !props.isDisabled
    ) {
        Icon(Icons.Default.AttachFile, contentDescription = null)
        Spacer(modifier = Modifier.width(8.dp))
        Text(selectedFile ?: "Choose File")
    }
}

@Composable
private fun ColorPickerView(props: ZylixComponentProps) {
    var selectedColor by remember { mutableStateOf(Color(0xFF2196F3)) }
    val colors = listOf(
        Color(0xFFF44336), Color(0xFFE91E63), Color(0xFF9C27B0),
        Color(0xFF673AB7), Color(0xFF3F51B5), Color(0xFF2196F3),
        Color(0xFF03A9F4), Color(0xFF00BCD4), Color(0xFF009688),
        Color(0xFF4CAF50), Color(0xFF8BC34A), Color(0xFFCDDC39)
    )

    Column {
        if (props.text.isNotEmpty()) {
            Text(props.text, modifier = Modifier.padding(bottom = 8.dp))
        }
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(colors.size) { index ->
                val color = colors[index]
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(color)
                        .border(
                            width = if (color == selectedColor) 3.dp else 0.dp,
                            color = Color.Black,
                            shape = CircleShape
                        )
                )
            }
        }
    }
}

// MARK: - Layout Component Views

@Composable
private fun StackView(props: ZylixComponentProps) {
    when (props.stackDirection) {
        ZylixStackDirection.HORIZONTAL -> Row(
            horizontalArrangement = Arrangement.spacedBy(props.stackSpacing.dp)
        ) {
            // Children
        }
        ZylixStackDirection.Z_STACK -> Box {
            // Children
        }
        else -> Column(
            verticalArrangement = Arrangement.spacedBy(props.stackSpacing.dp)
        ) {
            // Children
        }
    }
}

@Composable
private fun GridView(props: ZylixComponentProps) {
    LazyVerticalGrid(
        columns = GridCells.Adaptive(100.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Grid items
    }
}

@Composable
private fun ScrollViewWrapper(props: ZylixComponentProps) {
    LazyColumn {
        // Scroll content
    }
}

@Composable
private fun SpacerView() {
    Spacer(modifier = Modifier.height(16.dp))
}

@Composable
private fun DividerView() {
    HorizontalDivider()
}

@Composable
private fun CardView(props: ZylixComponentProps) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(8.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            if (props.text.isNotEmpty()) {
                Text(props.text)
            }
        }
    }
}

@Composable
private fun AspectRatioView(props: ZylixComponentProps) {
    val ratio = props.value.takeIf { it > 0 } ?: 16f / 9f
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(ratio)
            .background(Color.LightGray.copy(alpha = 0.3f)),
        contentAlignment = Alignment.Center
    ) {
        Text("${ratio}:1", color = Color.Gray)
    }
}

@Composable
private fun SafeAreaView(props: ZylixComponentProps) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp)
    ) {
        // Children would go here with safe area insets applied
        if (props.text.isNotEmpty()) {
            Text(props.text)
        }
    }
}

// MARK: - Navigation Component Views

@Composable
private fun NavBarView(props: ZylixComponentProps) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 4.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = props.text,
                style = MaterialTheme.typography.titleLarge
            )
        }
    }
}

@Composable
private fun TabBarView(props: ZylixComponentProps) {
    var selectedTab by remember { mutableStateOf(0) }
    TabRow(selectedTabIndex = selectedTab) {
        listOf("Tab 1", "Tab 2", "Tab 3").forEachIndexed { index, title ->
            Tab(
                selected = selectedTab == index,
                onClick = { selectedTab = index },
                text = { Text(title) }
            )
        }
    }
}

@Composable
private fun BreadcrumbView(props: ZylixComponentProps) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        listOf("Home", "Category", "Current").forEachIndexed { index, item ->
            if (index > 0) {
                Text("/", color = Color.Gray)
            }
            Text(
                text = item,
                color = if (index == 2) Color.Unspecified else MaterialTheme.colorScheme.primary
            )
        }
    }
}

@Composable
private fun PaginationView(props: ZylixComponentProps) {
    var currentPage by remember { mutableStateOf(1) }
    Row(
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = { if (currentPage > 1) currentPage-- }) {
            Icon(Icons.Default.ChevronLeft, contentDescription = "Previous")
        }
        (1..5).forEach { page ->
            Button(
                onClick = { currentPage = page },
                colors = if (page == currentPage)
                    ButtonDefaults.buttonColors()
                else
                    ButtonDefaults.outlinedButtonColors(),
                contentPadding = PaddingValues(8.dp),
                modifier = Modifier.size(40.dp)
            ) {
                Text("$page")
            }
        }
        IconButton(onClick = { if (currentPage < 5) currentPage++ }) {
            Icon(Icons.Default.ChevronRight, contentDescription = "Next")
        }
    }
}

@Composable
private fun DrawerView(props: ZylixComponentProps) {
    var isOpen by remember { mutableStateOf(false) }

    Column {
        Button(onClick = { isOpen = !isOpen }) {
            Icon(Icons.Default.Menu, contentDescription = null)
            Spacer(modifier = Modifier.width(8.dp))
            Text(if (isOpen) "Close Drawer" else "Open Drawer")
        }

        if (isOpen) {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
                color = MaterialTheme.colorScheme.surfaceVariant,
                shape = RoundedCornerShape(8.dp)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    listOf("Home", "Profile", "Settings", "Help").forEach { item ->
                        Text(
                            text = item,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 12.dp)
                        )
                        if (item != "Help") HorizontalDivider()
                    }
                }
            }
        }
    }
}

// MARK: - Feedback Component Views

@Composable
private fun AlertView(props: ZylixComponentProps) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = props.alertStyle.color.copy(alpha = 0.1f),
        shape = RoundedCornerShape(8.dp)
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                imageVector = props.alertStyle.icon,
                contentDescription = null,
                tint = props.alertStyle.color
            )
            Text(text = props.text, color = props.alertStyle.color)
        }
    }
}

@Composable
private fun ProgressView(props: ZylixComponentProps) {
    when (props.progressStyle) {
        ZylixProgressStyle.LINEAR ->
            LinearProgressIndicator(
                progress = { props.progressValue / 100f },
                modifier = Modifier.fillMaxWidth()
            )
        ZylixProgressStyle.CIRCULAR ->
            CircularProgressIndicator(progress = { props.progressValue / 100f })
        ZylixProgressStyle.INDETERMINATE ->
            CircularProgressIndicator()
    }
}

@Composable
private fun SpinnerView() {
    CircularProgressIndicator()
}

@Composable
private fun SkeletonView(props: ZylixComponentProps) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(20.dp)
            .clip(RoundedCornerShape(4.dp))
            .background(
                Brush.linearGradient(
                    colors = listOf(
                        Color.Gray.copy(alpha = 0.2f),
                        Color.Gray.copy(alpha = 0.4f),
                        Color.Gray.copy(alpha = 0.2f)
                    )
                )
            )
    )
}

@Composable
private fun BadgeView(props: ZylixComponentProps) {
    Surface(
        color = MaterialTheme.colorScheme.primary,
        shape = RoundedCornerShape(12.dp)
    ) {
        Text(
            text = props.text,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
            color = Color.White,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
private fun ToastView(props: ZylixComponentProps) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.inverseSurface,
        shape = RoundedCornerShape(8.dp),
        shadowElevation = 6.dp
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                imageVector = props.alertStyle.icon,
                contentDescription = null,
                tint = props.alertStyle.color
            )
            Text(
                text = props.text.ifEmpty { "Toast message" },
                color = MaterialTheme.colorScheme.inverseOnSurface,
                modifier = Modifier.weight(1f)
            )
            IconButton(
                onClick = { /* Dismiss */ },
                modifier = Modifier.size(24.dp)
            ) {
                Icon(
                    Icons.Default.Close,
                    contentDescription = "Dismiss",
                    tint = MaterialTheme.colorScheme.inverseOnSurface
                )
            }
        }
    }
}

@Composable
private fun ModalView(props: ZylixComponentProps) {
    var isVisible by remember { mutableStateOf(false) }

    Column {
        Button(onClick = { isVisible = true }) {
            Text("Show Modal")
        }

        if (isVisible) {
            AlertDialog(
                onDismissRequest = { isVisible = false },
                title = { Text(props.text.ifEmpty { "Modal Title" }) },
                text = {
                    Column {
                        Text("This is the modal content.")
                        Text("You can add any content here.")
                    }
                },
                confirmButton = {
                    Button(onClick = { isVisible = false }) {
                        Text("Confirm")
                    }
                },
                dismissButton = {
                    TextButton(onClick = { isVisible = false }) {
                        Text("Cancel")
                    }
                }
            )
        }
    }
}

// MARK: - Data Display Component Views

@Composable
private fun AvatarView(props: ZylixComponentProps) {
    Box(
        modifier = Modifier
            .size(40.dp)
            .clip(CircleShape)
            .background(
                Brush.linearGradient(
                    colors = listOf(
                        MaterialTheme.colorScheme.primary,
                        MaterialTheme.colorScheme.secondary
                    )
                )
            ),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = props.text.take(1).uppercase(),
            color = Color.White,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
private fun IconView(props: ZylixComponentProps) {
    Icon(
        imageVector = Icons.Default.Star,
        contentDescription = props.text,
        modifier = Modifier.size(24.dp)
    )
}

@Composable
private fun TagView(props: ZylixComponentProps) {
    Surface(
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = RoundedCornerShape(16.dp)
    ) {
        Text(
            text = props.text,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp),
            fontSize = 14.sp
        )
    }
}

@Composable
private fun TableView(props: ZylixComponentProps) {
    val headers = listOf("Name", "Value", "Status")
    val rows = listOf(
        listOf("Item 1", "100", "Active"),
        listOf("Item 2", "200", "Pending"),
        listOf("Item 3", "300", "Complete")
    )

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, Color.LightGray, RoundedCornerShape(8.dp))
    ) {
        // Header row
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .padding(12.dp)
        ) {
            headers.forEach { header ->
                Text(
                    text = header,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f)
                )
            }
        }
        HorizontalDivider()
        // Data rows
        rows.forEach { row ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(12.dp)
            ) {
                row.forEach { cell ->
                    Text(text = cell, modifier = Modifier.weight(1f))
                }
            }
            HorizontalDivider()
        }
    }
}

@Composable
private fun TooltipView(props: ZylixComponentProps) {
    var showTooltip by remember { mutableStateOf(false) }

    Box {
        Button(onClick = { showTooltip = !showTooltip }) {
            Text(props.text.ifEmpty { "Hover me" })
        }

        if (showTooltip) {
            Surface(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(bottom = 48.dp),
                color = Color.DarkGray,
                shape = RoundedCornerShape(4.dp),
                shadowElevation = 4.dp
            ) {
                Text(
                    text = "This is a tooltip",
                    color = Color.White,
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                    fontSize = 12.sp
                )
            }
        }
    }
}

@Composable
private fun AccordionView(props: ZylixComponentProps) {
    var isExpanded by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, Color.LightGray, RoundedCornerShape(8.dp))
    ) {
        Surface(
            onClick = { isExpanded = !isExpanded },
            color = MaterialTheme.colorScheme.surfaceVariant
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = props.text.ifEmpty { "Accordion Header" },
                    fontWeight = FontWeight.Medium
                )
                Icon(
                    imageVector = if (isExpanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                    contentDescription = if (isExpanded) "Collapse" else "Expand"
                )
            }
        }

        if (isExpanded) {
            HorizontalDivider()
            Text(
                text = "This is the accordion content. It can contain any information that you want to show when expanded.",
                modifier = Modifier.padding(16.dp)
            )
        }
    }
}

@Composable
private fun CarouselView(props: ZylixComponentProps) {
    var currentIndex by remember { mutableStateOf(0) }
    val items = listOf("Slide 1", "Slide 2", "Slide 3", "Slide 4")

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .height(150.dp),
            elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.linearGradient(
                            colors = listOf(
                                MaterialTheme.colorScheme.primary,
                                MaterialTheme.colorScheme.secondary
                            )
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = items[currentIndex],
                    color = Color.White,
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(
                onClick = { if (currentIndex > 0) currentIndex-- },
                enabled = currentIndex > 0
            ) {
                Icon(Icons.Default.ChevronLeft, contentDescription = "Previous")
            }

            items.forEachIndexed { index, _ ->
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(
                            if (index == currentIndex)
                                MaterialTheme.colorScheme.primary
                            else
                                Color.LightGray
                        )
                )
            }

            IconButton(
                onClick = { if (currentIndex < items.lastIndex) currentIndex++ },
                enabled = currentIndex < items.lastIndex
            ) {
                Icon(Icons.Default.ChevronRight, contentDescription = "Next")
            }
        }
    }
}

// MARK: - Placeholder View

@Composable
private fun PlaceholderView(props: ZylixComponentProps) {
    Surface(
        modifier = Modifier.padding(8.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = RoundedCornerShape(8.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                imageVector = Icons.Default.GridView,
                contentDescription = null,
                tint = Color.Gray
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = props.componentType.displayName,
                color = Color.Gray,
                fontSize = 12.sp
            )
        }
    }
}

/**
 * Demo composable showing all available component types.
 */
@Composable
fun ZylixComponentsDemo() {
    var selectedCategory by remember { mutableStateOf(ComponentCategory.BASIC) }

    Column(modifier = Modifier.fillMaxSize()) {
        // Category tabs
        ScrollableTabRow(
            selectedTabIndex = ComponentCategory.entries.indexOf(selectedCategory)
        ) {
            ComponentCategory.entries.forEach { category ->
                Tab(
                    selected = selectedCategory == category,
                    onClick = { selectedCategory = category },
                    text = { Text(category.displayName) }
                )
            }
        }

        // Component list
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            val components = ZylixComponentType.entries.filter { it.category == selectedCategory }
            items(components.size) { index ->
                val type = components[index]
                ComponentRow(type)
            }
        }
    }
}

@Composable
private fun ComponentRow(type: ZylixComponentType) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Text(
                text = type.displayName,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(12.dp))
            ZylixComponentFactory.CreateView(
                props = ZylixComponentProps(
                    componentType = type,
                    text = type.displayName
                )
            )
        }
    }
}
