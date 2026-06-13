package com.focuscycle.data

import android.content.Context
import kotlinx.serialization.json.Json

class AppGraph private constructor(context: Context) {
    private val appContext = context.applicationContext
    val json: Json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }
    val database: FocusCycleDatabase = FocusCycleDatabase.create(appContext)
    val preferences: PreferenceRepository = PreferenceRepository(appContext, json)
    val sessions: SessionRepository = SessionRepository(database.sessionRecords(), preferences, json)
    val pendingCommands: PendingCommandRepository = PendingCommandRepository(database.pendingCommands(), json)

    companion object {
        @Volatile private var instance: AppGraph? = null

        fun get(context: Context): AppGraph =
            instance ?: synchronized(this) {
                instance ?: AppGraph(context).also { instance = it }
            }
    }
}
