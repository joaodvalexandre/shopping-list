package app.familyshopper.mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.Process

/**
 * Keeps the app alive while the phone is locked, the app is off screen, or it was closed, so the
 * family's phones stay connected and changes arrive at once. Android only allows that with a
 * notification that stays visible: this is it. It does nothing else; the connection itself is the app's.
 *
 * Swiping the app away from the recent apps does not stop it: the app's engine belongs to the process
 * (see MainActivity), and this service keeps the process alive, so the connections to the family's
 * phones, and the notifications about what they do, continue. Opening the app shows it again.
 */
class FamilyLinkService : Service() {
    private var closeLabel = "Close"

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        super.onDestroy()
    }

    /** New words for the notification, while the service runs (no need to start anything again). */
    fun refresh(title: String, text: String, close: String? = null) {
        if (close != null) closeLabel = close
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).notify(NOTIFICATION_ID, build(title, text))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // "Close" on the notification: the app stops completely, with its connections and its checks, until
        // it is opened again (which starts it all again). The mark keeps the scheduled checks quiet meanwhile.
        if (intent?.action == ACTION_QUIT) {
            getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE).edit().putBoolean("flutter.closed_by_user", true).commit()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            Process.killProcess(Process.myPid())
            return START_NOT_STICKY
        }

        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Family Shopper"
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: ""
        intent?.getStringExtra(EXTRA_CLOSE)?.let { closeLabel = it }
        val notification = build(title, text)

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            // Android refused (a permission, or the app is not in a state to start it): no service, but no crash
            stopSelf()
            return START_NOT_STICKY
        }

        // Nothing to come back to if the app itself is gone: the connection lives in it
        return START_NOT_STICKY
    }

    private fun build(title: String, text: String): Notification {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Family phones", NotificationManager.IMPORTANCE_LOW)
            channel.setShowBadge(false)
            manager.createNotificationChannel(channel)
        }

        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, CHANNEL_ID) else Notification.Builder(this)

        val quit = PendingIntent.getService(
            this,
            1,
            Intent(this, FamilyLinkService::class.java).setAction(ACTION_QUIT),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        @Suppress("DEPRECATION")
        return builder
            .setSmallIcon(R.drawable.ic_stat_notify)
            .addAction(R.drawable.ic_stat_notify, closeLabel, quit)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .build()
    }

    companion object {
        var instance: FamilyLinkService? = null
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_CLOSE = "close"
        const val ACTION_QUIT = "app.familyshopper.mobile.QUIT"
        private const val CHANNEL_ID = "family_link"
        private const val NOTIFICATION_ID = 7001
    }
}
