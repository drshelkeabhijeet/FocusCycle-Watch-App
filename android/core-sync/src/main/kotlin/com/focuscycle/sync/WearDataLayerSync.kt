package com.focuscycle.sync

import android.content.Context
import com.focuscycle.domain.CompanionCommandPayload
import com.focuscycle.domain.CompanionEnvelope
import com.focuscycle.domain.CompanionSessionEvent
import com.focuscycle.domain.CompanionStateSnapshot
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.tasks.await
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

interface SyncTransport {
    suspend fun publishSnapshot(snapshot: CompanionStateSnapshot)
    suspend fun publishSessionEvent(event: CompanionSessionEvent)
    suspend fun sendCommand(nodeId: String, command: CompanionCommandPayload)
}

class WearDataLayerSyncTransport(
    context: Context,
    private val json: Json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
) : SyncTransport {
    private val dataClient: DataClient = Wearable.getDataClient(context)
    private val messageClient: MessageClient = Wearable.getMessageClient(context)

    override suspend fun publishSnapshot(snapshot: CompanionStateSnapshot) {
        putEnvelope("/focuscycle/state", CompanionEnvelope.snapshot(snapshot))
    }

    override suspend fun publishSessionEvent(event: CompanionSessionEvent) {
        putEnvelope("/focuscycle/events/${event.id}", CompanionEnvelope.sessionEvent(event))
    }

    override suspend fun sendCommand(nodeId: String, command: CompanionCommandPayload) {
        val bytes = json.encodeToString(CompanionEnvelope.command(command)).encodeToByteArray()
        messageClient.sendMessage(nodeId, "/focuscycle/command", bytes).await()
    }

    private suspend fun putEnvelope(path: String, envelope: CompanionEnvelope) {
        val request = PutDataMapRequest.create(path).apply {
            dataMap.putString("envelope", json.encodeToString(envelope))
            dataMap.putLong("updatedAt", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()
        dataClient.putDataItem(request).await()
    }
}

class IncomingEnvelopeParser(
    private val json: Json = Json { ignoreUnknownKeys = true }
) {
    fun fromMessage(bytes: ByteArray): CompanionEnvelope? =
        runCatching { json.decodeFromString<CompanionEnvelope>(bytes.decodeToString()) }.getOrNull()

    fun fromDataEvents(events: DataEventBuffer): List<CompanionEnvelope> = events
        .asSequence()
        .filter { it.type == DataEvent.TYPE_CHANGED }
        .mapNotNull { event ->
            val encoded = DataMapItem.fromDataItem(event.dataItem).dataMap.getString("envelope")
                ?: return@mapNotNull null
            runCatching { json.decodeFromString<CompanionEnvelope>(encoded) }.getOrNull()
        }
        .toList()
}
