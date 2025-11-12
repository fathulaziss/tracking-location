package com.example.tracking_location

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onStart() {
        super.onStart()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "hajj_channel_id", // HARUS SAMA
                "Location Tracking",
                NotificationManager.IMPORTANCE_LOW
            )
            channel.description = "Channel untuk foreground location tracking"
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
