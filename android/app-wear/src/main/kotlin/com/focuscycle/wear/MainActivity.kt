package com.focuscycle.wear

import android.Manifest
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Scaffold
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.TimeText
import com.focuscycle.data.AppGraph
import com.focuscycle.domain.ActivityType
import com.focuscycle.domain.MeditationSessionEngine
import com.focuscycle.domain.PranayamaPattern
import com.focuscycle.domain.PranayamaSessionEngine
import com.focuscycle.domain.PranayamaType
import com.focuscycle.domain.SessionRecord
import com.focuscycle.domain.YogaPreset
import com.focuscycle.domain.YogaSessionEngine
import com.focuscycle.health.WearHealthSessionRepository
import com.focuscycle.ui.FocusCycleColors
import com.focuscycle.ui.FocusCycleTheme
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    private val bodySensorsPermission = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        bodySensorsPermission.launch(Manifest.permission.BODY_SENSORS)
        val graph = AppGraph.get(this)
        val health = WearHealthSessionRepository(this)
        val alerts = AlertController(this)
        val initialScreen = when (intent?.getStringExtra(EXTRA_START_SCREEN)) {
            "yoga" -> ActiveScreen.Yoga
            "pranayama" -> ActiveScreen.Pranayama
            "meditation" -> ActiveScreen.Meditation
            else -> ActiveScreen.Landing
        }
        setContent {
            FocusCycleTheme(darkTheme = true) {
                WearApp(graph, health, alerts, initialScreen)
            }
        }
    }

    companion object {
        const val EXTRA_START_SCREEN = "com.focuscycle.wear.START_SCREEN"
    }
}

private enum class ActiveScreen {
    Landing,
    Yoga,
    Pranayama,
    Meditation
}

@Composable
private fun WearApp(
    graph: AppGraph,
    health: WearHealthSessionRepository,
    alerts: AlertController,
    initialScreen: ActiveScreen
) {
    var screen by remember { mutableStateOf(initialScreen) }
    val yoga by graph.preferences.yogaPreset.collectAsStateWithLifecycle(initialValue = YogaPreset())
    val pranayama by graph.preferences.pranayamaPatterns.collectAsStateWithLifecycle(
        initialValue = PranayamaType.entries.map { PranayamaPattern.defaultFor(it) }
    )
    val meditation by graph.preferences.meditationPreset.collectAsStateWithLifecycle(
        initialValue = com.focuscycle.domain.MeditationPreset()
    )

    Scaffold(timeText = { TimeText() }) {
        when (screen) {
            ActiveScreen.Landing -> LandingScreen(
                onYoga = { screen = ActiveScreen.Yoga },
                onPranayama = { screen = ActiveScreen.Pranayama },
                onMeditation = { screen = ActiveScreen.Meditation }
            )
            ActiveScreen.Yoga -> YogaTimerScreen(
                preset = yoga,
                health = health,
                alerts = alerts,
                graph = graph,
                onClose = { screen = ActiveScreen.Landing }
            )
            ActiveScreen.Pranayama -> PranayamaTimerScreen(
                pattern = pranayama.firstOrNull() ?: PranayamaPattern.defaultFor(PranayamaType.Anulom),
                health = health,
                alerts = alerts,
                graph = graph,
                onClose = { screen = ActiveScreen.Landing }
            )
            ActiveScreen.Meditation -> MeditationTimerScreen(
                durationMinutes = meditation.durationMinutes,
                health = health,
                alerts = alerts,
                graph = graph,
                onClose = { screen = ActiveScreen.Landing }
            )
        }
    }
}

@Composable
private fun LandingScreen(
    onYoga: () -> Unit,
    onPranayama: () -> Unit,
    onMeditation: () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 20.dp, vertical = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("FocusCycle", style = MaterialTheme.typography.title2, textAlign = TextAlign.Center)
        Spacer(Modifier.height(10.dp))
        PracticeButton("Yoga", onYoga)
        PracticeButton("Pranayama", onPranayama)
        PracticeButton("Meditation", onMeditation)
    }
}

@Composable
private fun PracticeButton(label: String, onClick: () -> Unit) {
    Button(onClick = onClick, modifier = Modifier.padding(vertical = 4.dp)) {
        Text(label, textAlign = TextAlign.Center)
    }
}

@Composable
private fun YogaTimerScreen(
    preset: YogaPreset,
    health: WearHealthSessionRepository,
    alerts: AlertController,
    graph: AppGraph,
    onClose: () -> Unit
) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val engine = remember(preset) { YogaSessionEngine(preset) }
    var state by remember(preset) { mutableStateOf(engine.state()) }
    val bpm by health.bpm.collectAsStateWithLifecycle(initialValue = null)

    LaunchedEffect(state.isActive) {
        while (state.isActive) {
            delay(1_000)
            val before = state.currentPhaseIndex
            state = engine.tick()
            if (state.currentPhaseIndex != before) alerts.play(WearAlertPattern.Notification)
            if (state.totalSeconds > 0 && state.elapsedSeconds >= state.totalSeconds) {
                val metrics = health.stop()
                context.stopService(Intent(context, ActiveSessionService::class.java))
                graph.sessions.record(SessionRecord(ActivityType.Yoga, state.elapsedSeconds, metrics = metrics))
                alerts.play(WearAlertPattern.Success)
                onClose()
            }
        }
    }

    TimerChrome(
        title = "Yoga",
        subtitle = "${state.elapsedSeconds}s / ${state.totalSeconds}s${bpm?.let { " · $it bpm" } ?: ""}",
        primary = if (state.isActive) "Pause" else "Start",
        onPrimary = {
            if (state.isActive) {
                state = engine.pause()
                health.stop()
                context.stopService(Intent(context, ActiveSessionService::class.java))
            } else {
                ContextCompat.startForegroundService(context, Intent(context, ActiveSessionService::class.java))
                engine.start()
                health.start()
                state = engine.state()
            }
        },
        onStop = {
            scope.launch {
                val elapsed = state.elapsedSeconds
                val metrics = health.stop()
                context.stopService(Intent(context, ActiveSessionService::class.java))
                if (elapsed > 0) graph.sessions.record(SessionRecord(ActivityType.Yoga, elapsed, metrics = metrics))
                engine.reset()
                onClose()
            }
        }
    )
}

