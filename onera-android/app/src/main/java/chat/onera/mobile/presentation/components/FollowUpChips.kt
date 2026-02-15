package chat.onera.mobile.presentation.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SuggestionChip
import androidx.compose.material3.SuggestionChipDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay

@Composable
fun FollowUpChips(
    followUps: List<String>,
    onSelectFollowUp: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    if (followUps.isEmpty()) return

    // Track which chips are visible for staggered animation
    val visibleChips = remember(followUps) { mutableStateListOf<Int>() }

    LaunchedEffect(followUps) {
        visibleChips.clear()
        followUps.forEachIndexed { index, _ ->
            delay(index * 100L)
            visibleChips.add(index)
        }
    }

    Row(
        modifier = modifier
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        followUps.forEachIndexed { index, text ->
            AnimatedVisibility(
                visible = index in visibleChips,
                enter = fadeIn(tween(300)) + slideInVertically(
                    animationSpec = tween(300),
                    initialOffsetY = { it / 2 }
                )
            ) {
                SuggestionChip(
                    onClick = { onSelectFollowUp(text) },
                    label = {
                        Text(
                            text = text,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            style = MaterialTheme.typography.bodySmall
                        )
                    },
                    colors = SuggestionChipDefaults.suggestionChipColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant,
                        labelColor = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                )
            }
        }
    }
}
