package org.moontechlab.selene

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class PipActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        val action = intent?.action ?: return
        Log.d("PipControls", "PipActionReceiver 收到动作: $action")
        MainActivity.dispatchPipActionFromReceiver(action)
    }
}
