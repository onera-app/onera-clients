---
name: android-material3
description: Material Design 3 patterns for Jetpack Compose
---

# Material Design 3 for Jetpack Compose

## Theme Setup

```kotlin
@Composable
fun OneraTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            if (darkTheme) dynamicDarkColorScheme(LocalContext.current)
            else dynamicLightColorScheme(LocalContext.current)
        }
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }
    
    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
```

## Color Scheme

```kotlin
// Primary colors
MaterialTheme.colorScheme.primary
MaterialTheme.colorScheme.onPrimary
MaterialTheme.colorScheme.primaryContainer
MaterialTheme.colorScheme.onPrimaryContainer

// Secondary colors
MaterialTheme.colorScheme.secondary
MaterialTheme.colorScheme.onSecondary

// Surface colors
MaterialTheme.colorScheme.surface
MaterialTheme.colorScheme.surfaceVariant
MaterialTheme.colorScheme.onSurface
MaterialTheme.colorScheme.onSurfaceVariant

// Error colors
MaterialTheme.colorScheme.error
MaterialTheme.colorScheme.onError
```

## Typography

```kotlin
MaterialTheme.typography.displayLarge   // 57sp
MaterialTheme.typography.displayMedium  // 45sp
MaterialTheme.typography.displaySmall   // 36sp
MaterialTheme.typography.headlineLarge  // 32sp
MaterialTheme.typography.headlineMedium // 28sp
MaterialTheme.typography.headlineSmall  // 24sp
MaterialTheme.typography.titleLarge     // 22sp
MaterialTheme.typography.titleMedium    // 16sp
MaterialTheme.typography.titleSmall     // 14sp
MaterialTheme.typography.bodyLarge      // 16sp
MaterialTheme.typography.bodyMedium     // 14sp
MaterialTheme.typography.bodySmall      // 12sp
MaterialTheme.typography.labelLarge     // 14sp
MaterialTheme.typography.labelMedium    // 12sp
MaterialTheme.typography.labelSmall     // 11sp
```

## Cards

```kotlin
// Elevated Card
ElevatedCard(
    modifier = Modifier.fillMaxWidth(),
    elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
) {
    Column(modifier = Modifier.padding(16.dp)) {
        Text("Title", style = MaterialTheme.typography.titleMedium)
        Text("Content", style = MaterialTheme.typography.bodyMedium)
    }
}

// Filled Card
Card(
    modifier = Modifier.fillMaxWidth(),
    colors = CardDefaults.cardColors(
        containerColor = MaterialTheme.colorScheme.surfaceVariant
    )
) {
    // content
}

// Outlined Card
OutlinedCard(
    modifier = Modifier.fillMaxWidth()
) {
    // content
}
```

## Buttons

```kotlin
// Filled (Primary action)
Button(onClick = { }) {
    Text("Primary Action")
}

// Filled Tonal
FilledTonalButton(onClick = { }) {
    Text("Secondary Action")
}

// Outlined
OutlinedButton(onClick = { }) {
    Text("Tertiary Action")
}

// Text
TextButton(onClick = { }) {
    Text("Low Emphasis")
}

// Icon Buttons
FilledIconButton(onClick = { }) {
    Icon(Icons.Default.Add, contentDescription = "Add")
}

FilledTonalIconButton(onClick = { }) {
    Icon(Icons.Default.Edit, contentDescription = "Edit")
}

OutlinedIconButton(onClick = { }) {
    Icon(Icons.Default.Share, contentDescription = "Share")
}

IconButton(onClick = { }) {
    Icon(Icons.Default.MoreVert, contentDescription = "More")
}
```

## Text Fields

```kotlin
// Outlined (Recommended)
OutlinedTextField(
    value = text,
    onValueChange = { text = it },
    label = { Text("Label") },
    placeholder = { Text("Placeholder") },
    supportingText = { Text("Supporting text") },
    leadingIcon = { Icon(Icons.Default.Search, null) },
    trailingIcon = { Icon(Icons.Default.Clear, null) },
    isError = hasError,
    singleLine = true
)

// Filled
TextField(
    value = text,
    onValueChange = { text = it },
    label = { Text("Label") }
)
```

## Top App Bar

```kotlin
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TopBarExample() {
    val scrollBehavior = TopAppBarDefaults.pinnedScrollBehavior()
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Title") },
                navigationIcon = {
                    IconButton(onClick = { }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { }) {
                        Icon(Icons.Default.Search, "Search")
                    }
                    IconButton(onClick = { }) {
                        Icon(Icons.Default.MoreVert, "More")
                    }
                },
                scrollBehavior = scrollBehavior
            )
        }
    ) { padding ->
        // content
    }
}
```

## Bottom Navigation

```kotlin
NavigationBar {
    items.forEachIndexed { index, item ->
        NavigationBarItem(
            icon = { Icon(item.icon, contentDescription = item.label) },
            label = { Text(item.label) },
            selected = selectedItem == index,
            onClick = { selectedItem = index }
        )
    }
}
```

## FAB

```kotlin
// Standard FAB
FloatingActionButton(
    onClick = { }
) {
    Icon(Icons.Default.Add, contentDescription = "Add")
}

// Extended FAB
ExtendedFloatingActionButton(
    onClick = { },
    icon = { Icon(Icons.Default.Edit, "Edit") },
    text = { Text("Compose") }
)

// Small FAB
SmallFloatingActionButton(onClick = { }) {
    Icon(Icons.Default.Add, contentDescription = "Add")
}

// Large FAB
LargeFloatingActionButton(onClick = { }) {
    Icon(Icons.Default.Add, contentDescription = "Add")
}
```

## Dialogs

```kotlin
AlertDialog(
    onDismissRequest = { showDialog = false },
    title = { Text("Dialog Title") },
    text = { Text("Dialog message goes here.") },
    confirmButton = {
        TextButton(onClick = { showDialog = false }) {
            Text("Confirm")
        }
    },
    dismissButton = {
        TextButton(onClick = { showDialog = false }) {
            Text("Cancel")
        }
    }
)
```

## Snackbar

```kotlin
val snackbarHostState = remember { SnackbarHostState() }

Scaffold(
    snackbarHost = { SnackbarHost(snackbarHostState) }
) { padding ->
    // To show snackbar:
    LaunchedEffect(showError) {
        if (showError) {
            snackbarHostState.showSnackbar(
                message = "Error occurred",
                actionLabel = "Retry",
                duration = SnackbarDuration.Short
            )
        }
    }
}
```

## Elevation & Surface

```kotlin
Surface(
    tonalElevation = 1.dp,  // Elevation levels: 0, 1, 3, 6, 8, 12
    shadowElevation = 0.dp,
    shape = RoundedCornerShape(16.dp),
    color = MaterialTheme.colorScheme.surface
) {
    // content
}
```

## Motion

```kotlin
// Enter
fadeIn() + expandVertically()
fadeIn() + slideInVertically()

// Exit
fadeOut() + shrinkVertically()
fadeOut() + slideOutVertically()

// AnimatedVisibility
AnimatedVisibility(
    visible = isVisible,
    enter = fadeIn() + expandVertically(),
    exit = fadeOut() + shrinkVertically()
) {
    // content
}
```
