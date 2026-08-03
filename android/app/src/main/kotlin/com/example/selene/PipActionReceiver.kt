package org.moontechlab.selene

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class PipActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        val action = intent?.action
        if (action.isNullOrBlank()) {
            Log.d("PipControls", "Receiver 丢弃空 PiP 动作")
            return
        }
        Log.d("PipControls", "PipActionReceiver 收到动作: $action")
        MainActivity.dispatchPipActionFromReceiver(action)
    }
}
