package ro.kidtoon.tv.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.tv.material3.Border
import androidx.tv.material3.ClickableSurfaceDefaults
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.darkColorScheme
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Culorile KidToon (ca pe telefon): vesele, cu contrast mare, ușor de văzut de pe canapea. */
object KidColors {
    val Background = Color(0xFF1B1446)
    val Panel = Color(0xFF241A5C)
    val Card = Color(0xFF2E2370)
    val CardFocused = Color(0xFF41329A)
    val LogoBox = Color(0xFF1F1750)
    /** Pe TV butonul ales e roz, cu text alb, ca să se vadă de departe. */
    val Accent = Color(0xFFFF5C9D)
    val AccentSoft = Color(0x33FF5C9D)
    val Sun = Color(0xFFFFC93C)
    val Text = Color(0xFFFFFFFF)
    val TextDim = Color(0xFFC9C2F0)
    val Live = Color(0xFFFF5A79)

    // Plăcile mari de pe ecranul principal.
    val Purple = Color(0xFF8E5CFF)
    val Pink = Color(0xFFFF5C9D)
    val Orange = Color(0xFFFF8A3D)
    val Yellow = Color(0xFFFFC93C)
    val Green = Color(0xFF3DD68C)
    val Blue = Color(0xFF3DA5FF)
    val Teal = Color(0xFF2EC4B6)
    val Red = Color(0xFFFF4D4D)
}

@Composable
fun KidTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = KidColors.Accent,
            background = KidColors.Background,
            surface = KidColors.Card,
            onSurface = KidColors.Text,
        ),
        content = content,
    )
}

val CardShape = RoundedCornerShape(22.dp)

@Composable
fun focusBorder() = ClickableSurfaceDefaults.border(
    focusedBorder = Border(BorderStroke(4.dp, Color.White), shape = CardShape),
)

private val hhmm = ThreadLocal.withInitial { SimpleDateFormat("HH:mm", Locale.getDefault()) }
fun formatTime(ms: Long): String = hhmm.get()!!.format(Date(ms))