@Composable
private fun PranayamaTimerScreen(
    pattern: PranayamaPattern,
    health: WearHealthSessionRepository,
    alerts: AlertController,
    graph: AppGraph,
    onClose: () -> Unit
) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val engine = remember(pattern) { PranayamaSessionEngine(pattern) }
    var state by remember(pattern) { mutableStateOf(engine.state()) }
    var previousPhase by remember(pattern) { mutableStateOf(state.currentPhase) }

    LaunchedEffect(state.isActive) {
        while (state.isActive) {
            delay(250)
            state = engine.tick()
            if (state.currentPhase != previousPhase) {
                previousPhase = state.currentPhase
                alerts.play(WearAlertPattern.Medium)
            }
            if (state.remainingSeconds <= 0) {
                val metrics = health.stop()
                context.stopService(Intent(context, ActiveSessionService::class.java))
                graph.sessions.record(
                    SessionRecord(ActivityType.Pranayama, pattern.totalDurationSeconds, pattern.typeRawValue, metrics)
                )
                alerts.play(WearAlertPattern.Success)
                onClose()
            }
        }
    }

    TimerChrome(
        title = pattern.typeRawValue,
        subtitle = "${state.currentPhase.displayName} · ${state.remainingSeconds}s",
        primary = if (state.isActive) "Pause" else "Start",
        onPrimary = {
            if (state.isActive) {
                state = engine.pause()
                health.stop()
                context.stopService(Intent(context, ActiveSessionService::class.java))
            } else {
                ContextCompat.startForegroundService(context, Intent(context, ActiveSessionService::class.java))
                engine.start()
                health.start()
                state = engine.state()
            }
        },
        onStop = {
            scope.launch {
                val elapsed = state.elapsedSeconds
                val metrics = health.stop()
                context.stopService(Intent(context, ActiveSessionService::class.java))
                if (elapsed >= 20) {
                    graph.sessions.record(SessionRecord(ActivityType.Pranayama, elapsed, pattern.typeRawValue, metrics))
                }
                engine.reset()
                onClose()
            }
        }
    )
}

@Composable
private fun MeditationTimerScreen(
    durationMinutes: Int,
    health: WearHealthSessionRepository,
    alerts: AlertController,
    graph: AppGraph,
    onClose: () -> Unit
) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val durationSeconds = durationMinutes * 60
    val engine = remember(durationSeconds) { MeditationSessionEngine(durationSeconds) }
    var state by remember(durationSeconds) { mutableStateOf(engine.state()) }

    LaunchedEffect(state.isActive) {
        while (state.isActive) {
            delay(1_000)
            state = engine.tick()
            if (state.remainingSeconds <= 0) {
                val metrics = health.stop()
                context.stopService(Intent(context, ActiveSessionService::class.java))
                graph.sessions.record(SessionRecord(ActivityType.Meditation, durationSeconds, metrics = metrics))
                alerts.play(WearAlertPattern.Success)
                onClose()
            }
        }
    }

    TimerChrome(
        title = "Meditation",
        subtitle = "${state.remainingSeconds}s remaining",
        primary = if (state.isActive) "Pause" else "Start",
        onPrimary = {
            if (state.isActive) {
                state = engine.pause()
                health.stop()
                context.stopService(Intent(context, ActiveSessionService::class.java))
            } else {
                ContextCompat.startForegroundService(context, Intent(context, ActiveSessionService::class.java))
                engine.start()
                health.start()
                state = engine.state()
            }
        },
        onStop = {
            scope.launch {
                val elapsed = state.elapsedSeconds
                val metrics = health.stop()
                context.stopService(Intent(context, ActiveSessionService::class.java))
                if (elapsed >= 20) graph.sessions.record(SessionRecord(ActivityType.Meditation, elapsed, metrics = metrics))
                engine.reset()
                onClose()
            }
        }
    )
}

@Composable
private fun TimerChrome(
    title: String,
    subtitle: String,
    primary: String,
    onPrimary: () -> Unit,
    onStop: () -> Unit
) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.padding(20.dp)
        ) {
            Text(title, style = MaterialTheme.typography.title2, textAlign = TextAlign.Center)
            Text(subtitle, style = MaterialTheme.typography.caption1, textAlign = TextAlign.Center)
            Spacer(Modifier.height(12.dp))
            Button(onClick = onPrimary, colors = ButtonDefaults.buttonColors(backgroundColor = FocusCycleColors.PlayGreen)) {
                Text(primary)
            }
            Button(onClick = onStop, colors = ButtonDefaults.buttonColors(backgroundColor = FocusCycleColors.StopRed)) {
                Text("Stop")
            }
        }
    }
}
