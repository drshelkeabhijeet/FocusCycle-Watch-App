package com.focuscycle.wear

import android.content.Intent
import com.focuscycle.data.AppGraph
import com.focuscycle.domain.CompanionApplyPresetCommand
import com.focuscycle.domain.CompanionCommandPayload
import com.focuscycle.domain.MeditationPreset
import com.focuscycle.domain.PranayamaPattern
import com.focuscycle.domain.YogaPreset
import com.focuscycle.sync.IncomingEnvelopeParser
import com.focuscycle.sync.WearDataLayerSyncTransport
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking

class WearCommandListenerService : WearableListenerService() {
    private val parser = IncomingEnvelopeParser()

    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path != "/focuscycle/command") return
        val command = parser.fromMessage(messageEvent.data)?.command ?: return
        runBlocking { applyCommand(command) }
    }

    private suspend fun applyCommand(command: CompanionCommandPayload) {
        val graph = AppGraph.get(this)
        when (command.type) {
            "requestState" -> publishSnapshot(graph)
            "applyPreset" -> {
                command.applyPreset?.let { applyPreset(graph, it) }
                publishSnapshot(graph)
            }
            "quickStart" -> {
                command.quickStart?.practice?.let { practice ->
                    startActivity(
                        Intent(this, MainActivity::class.java)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            .putExtra(MainActivity.EXTRA_START_SCREEN, practice)
                    )
                }
            }
        }
    }

    private suspend fun applyPreset(graph: AppGraph, preset: CompanionApplyPresetCommand) {
        when (preset.practice) {
            "yoga" -> preset.yoga?.let {
                graph.preferences.saveYogaPreset(
                    YogaPreset(
                        holdSeconds = maxOf(1, it.holdSeconds),
                        restSeconds = maxOf(0, it.restSeconds),
                        asanaCount = maxOf(1, it.asanaCount)
                    )
                )
            }
            "pranayama" -> preset.pranayama?.let {
                graph.preferences.savePranayamaPattern(
                    PranayamaPattern(
                        typeRawValue = it.typeRawValue,
                        inhaleDuration = maxOf(1, it.inhaleDuration),
                        hold1Duration = maxOf(0, it.hold1Duration),
                        exhaleDuration = maxOf(1, it.exhaleDuration),
                        hold2Duration = maxOf(0, it.hold2Duration),
                        cycles = maxOf(1, it.cycles)
                    )
                )
            }
            "meditation" -> preset.meditation?.let {
                graph.preferences.saveMeditationPreset(MeditationPreset(durationMinutes = maxOf(1, it.durationMinutes)))
            }
        }
    }

    private suspend fun publishSnapshot(graph: AppGraph) {
        val snapshot = graph.sessions.snapshot(
            yoga = graph.preferences.yogaPreset.first(),
            pranayama = graph.preferences.pranayamaPatterns.first(),
            meditation = graph.preferences.meditationPreset.first()
        )
        WearDataLayerSyncTransport(this, graph.json).publishSnapshot(snapshot)
    }
}
