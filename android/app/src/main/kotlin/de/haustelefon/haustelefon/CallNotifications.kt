package de.haustelefon.haustelefon

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build

/** Benachrichtigungen: Dauer-Hinweis, eingehender und verpasster Anruf. */
object CallNotifications {
    const val EXTRA_INCOMING = "incoming"

    const val ID_KEEPALIVE = 1
    private const val ID_INCOMING = 2
    private const val ID_MISSED = 3

    private const val CH_KEEPALIVE = "keepalive"
    private const val CH_INCOMING = "incoming_calls"
    private const val CH_MISSED = "missed_calls"

    private fun manager(ctx: Context) =
        ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun ensureChannels(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val m = manager(ctx)
        m.createNotificationChannel(
            NotificationChannel(
                CH_KEEPALIVE,
                ctx.getString(R.string.channel_keepalive),
                NotificationManager.IMPORTANCE_MIN,
            ).apply { description = ctx.getString(R.string.channel_keepalive_desc) }
        )
        m.createNotificationChannel(
            NotificationChannel(
                CH_INCOMING,
                ctx.getString(R.string.channel_incoming),
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                    description = ctx.getString(R.string.channel_incoming_desc)
                    setSound(
                        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE),
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build(),
                    )
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 600, 400, 600, 400, 600)
                }
        )
        m.createNotificationChannel(
            NotificationChannel(
                CH_MISSED,
                ctx.getString(R.string.channel_missed),
                NotificationManager.IMPORTANCE_DEFAULT,
            )
        )
    }

    private fun openApp(ctx: Context, incoming: Boolean, requestCode: Int): PendingIntent {
        val intent = Intent(ctx, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra(EXTRA_INCOMING, incoming)
        return PendingIntent.getActivity(
            ctx, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    @Suppress("DEPRECATION")
    private fun builder(ctx: Context, channel: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(ctx, channel)
        else Notification.Builder(ctx)

    fun keepAlive(ctx: Context, title: String, text: String): Notification {
        ensureChannels(ctx)
        return builder(ctx, CH_KEEPALIVE)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title.ifEmpty { ctx.getString(R.string.app_name) })
            .setContentText(text)
            .setOngoing(true)
            .setContentIntent(openApp(ctx, false, 10))
            .build()
    }

    fun showIncoming(ctx: Context, title: String, caller: String) {
        ensureChannels(ctx)
        val open = openApp(ctx, true, 11)
        val n = builder(ctx, CH_INCOMING)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(caller)
            .setCategory(Notification.CATEGORY_CALL)
            .setOngoing(true)
            .setAutoCancel(true)
            .setContentIntent(open)
            // Holt die App bei gesperrtem Display direkt in den Vordergrund.
            .setFullScreenIntent(open, true)
            .build()
        manager(ctx).notify(ID_INCOMING, n)
    }

    fun cancelIncoming(ctx: Context) = manager(ctx).cancel(ID_INCOMING)

    fun showMissed(ctx: Context, title: String, caller: String) {
        ensureChannels(ctx)
        val n = builder(ctx, CH_MISSED)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(caller)
            .setCategory(Notification.CATEGORY_MISSED_CALL)
            .setAutoCancel(true)
            .setContentIntent(openApp(ctx, false, 12))
            .build()
        manager(ctx).notify(ID_MISSED, n)
    }
}
