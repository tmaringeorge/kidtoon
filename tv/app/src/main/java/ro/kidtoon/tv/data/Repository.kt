package ro.kidtoon.tv.data

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.InputStream
import java.security.MessageDigest
import java.util.concurrent.TimeUnit
import java.util.zip.GZIPInputStream

class Repository(private val context: Context, val prefs: Prefs) {

    val http: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .followRedirects(true)
        .build()

    data class LoadResult(
        val channels: List<Channel>,
        val epgUrlsFromPlaylists: List<String>,
        val errors: List<String>,
        val filteredOut: Int,
    )

    suspend fun loadChannels(): LoadResult = withContext(Dispatchers.IO) {
        val errors = java.util.Collections.synchronizedList(mutableListOf<String>())
        val parsed = mutableListOf<ParsedPlaylist>()

        if (prefs.builtInEnabled) {
            val text = context.assets.open(BUILT_IN_ASSET).bufferedReader().use { it.readText() }
            parsed += M3uParser.parse(text, BUILT_IN_NAME)
        }
        coroutineScope {
            prefs.playlists.filter { it.enabled }.map { src ->
                async {
                    runCatching {
                        val text = fetchCached(src.url, maxAgeMs = 6 * 3600_000L).use { s ->
                            s.bufferedReader().readText()
                        }
                        M3uParser.parse(text, src.name)
                    }.onFailure { errors += "${src.name}: ${it.message ?: it.javaClass.simpleName}" }
                        .getOrNull()
                }
            }.awaitAll().filterNotNull().let { parsed += it }
        }

        val all = parsed.flatMap { it.channels }
        val allowed = all.filter { SourceFilter.isAllowed(it.url) }
        // Acelasi post din mai multe liste: pastram prima aparitie.
        val unique = allowed.distinctBy { it.url }
        LoadResult(
            channels = unique,
            epgUrlsFromPlaylists = parsed.flatMap { it.epgUrls }.distinct(),
            errors = errors,
            filteredOut = all.size - allowed.size,
        )
    }

    suspend fun loadEpg(urls: List<String>): Epg = withContext(Dispatchers.IO) {
        if (urls.isEmpty()) return@withContext Epg.EMPTY
        coroutineScope {
            urls.map { url ->
                async {
                    runCatching {
                        fetchCached(url, maxAgeMs = 12 * 3600_000L).use { raw ->
                            val stream = if (url.endsWith(".gz")) GZIPInputStream(raw) else maybeGunzip(raw)
                            XmlTvParser.parse(stream.buffered())
                        }
                    }.getOrNull()
                }
            }.awaitAll().filterNotNull()
        }.let { if (it.isEmpty()) Epg.EMPTY else Epg.merge(it) }
    }

    fun clearCache() {
        File(context.cacheDir, "downloads").listFiles()?.forEach { it.setLastModified(0) }
    }

    /** Descarca un fisier si il pastreaza in cache; la eroare de retea foloseste copia veche. */
    private fun fetchCached(url: String, maxAgeMs: Long): InputStream {
        val dir = File(context.cacheDir, "downloads").apply { mkdirs() }
        val file = File(dir, sha1(url))
        val fresh = file.exists() && System.currentTimeMillis() - file.lastModified() < maxAgeMs
        if (!fresh) {
            try {
                val req = Request.Builder().url(url).header("User-Agent", USER_AGENT).build()
                http.newCall(req).execute().use { resp ->
                    if (!resp.isSuccessful) error("HTTP ${resp.code}")
                    val tmp = File(dir, file.name + ".tmp")
                    resp.body!!.byteStream().use { input -> tmp.outputStream().use { input.copyTo(it) } }
                    tmp.renameTo(file)
                }
            } catch (e: Exception) {
                if (!file.exists()) throw e
            }
        }
        return file.inputStream()
    }

    private fun maybeGunzip(input: InputStream): InputStream {
        val buffered = input.buffered()
        buffered.mark(2)
        val b1 = buffered.read(); val b2 = buffered.read()
        buffered.reset()
        return if (b1 == 0x1f && b2 == 0x8b) GZIPInputStream(buffered) else buffered
    }

    private fun sha1(s: String): String =
        MessageDigest.getInstance("SHA-1").digest(s.toByteArray()).joinToString("") { "%02x".format(it) }

    companion object {
        const val BUILT_IN_ASSET = "copii.m3u"
        const val BUILT_IN_NAME = "Lista KidToon"
        const val USER_AGENT = "KidToon/1.0 (Android TV)"
    }
}
