package com.focuscycle.phone

import android.content.Context
import com.focuscycle.data.AppGraph
import com.focuscycle.domain.CompanionCommandPayload
import com.focuscycle.domain.CompanionEnvelope
import com.focuscycle.domain.CompanionSessionEvent
import com.focuscycle.domain.SessionRecord
import com.focuscycle.sync.IncomingEnvelopeParser
import com.focuscycle.sync.WearDataLayerSyncTransport
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class PhoneCommandSender(
    private val context: Context,
    private val graph: AppGraph,
    private val json: Json = graph.json
) {
    private val nodeClient = Wearable.getNodeClient(context)
    private val messageClient = Wearable.getMessageClient(context)

    suspend fun send(command: CompanionCommandPayload): Boolean {
        graph.pendingCommands.enqueue(command)
        val nodes = nodeClient.connectedNodes.await()
        var sent = false
        val payload = json.encodeToString(CompanionEnvelope.command(command)).encodeToByteArray()
        for (node in nodes) {
            runCatching {
                messageClient.sendMessage(node.id, "/focuscycle/command", payload).await()
            }.onSuccess {
                sent = true
            }
        }
        if (sent) graph.pendingCommands.markDispatched(command.id)
        return sent
    }
}

class PhoneWearListenerService : WearableListenerService() {
    private val parser = IncomingEnvelopeParser()
    private val scope = CoroutineScope(Dispatchers.IO)

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        val envelopes = parser.fromDataEvents(dataEvents)
        scope.launch {
            val graph = AppGraph.get(this@PhoneWearListenerService)
            envelopes.forEach { envelope ->
                when (envelope.kind) {
                    "sessionEvent" -> envelope.sessionEvent?.let { graph.sessions.record(it.toRecord()) }
                    "stateSnapshot" -> envelope.stateSnapshot?.recentEvents
                        ?.forEach { graph.sessions.record(it.toRecord()) }
                }
            }
        }
    }
}

private fun CompanionSessionEvent.toRecord(): SessionRecord = SessionRecord(
    id = id,
    activityTypeRawValue = activityTypeRawValue,
    dateEpochMillis = dateEpochMillis,
    durationSeconds = durationSeconds,
    pattern = pattern,
    avgHeartRate = avgHeartRate,
    avgRespiratoryRate = avgRespiratoryRate,
    activeEnergyKcal = activeEnergyKcal,
    hrvPreSdnnMs = hrvPreSdnnMs,
    hrvPostSdnnMs = hrvPostSdnnMs,
    spo2PrePercent = spo2PrePercent,
    spo2PostPercent = spo2PostPercent,
    hrSamples = hrSamples?.map { com.focuscycle.domain.HRSamplePoint(it.t, it.bpm) }
)
