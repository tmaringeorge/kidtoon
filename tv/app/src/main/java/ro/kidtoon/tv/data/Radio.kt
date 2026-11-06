package ro.kidtoon.tv.data

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File

/**
 * Posturile de radio din Romania, din baza de date publica radio-browser.info
 * (stream-urile oficiale ale posturilor, intretinute de comunitate).
 */
class RadioRepository(private val context: Context, private val http: OkHttpClient) {
    private val cache get() = File(context.cacheDir, "radio-ro.json")

    suspend fun load(force: Boolean = false): List<RadioStation> = withContext(Dispatchers.IO) {
        val fresh = cache.exists() && System.currentTimeMillis() - cache.lastModified() < 24 * 3600_000L
        if (force || !fresh) {
            for (server in SERVERS) {
                val ok = runCatching {
                    val req = Request.Builder()
                        .url("https://$server.api.radio-browser.info$PATH")
                        .header("User-Agent", Repository.USER_AGENT)
                        .build()
                    http.newCall(req).execute().use { resp ->
                        if (!resp.isSuccessful) error("HTTP ${resp.code}")
                        val body = resp.body!!.string()
                        RadioParser.parse(body) // valideaza inainte de a scrie in cache
                        cache.writeText(body)
                    }
                }.isSuccess
                if (ok) break
            }
        }
        if (!cache.exists()) error("Nu pot descărca lista de radiouri. Verifică internetul.")
        RadioParser.parse(cache.readText())
    }

    companion object {
        private val SERVERS = listOf("de1", "fi1", "at1", "de2", "nl1")
        private const val PATH =
            "/json/stations/bycountrycodeexact/RO?hidebroken=true&order=clickcount&reverse=true&limit=1500"
    }
}
