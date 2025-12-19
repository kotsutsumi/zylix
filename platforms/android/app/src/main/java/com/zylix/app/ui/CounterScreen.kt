package com.zylix.app.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zylix.app.ZylixBridge

/**
 * Counter Screen - Jetpack Compose UI
 *
 * This is the native Android UI that displays state from Zylix Core.
 * The UI only renders state - all logic is handled by the Zig core.
 */
@Composable
fun CounterScreen() {
    val counter by ZylixBridge.counter.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "Zylix Counter",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "Powered by Zig Core",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.height(48.dp))

        // Counter display
        Text(
            text = counter.toString(),
            fontSize = 72.sp,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary
        )

        Spacer(modifier = Modifier.height(48.dp))

        // Control buttons
        Row(
            horizontalArrangement = Arrangement.Center
        ) {
            Button(
                onClick = { ZylixBridge.decrement() }
            ) {
                Text(text = "-", fontSize = 24.sp)
            }

            Spacer(modifier = Modifier.width(24.dp))

            Button(
                onClick = { ZylixBridge.increment() }
            ) {
                Text(text = "+", fontSize = 24.sp)
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        OutlinedButton(
            onClick = { ZylixBridge.reset() }
        ) {
            Text(text = "Reset")
        }

        Spacer(modifier = Modifier.height(48.dp))

        // ABI version info
        Text(
            text = "ABI Version: ${ZylixBridge.getAbiVersion()}",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}
