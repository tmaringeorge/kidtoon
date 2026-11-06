package ro.kidtoon.tv.ui

import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.net.Inet4Address
import java.net.InetSocketAddress
import java.net.NetworkInterface
import java.net.ServerSocket
import java.net.Socket
import ro.kidtoon.tv.data.GhiStudio
import ro.kidtoon.tv.data.StudioPack

/**
 * Un server mic, doar în rețeaua de acasă și doar cât e deschis ecranul „Primește de pe telefon”.
 * Acceptă un singur lucru: POST /ghi cu codul de pe ecran. După 5 coduri greșite se oprește.
 */
class StudioServer(
    private val code: String,
    private val onReceived: (text: String, pack: StudioPack) -> Unit,
    private val onStatus: (String) -> Unit,
) {
    @Volatile private var server: ServerSocket? = null
    @Volatile private var stopped = false
    private var wrong = 0

    /** Blochează firul până la [stop]; se cheamă pe Dispatchers.IO. */
    fun run() {
        val s = try {
            ServerSocket().apply { reuseAddress = true; bind(InetSocketAddress(GhiStudio.PORT)) }
        } catch (e: Exception) {
            onStatus("Nu pot porni primirea (portul ${GhiStudio.PORT} e ocupat). Închide și deschide din nou.")
            return
        }
        server = s
        if (stopped) s.close()
        onStatus("Aștept telefonul…")
        while (!stopped) {
            val client = try { s.accept() } catch (e: Exception) { break }
            runCatching { client.use { serve(it) } }
            if (wrong >= 5) {
                onStatus("Prea multe coduri greșite. Închide și deschide din nou pentru un cod nou.")
                break
            }
        }
        runCatching { s.close() }
    }

    fun stop() {
        stopped = true
        runCatching { server?.close() }
    }

    private fun serve(socket: Socket) {
        socket.soTimeout = 10_000
        val input = DataInputStream(BufferedInputStream(socket.getInputStream()))
        val head = readHead(input) ?: return reply(socket, 400, "cerere stricată")
        val lines = head.split("\r\n")
        val headers = lines.drop(1).mapNotNull { l ->
            val i = l.indexOf(':')
            if (i <= 0) null else l.substring(0, i).trim().lowercase() to l.substring(i + 1).trim()
        }.toMap()
        val length = headers["content-length"]?.toIntOrNull() ?: return reply(socket, 411, "lipsește lungimea")
        if (length !in 0..GhiStudio.MAX_BODY) return reply(socket, 413, "prea mare")
        val bytes = ByteArray(length)
        input.readFully(bytes)
        val body = String(bytes, Charsets.UTF_8)
        val answer = GhiStudio.handle(lines.first(), headers, body, code)
        if (answer.status == 403) wrong++
        val pack = answer.pack
        if (pack != null) {
            onReceived(body, pack)
            onStatus("✓ Am primit ${pack.episodes.size} episoade și ${pack.people.size} personaje. Le găsești la Povești, după celelalte.")
        }
        reply(socket, answer.status, answer.body)
    }

    /** Antetul cererii, până la rândul gol (cel mult 16 KB). */
    private fun readHead(input: DataInputStream): String? {
        val out = ByteArrayOutputStream()
        var last4 = 0
        while (out.size() < 16_384) {
            val b = input.read()
            if (b < 0) return null
            out.write(b)
            last4 = (last4 shl 8) or b
            if (last4 == 0x0D0A0D0A) return out.toString("UTF-8").trimEnd()
        }
        return null
    }

    private fun reply(socket: Socket, status: Int, body: String) {
        val bytes = body.toByteArray(Charsets.UTF_8)
        val head = "HTTP/1.1 $status ${if (status == 200) "OK" else "Error"}\r\n" +
            "Content-Type: text/plain; charset=utf-8\r\nContent-Length: ${bytes.size}\r\nConnection: close\r\n\r\n"
        socket.getOutputStream().apply {
            write(head.toByteArray(Charsets.US_ASCII))
            write(bytes)
            flush()
        }
    }

    companion object {
        /** Adresa TV-ului în rețeaua de acasă (Wi-Fi sau cablu), de scris pe telefon. */
        fun localAddress(): String? = runCatching {
            NetworkInterface.getNetworkInterfaces().toList()
                .filter { it.isUp && !it.isLoopback && !it.isVirtual }
                .sortedBy { if (it.name.startsWith("wlan") || it.name.startsWith("eth")) 0 else 1 }
                .flatMap { it.inetAddresses.toList() }
                .firstOrNull { it is Inet4Address && it.isSiteLocalAddress }
                ?.hostAddress
        }.getOrNull()
    }
}
