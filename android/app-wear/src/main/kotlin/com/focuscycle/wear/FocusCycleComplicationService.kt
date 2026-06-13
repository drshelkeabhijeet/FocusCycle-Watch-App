package com.focuscycle.wear

import androidx.wear.watchface.complications.data.ComplicationData
import androidx.wear.watchface.complications.data.ComplicationType
import androidx.wear.watchface.complications.data.PlainComplicationText
import androidx.wear.watchface.complications.data.ShortTextComplicationData
import androidx.wear.watchface.complications.datasource.ComplicationRequest
import androidx.wear.watchface.complications.datasource.SuspendingComplicationDataSourceService

class FocusCycleComplicationService : SuspendingComplicationDataSourceService() {
    override fun getPreviewData(type: ComplicationType): ComplicationData? =
        shortText("Yoga", "Start")

    override suspend fun onComplicationRequest(request: ComplicationRequest): ComplicationData =
        shortText("Yoga", "Start")

    private fun shortText(text: String, title: String): ComplicationData =
        ShortTextComplicationData.Builder(
            text = PlainComplicationText.Builder(text).build(),
            contentDescription = PlainComplicationText.Builder("FocusCycle $title").build()
        )
            .setTitle(PlainComplicationText.Builder(title).build())
            .build()
}
