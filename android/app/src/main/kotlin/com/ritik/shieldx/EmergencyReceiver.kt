package com.ritik.shieldx

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.telecom.TelecomManager
import android.telephony.SmsManager

class EmergencyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val number = intent.getStringExtra("number") ?: return
        val message = intent.getStringExtra("message") ?: "SOS! I am in DANGER! Need Help!"

        // 1. Send SMS silently - single message, no popup
        try {
            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                context.getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
            val parts = smsManager.divideMessage(message)
            smsManager.sendMultipartTextMessage(number, null, parts, null, null)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // 2. Place call 1 second after SMS using TelecomManager (works from background on all Android versions)
        Handler(Looper.getMainLooper()).postDelayed({
            try {
                val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
                val callUri = Uri.fromParts("tel", number, null)
                val extras = Bundle()
                // This requires CALL_PHONE permission - already in manifest
                telecomManager.placeCall(callUri, extras)
            } catch (e1: Exception) {
                e1.printStackTrace()
                // Fallback: startActivity with ACTION_CALL
                try {
                    val callIntent = Intent(Intent.ACTION_CALL).apply {
                        data = Uri.parse("tel:$number")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(callIntent)
                } catch (e2: Exception) {
                    e2.printStackTrace()
                }
            }
        }, 1500L)
    }
}
