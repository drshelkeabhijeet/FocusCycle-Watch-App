package com.focuscycle.phone

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.focuscycle.data.AppGraph
import com.focuscycle.domain.CompanionApplyPresetCommand
import com.focuscycle.domain.CompanionCommandPayload
import com.focuscycle.domain.CompanionMeditationPreset
import com.focuscycle.domain.CompanionPranayamaPreset
import com.focuscycle.domain.CompanionQuickStartCommand
import com.focuscycle.domain.CompanionYogaPreset
import com.focuscycle.domain.SessionRecord
import com.focuscycle.health.HealthConnectBaselineRepository
import com.focuscycle.ui.FocusCycleTheme
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.UUID

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val graph = AppGraph.get(this)
        val sender = PhoneCommandSender(this, graph)
        val health = HealthConnectBaselineRepository(this)
        setContent {
            FocusCycleTheme {
                PhoneApp(graph, sender, health)
            }
        }
    }
}

private enum class PhoneTab {
    Dashboard,
    Presets,
    History,
    Insights
}

@Composable
private fun PhoneApp(
    graph: AppGraph,
    sender: PhoneCommandSender,
    health: HealthConnectBaselineRepository
) {
    var tab by remember { mutableStateOf(PhoneTab.Dashboard) }
    val sessions by graph.sessions.sessions.collectAsStateWithLifecycle(initialValue = emptyList())
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        sender.send(command(type = "requestState"))
    }

    Scaffold { padding ->
        Column(Modifier.fillMaxSize().padding(padding).padding(16.dp)) {
            Text("FocusCycle", style = MaterialTheme.typography.headlineMedium)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                PhoneTab.entries.forEach {
                    FilterChip(selected = tab == it, onClick = { tab = it }, label = { Text(it.name) })
                }
            }
            Spacer(Modifier.height(12.dp))
            when (tab) {
                PhoneTab.Dashboard -> Dashboard(sessions) { practice ->
                    scope.launch {
                        sender.send(
                            command(
                                type = "quickStart",
                                quickStart = CompanionQuickStartCommand(practice)
                            )
                        )
                    }
                }
                PhoneTab.Presets -> Presets(sender)
                PhoneTab.History -> History(sessions)
                PhoneTab.Insights -> Insights(sessions, health)
            }
        }
    }
}

@Composable
private fun Dashboard(sessions: List<SessionRecord>, onQuickStart: (String) -> Unit) {
    LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text("Streaks and totals", style = MaterialTheme.typography.titleMedium)
                    SummaryRow("Yoga", sessions, "yoga")
                    SummaryRow("Pranayama", sessions, "pranayama")
                    SummaryRow("Meditation", sessions, "meditation")
                }
            }
        }
        item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text("Quick Start on Watch", style = MaterialTheme.typography.titleMedium)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(onClick = { onQuickStart("yoga") }) { Text("Yoga") }
                        Button(onClick = { onQuickStart("pranayama") }) { Text("Pranayama") }
                        Button(onClick = { onQuickStart("meditation") }) { Text("Meditation") }
                    }
                }
            }
        }
    }
}

@Composable
private fun SummaryRow(label: String, sessions: List<SessionRecord>, activity: String) {
    val filtered = sessions.filter { it.activityTypeRawValue == activity }
    val minutes = filtered.sumOf { it.durationSeconds } / 60
    Text("$label: ${filtered.size} sessions · $minutes min")
}

@Composable
private fun Presets(sender: PhoneCommandSender) {
    val scope = rememberCoroutineScope()
    var hold by remember { mutableIntStateOf(60) }
    var rest by remember { mutableIntStateOf(20) }
    var asanas by remember { mutableIntStateOf(10) }
    var meditation by remember { mutableIntStateOf(12) }
    var inhale by remember { mutableIntStateOf(4) }
    var hold1 by remember { mutableIntStateOf(4) }
    var exhale by remember { mutableIntStateOf(4) }
    var hold2 by remember { mutableIntStateOf(4) }
    var cycles by remember { mutableIntStateOf(10) }

    LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text("Yoga Preset", style = MaterialTheme.typography.titleMedium)
                    NumberField("Hold seconds", hold) { hold = it }
                    NumberField("Rest seconds", rest) { rest = it }
                    NumberField("Asanas", asanas) { asanas = it }
                    Button(onClick = {
                        scope.launch {
                            sender.send(
                                command(
                                    type = "applyPreset",
                                    applyPreset = CompanionApplyPresetCommand(
                                        practice = "yoga",
                                        yoga = CompanionYogaPreset(hold, rest, asanas)
                                    )
                                )
                            )
                        }
                    }) { Text("Apply on Watch") }
                }
            }
        }
        item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text("Pranayama Preset", style = MaterialTheme.typography.titleMedium)
                    NumberField("Inhale", inhale) { inhale = it }
                    NumberField("Hold 1", hold1) { hold1 = it }
                    NumberField("Exhale", exhale) { exhale = it }
                    NumberField("Hold 2", hold2) { hold2 = it }
                    NumberField("Cycles", cycles) { cycles = it }
                    Button(onClick = {
                        scope.launch {
                            sender.send(
                                command(
                                    type = "applyPreset",
                                    applyPreset = CompanionApplyPresetCommand(
                                        practice = "pranayama",
                                        pranayama = CompanionPranayamaPreset("Anulom", inhale, hold1, exhale, hold2, cycles)
                                    )
                                )
                            )
                        }
                    }) { Text("Apply on Watch") }
                }
            }
        }
        item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text("Meditation Preset", style = MaterialTheme.typography.titleMedium)
                    NumberField("Duration minutes", meditation) { meditation = it }
                    Button(onClick = {
                        scope.launch {
                            sender.send(
                                command(
                                    type = "applyPreset",
                                    applyPreset = CompanionApplyPresetCommand(
                                        practice = "meditation",
                                        meditation = CompanionMeditationPreset(meditation)
                                    )
                                )
                            )
                        }
                    }) { Text("Apply on Watch") }
                }
            }
        }
    }
}

