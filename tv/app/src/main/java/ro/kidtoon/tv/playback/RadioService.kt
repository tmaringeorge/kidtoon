package ro.kidtoon.tv.playback

import android.app.PendingIntent
import android.content.Intent
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import okhttp3.OkHttpClient
import ro.kidtoon.tv.MainActivity
import ro.kidtoon.tv.data.Repository
import java.util.concurrent.TimeUnit

/**
 * Serviciul care tine radioul pornit si cand aplicatia nu e pe ecran (Home, alta
 * aplicatie, ecran stins), ca la YouTube. Ecranul radio se conecteaza la el cu un
 * MediaController; telecomanda si notificarea media il controleaza direct.
 */
@OptIn(UnstableApi::class)
class RadioService : MediaSessionService() {
    private var session: MediaSession? = null

    override fun onCreate() {
        super.onCreate()
        val http = OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build()
        val dataSource = OkHttpDataSource.Factory(http).setUserAgent(Repository.USER_AGENT)
        val player = ExoPlayer.Builder(this)
            .setMediaSourceFactory(DefaultMediaSourceFactory(dataSource))
            .setAudioAttributes(
                AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_MUSIC).build(),
                /* handleAudioFocus = */ true,
            )
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_NETWORK)
            .build()
        val openApp = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        session = MediaSession.Builder(this, player)
            .setSessionActivity(openApp)
            .setCallback(object : MediaSession.Callback {
                // Adresa streamului vine prin requestMetadata (MediaController nu trimite localConfiguration).
                override fun onAddMediaItems(
                    mediaSession: MediaSession,
                    controller: MediaSession.ControllerInfo,
                    mediaItems: MutableList<MediaItem>,
                ): ListenableFuture<MutableList<MediaItem>> = Futures.immediateFuture(
                    mediaItems.map { item ->
                        val uri = item.requestMetadata.mediaUri ?: item.localConfiguration?.uri
                        item.buildUpon()
                            .setUri(uri)
                            .setMimeType(item.requestMetadata.extras?.getString(KEY_MIME))
                            .build()
                    }.toMutableList()
                )
            })
            .build()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = session

    /** Daca aplicatia e inchisa din lista de recente, radioul se opreste si el. */
    override fun onTaskRemoved(rootIntent: Intent?) {
        session?.player?.let { it.stop(); it.clearMediaItems() }
        stopSelf()
    }

    override fun onDestroy() {
        session?.run {
            player.release()
            release()
        }
        session = null
        super.onDestroy()
    }

    companion object {
        const val KEY_MIME = "kidtoon.mime"
    }
}
