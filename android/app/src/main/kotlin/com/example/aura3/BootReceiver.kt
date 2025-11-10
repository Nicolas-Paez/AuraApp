package com.example.aura3

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Simple BootReceiver that starts the MainActivity on boot.
 * NOTE: This is a pragmatic approach to allow the app to re-schedule alarms after reboot.
 * On some devices this may be blocked by battery/auto-start restrictions.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            try {
                Log.i("BootReceiver", "BOOT_COMPLETED received, starting MainActivity to reschedule alarms")
                val launchIntent = context.packageManager
                    .getLaunchIntentForPackage(context.packageName)
                    ?.apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        putExtra("FROM_BOOT", true)
                    }
                
                if (launchIntent != null) {
                    context.startActivity(launchIntent)
                } else {
                    Log.e("BootReceiver", "Could not get launch intent for package")
                }
            } catch (e: Exception) {
                Log.e("BootReceiver", "Error handling BOOT_COMPLETED: ${e.message}")
            }
        }
    }
}