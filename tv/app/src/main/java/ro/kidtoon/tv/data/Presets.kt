package ro.kidtoon.tv.data

/** Surse publice sugerate in Setari (parintele alege daca le adauga). La fel ca pe telefon. */
object Presets {
    /** Lista pornita implicit: desene animate si emisiuni pentru copii, publice. */
    val kids = PlaylistSource("Desene animate (iptv-org · Copii)", "https://iptv-org.github.io/iptv/categories/kids.m3u")

    val playlists = listOf(
        PlaylistSource("iptv-org · Copii", "https://iptv-org.github.io/iptv/categories/kids.m3u"),
        PlaylistSource("iptv-org · Animație", "https://iptv-org.github.io/iptv/categories/animation.m3u"),
        PlaylistSource("iptv-org · Educație", "https://iptv-org.github.io/iptv/categories/education.m3u"),
        PlaylistSource("iptv-org · Familie", "https://iptv-org.github.io/iptv/categories/family.m3u"),
        PlaylistSource("iptv-org · România (filtrat pentru copii)", "https://iptv-org.github.io/iptv/countries/ro.m3u"),
    )

    val epg = listOf(
        "https://epgshare01.online/epgshare01/epg_ripper_RO1.xml.gz",
    )
}