@Composable
private fun NumberField(label: String, value: Int, onChange: (Int) -> Unit) {
    OutlinedTextField(
        value = value.toString(),
        onValueChange = { onChange(it.toIntOrNull()?.coerceAtLeast(0) ?: 0) },
        label = { Text(label) },
        modifier = Modifier.fillMaxWidth()
    )
}

@Composable
private fun History(sessions: List<SessionRecord>) {
    val formatter = remember {
        DateTimeFormatter.ofPattern("MMM d, h:mm a").withZone(ZoneId.systemDefault())
    }
    LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (sessions.isEmpty()) {
            item { Text("No synced sessions yet.") }
        }
        items(sessions) { session ->
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text(session.activityTypeRawValue.replaceFirstChar { it.uppercase() })
                    Text("${session.durationSeconds}s · ${formatter.format(Instant.ofEpochMilli(session.dateEpochMillis))}")
                    session.avgHeartRate?.let { Text("Avg HR: ${it.toInt()} bpm") }
                    session.activeEnergyKcal?.let { Text("Energy: ${it.toInt()} kcal") }
                }
            }
        }
    }
}

@Composable
private fun Insights(sessions: List<SessionRecord>, health: HealthConnectBaselineRepository) {
    var baseline by remember { mutableStateOf<com.focuscycle.health.BaselineHealthSnapshot?>(null) }
    LaunchedEffect(Unit) {
        baseline = health.readBaseline()
    }
    LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text("Wellness Baseline", style = MaterialTheme.typography.titleMedium)
                    Text("Resting HR: ${baseline?.restingHeartRate?.toInt()?.toString() ?: "Unavailable"}")
                    Text("VO2 Max: ${baseline?.vo2Max?.toString() ?: "Unavailable"}")
                    Text("Blood Oxygen: ${baseline?.latestSpO2?.toString() ?: "Unavailable"}")
                    Text("Sleep: ${baseline?.lastNightSleepHours?.toString() ?: "Unavailable"}")
                }
            }
        }
        item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text("Last Sessions", style = MaterialTheme.typography.titleMedium)
                    SessionBarChart(sessions.take(30))
                }
            }
        }
    }
}

@Composable
private fun SessionBarChart(sessions: List<SessionRecord>) {
    Canvas(modifier = Modifier.fillMaxWidth().height(180.dp)) {
        val maxMinutes = sessions.maxOfOrNull { it.durationSeconds / 60f } ?: 1f
        val barWidth = size.width / maxOf(1, sessions.size)
        sessions.forEachIndexed { index, session ->
            val height = size.height * ((session.durationSeconds / 60f) / maxMinutes.coerceAtLeast(1f))
            drawRect(
                color = when (session.activityTypeRawValue) {
                    "yoga" -> Color(0xFF42A5F5)
                    "pranayama" -> Color(0xFF4CAF50)
                    else -> Color(0xFF8E68FF)
                },
                topLeft = Offset(index * barWidth, size.height - height),
                size = Size(barWidth * 0.8f, height)
            )
        }
    }
}

private fun command(
    type: String,
    quickStart: CompanionQuickStartCommand? = null,
    applyPreset: CompanionApplyPresetCommand? = null
) = CompanionCommandPayload(
    id = UUID.randomUUID().toString(),
    type = type,
    createdAtEpochMillis = Instant.now().toEpochMilli(),
    quickStart = quickStart,
    applyPreset = applyPreset
)
