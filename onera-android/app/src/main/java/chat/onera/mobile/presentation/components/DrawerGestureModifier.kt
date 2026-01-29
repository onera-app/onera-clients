package chat.onera.mobile.presentation.components

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import kotlin.math.abs

/**
 * State holder for drawer gesture handling.
 */
class DrawerGestureState(
    val drawerWidthPx: Float,
    val minDragThresholdPx: Float
) {
    var isDrawerOpen by mutableStateOf(false)
    var dragOffset by mutableFloatStateOf(0f)
    var isDragging by mutableStateOf(false)
    var totalDragDistance by mutableFloatStateOf(0f)
    var isHorizontalSwipe by mutableStateOf<Boolean?>(null)
    
    /**
     * Calculate the current visual offset based on drawer state and drag.
     */
    val currentOffset: Float
        get() = ((if (isDrawerOpen) drawerWidthPx else 0f) + dragOffset)
            .coerceIn(0f, drawerWidthPx)
    
    /**
     * Reset drag state when gesture ends.
     */
    fun resetDragState() {
        isDragging = false
        dragOffset = 0f
        totalDragDistance = 0f
        isHorizontalSwipe = null
    }
    
    /**
     * Determine final drawer state based on drag velocity and position.
     * @param velocity The drag velocity
     * @param openThreshold Fraction of drawer width to consider "open enough"
     * @param velocityThreshold Minimum velocity to trigger state change
     */
    fun finalizeDrawerState(
        velocity: Float,
        openThreshold: Float = 0.3f,
        velocityThreshold: Float = 300f
    ) {
        isDrawerOpen = when {
            // Fast swipe right opens
            velocity > velocityThreshold -> true
            // Fast swipe left closes
            velocity < -velocityThreshold -> false
            // Otherwise, snap based on position
            else -> currentOffset > drawerWidthPx * openThreshold
        }
    }
}

/**
 * Remember drawer gesture state with proper screen dimensions.
 */
@Composable
fun rememberDrawerGestureState(
    drawerWidthFraction: Float = 0.80f,
    minDragThreshold: Float = 10f
): DrawerGestureState {
    val density = LocalDensity.current
    val configuration = LocalConfiguration.current
    
    val screenWidthPx = with(density) { configuration.screenWidthDp.dp.toPx() }
    val drawerWidthPx = screenWidthPx * drawerWidthFraction
    val minDragThresholdPx = with(density) { minDragThreshold.dp.toPx() }
    
    return remember(drawerWidthPx, minDragThresholdPx) {
        DrawerGestureState(drawerWidthPx, minDragThresholdPx)
    }
}

/**
 * Modifier for content that can be swiped right to open the drawer.
 * Apply this to the main content area when the drawer is closed.
 */
fun Modifier.swipeToOpenDrawer(
    state: DrawerGestureState,
    enabled: Boolean = true
): Modifier = composed {
    if (!enabled || state.isDrawerOpen) {
        return@composed this
    }
    
    this.pointerInput(Unit) {
        detectHorizontalDragGestures(
            onDragStart = {
                state.totalDragDistance = 0f
                state.isHorizontalSwipe = null
            },
            onDragEnd = {
                if (state.isDragging) {
                    state.finalizeDrawerState(state.dragOffset, openThreshold = 0.25f)
                }
                state.resetDragState()
            },
            onDragCancel = {
                state.resetDragState()
            },
            onHorizontalDrag = { change, dragAmount ->
                // Only allow right swipe (positive dragAmount) to open drawer
                if (dragAmount > 0) {
                    val horizontalDelta = abs(change.positionChange().x)
                    val verticalDelta = abs(change.positionChange().y)
                    
                    // Determine swipe direction on first significant movement
                    if (state.isHorizontalSwipe == null && (horizontalDelta > 5 || verticalDelta > 5)) {
                        state.isHorizontalSwipe = horizontalDelta > verticalDelta
                    }
                    
                    // Only track horizontal swipes
                    if (state.isHorizontalSwipe == true) {
                        state.totalDragDistance += dragAmount
                        
                        // Start tracking drawer after minimum threshold
                        if (state.totalDragDistance > state.minDragThresholdPx) {
                            if (!state.isDragging) {
                                state.isDragging = true
                            }
                            change.consume()
                            state.dragOffset = (state.dragOffset + dragAmount)
                                .coerceIn(0f, state.drawerWidthPx)
                        }
                    }
                }
            }
        )
    }
}

/**
 * Modifier for drawer content to handle swipe-to-close gesture.
 * Apply this to the drawer and/or the overlay when drawer is open.
 */
fun Modifier.swipeToCloseDrawer(
    state: DrawerGestureState,
    enabled: Boolean = true
): Modifier = composed {
    if (!enabled) {
        return@composed this
    }
    
    this.pointerInput(Unit) {
        detectHorizontalDragGestures(
            onDragStart = {
                state.isDragging = true
                state.totalDragDistance = 0f
                state.isHorizontalSwipe = null
            },
            onDragEnd = {
                state.finalizeDrawerState(state.dragOffset, openThreshold = 0.5f)
                state.resetDragState()
            },
            onDragCancel = {
                state.resetDragState()
            },
            onHorizontalDrag = { change, dragAmount ->
                // Allow both left swipe to close and right swipe for over-drag
                if (state.isDrawerOpen && dragAmount < 0) {
                    change.consume()
                    state.dragOffset = (state.dragOffset + dragAmount)
                        .coerceIn(-state.drawerWidthPx, 0f)
                }
            }
        )
    }
}

/**
 * Animated drawer offset for smooth transitions.
 */
@Composable
fun animatedDrawerOffset(
    state: DrawerGestureState
): Float {
    val targetOffset = when {
        state.isDragging -> state.currentOffset
        state.isDrawerOpen -> state.drawerWidthPx
        else -> 0f
    }
    
    val animatedOffset by animateFloatAsState(
        targetValue = targetOffset,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessMedium
        ),
        label = "drawerOffset"
    )
    
    return if (state.isDragging) state.currentOffset else animatedOffset
}
